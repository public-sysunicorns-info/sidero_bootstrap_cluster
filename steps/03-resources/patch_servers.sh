#!/bin/bash

set -ex

_servers_object_list=$(kubectl get server -o=json)
_servers_data_list=$(cat $PWD/../../data/servers.json | jq -r '.')

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

        _name=$(echo $server_data_object | jq -r -c .name)
        _tmp_patch_generic=$(cat $PWD/patch-generic.json | jq -rc .)
        _tmp_patch_spec=$(cat $PWD/patch-$_name.json | jq -rc .)
        _tmp_patch_merged=$(jq -rc --argjson arr1 "$_tmp_patch_generic" --argjson arr2 "$_tmp_patch_spec" -n '$arr1 + $arr2')

        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/configPatches", "value": '$_tmp_patch_merged'}]'
        # Put Server as Accepted
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/accepted", "value": '$(echo $server_data_object | jq -c -r .accepted)'}]'

    fi
}

for _row in $( echo ${_servers_data_list} | jq -c -r '.[]'); do
    patch_server $_row
done