
# Create the cluster in sidero
```sh
export CONTROL_PLANE_SERVERCLASS=small-ard-serverclass
export WORKER_SERVERCLASS=large-ard-serverclass
export TALOS_VERSION=v0.14.0
export KUBERNETES_VERSION=v1.22.2
export CONTROL_PLANE_PORT=6443
export CONTROL_PLANE_ENDPOINT=192.168.3.15

clusterctl generate cluster cluster-0 -i sidero > cluster-0.yaml
```


```sh
    kubectl apply -f cluster-0.yaml
```

```sh
    watch kubectl get servers,machines,clusters
```

# Extract Talos configuration for all the machine in the cluster

```sh
kubectl \
    get secret \
    cluster-0-talosconfig \
    -o jsonpath='{.data.talosconfig}' \
  | base64 -d \
   > cluster-0-talosconfig
```

# Init the bootstrap on the cluster
```sh
    talosctl bootstrap --context=cluster-0 -n 192.168.3.15
```

# Scale controlplane to x

# Scale worker to x

# Retrieve Kubeconfig
```sh
    talosctl --talosconfig cluster-0-talosconfig --nodes 192.168.3.15 kubeconfig
```
