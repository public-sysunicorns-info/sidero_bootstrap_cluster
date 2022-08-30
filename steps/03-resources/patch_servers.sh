#!/bin/bash

set -ex

_servers_object_list=$(kubectl get server -o=json)
_servers_data_list=$(cat $PWD/data/servers.json | jq -r '.')

function patch_server() {

    # Variables
    local server_data_object=$(echo $1 | jq .)
    echo ${server_data_object}

    # Retrieve Server Resource Id
    local server_id=$(echo $_servers_object_list | jq -r -c '.items[] | select(.spec.hostname | contains("'$(echo $server_data_object | jq -r .ip)'")) | .metadata.name')

    if [ -z ${server_id} ]
    then
        echo "Server Not Found $(echo $server_data_object | jq -r .ip)"
    else

        # Put labels to matcher serverclass
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/metadata/labels", "value": '$(echo $server_data_object | jq -r -c .labels)'}]'
        # Put bmc (ipmi) configuration
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/bmc", "value": {endpoint: "'$(echo $server_data_object | jq -r -c .idrac.ip)'", "user":"'$(echo $server_data_object | jq -r -c .idrac.user)'", "pass": "'$(echo $server_data_object | jq -r -c .idrac.pass)'"}}]'

        # Put pxeBootAlways to add the flexibility for migration
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/pxeBootAlways", "value": true}]'

        # Put method to move from pxe to disk
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/bootFromDiskMethod", "value": "ipxe-exit"}]'

        # Set Hostname of the server
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/configPatches", "value": []}]'

        # Set Hostname of the server
        #kubectl patch server ${server_id} --type='json' -p='[{"op": "add", "path": "/spec/configPatches/0", "value": {"op": "replace","path": "/machine/network/hostname","value": "'$(echo $server_data_object | jq -r -c .hostname)'"}}]'
        
        # Specify the install disk to /dev/sda
        kubectl patch server ${server_id} --type='json' -p='[{"op": "add", "path": "/spec/configPatches/0", "value": {"op":"replace", "path":"/machine/install/disk", "value":"/dev/sda"}}]'
        
        # Specify that a bootloader is needed
        kubectl patch server ${server_id} --type='json' -p='[{"op": "add", "path": "/spec/configPatches/1", "value": {"op":"replace", "path":"/machine/install/bootloader", "value":true}}]'

        # Force wipe (hard wipe) of install disk on install phase
        # kubectl patch server ${server_id} --type='json' -p='[{"op": "add", "path": "/spec/configPatches/-", "value": {"op":"replace", "path":"/machine/install/wipe", "value":true}}]'

        # Specify the CNI as cilium
        kubectl patch server ${server_id} --type='json' -p='[{"op": "add", "path": "/spec/configPatches/2", "value": {"op":"replace", "path":"/cluster/network/cni", "value":{"name": "custom", "urls": ["http://192.168.2.44:8090/cilium.yaml"]}}}]'
        
        # Specify VIP

        # eth0 deviceSelecto
        #kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/configPatches/-", "value": {"op":"replace", "path":"/machine/network/intefaces/0/deviceSelector","value":{"hardwareAddr":"'$(echo $server_data_object | jq -c -r .macaddr)'"}}}]'
        # eth0 dhcp
        #kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/configPatches/-", "value": {"op":"replace", "path":"/machine/network/intefaces/0/dhcp","value": true}}]'
        # eth0 vip
        #kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/configPatches/-", "value": {"op":"replace", "path":"/machine/network/interfaces/0/vip","value": {"ip": "192.168.5.100"}}}]'

        # Put Server as Accepted
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/accepted", "value": '$(echo $server_data_object | jq -c -r .accepted)'}]'

    fi
}

for _row in $( echo ${_servers_data_list} | jq -c -r '.[]'); do
    patch_server $_row
done