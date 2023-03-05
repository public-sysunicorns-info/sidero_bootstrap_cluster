

## Prepare Custom CNI Cilium

```sh
helm repo add cilium https://helm.cilium.io/
helm repo update

export KUBERNETES_API_SERVER_ADDRESS=192.168.3.15
export KUBERNETES_API_SERVER_PORT=6443

if test -f "$PWD/data/webserver/cilium.yaml"; then
    rm $PWD/data/webserver/cilium.yaml
fi

helm template cilium cilium/cilium \
    --version 1.11.2 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost="${KUBERNETES_API_SERVER_ADDRESS}" \
    --set k8sServicePort="${KUBERNETES_API_SERVER_PORT}" > $PWD/data/webserver/cilium.yaml

```

## Execute Patch Script

Serve an http local server to provide the configs to the cluster
```sh
    docker run -dit --name serving-config -p 8090:80 -v "$PWD/data/webserver":/usr/local/apache2/htdocs/ httpd:2.4  
```

Wait for all the wanted server to be listed in 
```sh
    kubectl get servers
```

[link: Add disks to nodes](https://kubito.dev/posts/talos-linux-additonal-disks-to-nodes/)

Execute the patch
```sh
    ./patch_server.sh
```