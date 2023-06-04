#!/bin/bash

set -eux

# Change to the one of your hosting sidero machine
# For DockerDesktop Install, the host ip
# For Minikube, the ip of the minikube host (retrieve by `minikube ip` command)
export HOST_IP="192.168.2.44"

export SIDERO_CONTROLLER_MANAGER_HOST_NETWORK=true
export SIDERO_CONTROLLER_MANAGER_API_ENDPOINT=$HOST_IP
export SIDERO_CONTROLLER_MANAGER_SIDEROLINK_ENDPOINT=$HOST_IP

export TALOS_CONFIG_PATH="$HOME/.talos/config"
export SIDERO_CLUSTERCTL_PATH="$HOME/.cluster-api/clusterctl.yaml"

export KUBERNETES_API_SERVER_ADDRESS=192.168.3.15
export KUBERNETES_API_SERVER_PORT=6443

export DOCKER_SERVER_CILLIUM_NAME="serving-config"

export CONTROL_PLANE_SERVERCLASS=small-ard-serverclass
export WORKER_SERVERCLASS=large-serverclass
export TALOS_VERSION=v1.3.5
export KUBERNETES_VERSION=v1.26.2
export CONTROL_PLANE_PORT=6443
export CONTROL_PLANE_ENDPOINT=192.168.3.15
export SIDERO_CLUSTER_PATH=data/cluster-0.yaml
export SIDERO_CLUSTER_SECRET_PATH=data/cluster-0-talosconfig
export TALOS_CTX=cluster-0
export CLUSTER_KUBE_CTX=admin@cluster-0

clean_previous_talos_install () {
  # /!\ it will clean previous installation
  if [[ -f ${TALOS_CONFIG_PATH} ]]; then
    rm ${TALOS_CONFIG_PATH}
  fi

  kubectl config unset contexts.admin@sidero-local
  kubectl config unset clusters.sidero-local
  kubectl config unset users.admin@sidero-local

  # Clean Previous Container
  _container_id=$(docker ps -f name=sidero-local-controlplane-1 -q -a)
  if [[ ! -z "${_container_id}" ]]; then
    if [ "$( docker container inspect -f '{{.State.Running}}' ${_container_id} )" == "true" ]; then
      docker kill ${_container_id}
    fi
    docker rm ${_container_id}
  fi
}

create_talos_install (){
  # Create a kube in single container
  talosctl cluster create \
    --name sidero-local \
    -p 69:69/udp,8081:8081/tcp,51821:51821/udp \
    --workers 0 \
    --config-patch '[{"op": "add", "path": "/cluster/allowSchedulingOnMasters", "value": true}]' \
    --endpoint $HOST_IP \
    --wait-timeout 30m

  if [[ ! -f ${SIDERO_CLUSTERCTL_PATH} ]]; then
    cp "steps/01-resources/sidero/clusterctl.yaml" ${SIDERO_CLUSTERCTL_PATH}
  fi
}

install_sidero_on_talos (){
  clusterctl init -b talos -c talos -i sidero
}

install_sidero_custom_serverclass () {
  kubectl apply -f ./steps/01-resources/sidero/large-ard-serverclass.yml
  kubectl apply -f ./steps/01-resources/sidero/large-serverclass.yml
  kubectl apply -f ./steps/01-resources/sidero/small-ard-serverclass.yml
  kubectl apply -f ./steps/01-resources/sidero/small-serverclass.yml
}

patch_server (){
  echo "TODO PATCH SERVER"
}

prepare_cillium (){
  helm repo add cilium https://helm.cilium.io/
  helm repo update

  if [[ -f "./data/webserver/cilium.yaml" ]]; then
      rm $PWD/data/webserver/cilium.yaml
  fi

  helm template cilium cilium/cilium \
      --version 1.11.2 \
      --namespace kube-system \
      --set ipam.mode=kubernetes \
      --set kubeProxyReplacement=strict \
      --set k8sServiceHost="${KUBERNETES_API_SERVER_ADDRESS}" \
      --set k8sServicePort="${KUBERNETES_API_SERVER_PORT}" > ./data/webserver/cilium.yaml
}

server_cillium (){
  # Clean Previous Container
  _container_id=$(docker ps -f name=${DOCKER_SERVER_CILLIUM_NAME} -q -a)
  if [[ ! -z "${_container_id}" ]]; then
    if [ "$( docker container inspect -f '{{.State.Running}}' ${_container_id} )" == "true" ]; then
      docker kill ${_container_id}
    fi
    docker rm ${_container_id}
  fi
  docker run -dit --name ${DOCKER_SERVER_CILLIUM_NAME} -p 8090:80 -v "$PWD/data/webserver":/usr/local/apache2/htdocs/ httpd:2.4  
}

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

        local _name=$(echo $server_data_object | jq -r -c .name)
        local _tmp_patch_generic=$(cat $PWD/steps/03-resources/patch-generic.json | jq -rc .)
        local _tmp_patch_spec=$(cat $PWD/steps/03-resources/patch-$_name.json | jq -rc .)
        local _tmp_patch_merged=$(jq -rc --argjson arr1 "$_tmp_patch_generic" --argjson arr2 "$_tmp_patch_spec" -n '$arr1 + $arr2')

        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/configPatches", "value": '$_tmp_patch_merged'}]'
        # Put Server as Accepted
        kubectl patch server ${server_id} --type='json' -p='[{"op": "replace", "path": "/spec/accepted", "value": '$(echo $server_data_object | jq -c -r .accepted)'}]'

    fi
}

create_sidero_cluster (){
  if [[ -f ${SIDERO_CLUSTER_PATH} ]];then
    rm ${SIDERO_CLUSTER_PATH}
  fi
  clusterctl generate cluster cluster-0 -i sidero > ${SIDERO_CLUSTER_PATH}
  kubectl apply -f ${SIDERO_CLUSTER_PATH}
}

retrieve_secret_from_cluster (){
  sleep 10
  kubectl \
    get secret \
    cluster-0-talosconfig \
    -o jsonpath='{.data.talosconfig}' \
  | base64 -d \
   > ${SIDERO_CLUSTER_SECRET_PATH}

   talosctl config merge ${SIDERO_CLUSTER_SECRET_PATH}
}

bootstrap_sidero_cluster (){
  # Waiting etcd service to be preparing
  while [ -z "$(talosctl service etcd status 2>/dev/null | grep -E '^STATE\s+Preparing$')" ]; do sleep 30; done
  # Try to launch bootstrap
  while ! talosctl bootstrap; do sleep 60; done
  # Waiting etcd service to be running
  while [ -z "$(talosctl service etcd status 2>/dev/null | grep -E '^HEALTH\s+OK$')" ]; do sleep 30; done
}

accept_all_servers (){
  _servers_object_list=$(kubectl get server -o=json | jq -r -c '.items[].metadata.name')

  for _row in $( echo ${_servers_object_list}); do
      kubectl patch server $_row --type='json' -p '[{"op":"replace", "path":"/spec/accepted", "value": true}]'
  done
}

expand_control_plane (){
  kubectl patch TalosControlPlane cluster-0-cp --context="admin@sidero-local" --type='json' -p '[{"op":"replace", "path":"/spec/replicas", "value": 3}]'
  until test "$(kubectl get TalosControlPlane cluster-0-cp --context="admin@sidero-local" -o json | jq -r .status.readyReplicas)" = "3"
  do
    sleep 30
  done
}

expand_workers(){
  kubectl patch MachineDeployment cluster-0-workers --context="admin@sidero-local" --type='json' -p '[{"op":"replace", "path":"/spec/replicas", "value": 4}]'
  until test "$(kubectl get MachineDeployment cluster-0-workers --context="admin@sidero-local" -o json | jq -r .status.unavailableReplicas)" = "0"
  do
    sleep 30
  done
}

# clean_previous_talos_install
# create_talos_install
# install_sidero_on_talos
# install_sidero_custom_serverclass
# prepare_cillium
# server_cillium

# set +e

# ipmitool -I lan -H 192.168.5.10 -U root -P calvin power cycle
# ipmitool -I lan -H 192.168.5.11 -U root -P calvin power cycle
# ipmitool -I lan -H 192.168.5.12 -U root -P calvin power cycle
# ipmitool -I lan -H 192.168.5.13 -U root -P calvin power cycle
# ipmitool -I lan -H 192.168.5.14 -U root -P calvin power cycle
# ipmitool -I lanplus -H 192.168.5.15 -U root -P calvin power cycle
# ipmitool -I lanplus -H 192.168.5.16 -U root -P calvin power cycle
# ipmitool -I lanplus -H 192.168.5.17 -U root -P calvin power cycle

# set -e

# until test "$(kubectl get server -o json | jq .items | jq length)" = "7"
# do
#   sleep 30
# done

# _servers_object_list=$(kubectl get server -o=json)
# _servers_data_list=$(cat $PWD/data/servers.json | jq -r '.')

# for _row in $( echo ${_servers_data_list} | jq -c -r '.[]'); do
#     patch_server $_row
# done

# create_sidero_cluster

# #watch -c  -n 5 kubectl get servers,machines,clusters

# retrieve_secret_from_cluster

# talosctl config endpoint --context ${TALOS_CTX} ${CONTROL_PLANE_ENDPOINT}
# talosctl config node --context ${TALOS_CTX} ${CONTROL_PLANE_ENDPOINT}

# bootstrap_sidero_cluster
# accept_all_servers
# expand_control_plane
# talosctl config endpoints --context ${TALOS_CTX} ${CONTROL_PLANE_ENDPOINT} 192.168.3.16 192.168.3.17
# talosctl config nodes --context ${TALOS_CTX} ${CONTROL_PLANE_ENDPOINT} 192.168.3.16 192.168.3.17


# expand_workers
# talosctl config nodes --context ${TALOS_CTX} ${CONTROL_PLANE_ENDPOINT} 192.168.3.16 192.168.3.17 192.168.3.10 192.168.3.14

# talosctl kubeconfig --force -e ${CONTROL_PLANE_ENDPOINT} -n ${CONTROL_PLANE_ENDPOINT}


# helm repo add metallb https://metallb.github.io/metallb --kube-context ${CLUSTER_KUBE_CTX}
# helm install metallb metallb/metallb --create-namespace -n metallb-system --kube-context ${CLUSTER_KUBE_CTX}
# kubectl apply -f steps/05-resources/metallb/default-ipaddresspool.yml

# helm repo add bitnami https://charts.bitnami.com/bitnami --kube-context ${CLUSTER_KUBE_CTX}
# helm install nginx bitnami/nginx-ingress-controller --create-namespace -n nginx-system --kube-context ${CLUSTER_KUBE_CTX}

# Install localpv (pre-requis for JIVA)


# Install JIVA
helm repo add openebs-jiva https://openebs.github.io/jiva-operator
helm upgrade --install --create-namespace --namespace openebs --version 3.4.0 openebs-jiva openebs-jiva/jiva \
  --set openebsLocalpv.enabled=true \
  --set defaultPolicy.replicas=1 \
  --set defaultPolicy.replicaSC=local-hostpath

# Patch to share hostPID to container
kubectl --namespace openebs patch daemonset openebs-jiva-csi-node --type=json --patch '[{"op": "add", "path": "/spec/template/spec/hostPID", "value": true}]'
# Patch local-storage to only allocate to specific node
kubectl apply -f ./steps/06-resources/openebs-storageclass.yaml
# Patch pod-security to enable privilege for openebs
kubectl patch namespace openebs -p '{"metadata":{"labels":{"pod-security.kubernetes.io/audit":"privileged","pod-security.kubernetes.io/enforce":"privileged","pod-security.kubernetes.io/warn":"privileged"}}}'
# Patch icsciadm
kubectl apply -f ./steps/06-resources/openebs-jiva-csi-icsciadm.yaml

helm repo add mayastor https://openebs.github.io/mayastor-extensions/ 
# To upgrade version
# helm search repo mayastor --versions
helm upgrade --install mayastor mayastor/mayastor -n mayastor --create-namespace --version 2.2.0 \
  --set etcd.common.storageClass=openebs-jiva-csi-default \
  --set etcd.global.storageClass=openebs-jiva-csi-default \
  --set etcd.persistance.storageClass=openebs-jiva-csi-default \
  --set loki-stack.enabled=false \
  --set etcd.replicaCount=1
# Patch Privileged on namespace
kubectl patch namespace mayastor -p '{"metadata":{"labels":{"pod-security.kubernetes.io/audit":"privileged","pod-security.kubernetes.io/enforce":"privileged","pod-security.kubernetes.io/warn":"privileged"}}}'
kubectl label node r610-5bf035j-eth0 openebs.io/engine=mayastor
kubectl label node c6100-s01-eth0 openebs.io/engine=mayastor
kubectl label node c6100-s02-eth0 openebs.io/engine=mayastor
kubectl label node c6100-s03-eth0 openebs.io/engine=mayastor
kubectl label node c6100-s04-eth0 openebs.io/engine=mayastor
kubectl apply -f ./steps/06-resources/mayastor-pool.yml


# 
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
