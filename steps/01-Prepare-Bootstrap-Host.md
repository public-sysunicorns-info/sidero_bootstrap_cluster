# A / Install Cli Tools
[from sidero documentation](https://www.sidero.dev/v0.5/getting-started/prereq-cli-tools/)

## A.1 / kubectl
```sh
sudo curl -Lo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$(\
  curl -L -s https://dl.k8s.io/release/stable.txt\
  )/bin/linux/amd64/kubectl"
sudo chmod +x /usr/local/bin/kubectl
```

## A.2 / clusterctl
```sh
sudo curl -Lo /usr/local/bin/clusterctl \
  "https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.1/clusterctl-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64" \
sudo chmod +x /usr/local/bin/clusterctl
```

## A.3 / talosctl
```sh
sudo curl -Lo /usr/local/bin/talosctl \
 "https://github.com/talos-systems/talos/releases/latest/download/talosctl-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64"
chmod +x /usr/local/bin/talosctl
```

# B / Install Docker Desktop or Minikube

You need to be able to route UDP traffic to the kubernetes host (you or the vm).
For example RancherDesktop not work with UDP and due to that you need to find another solution like the two one propose here.
This is only for the bootstrap phase, after the "Pivoting" you don't need any more the local cluster.

## B.1 / (Simple and Use for the next step) Docker Desktop
[Docker Desktop Documentation](https://www.docker.com/products/docker-desktop/)

### B.1.1 / Install Docker Desktop
[DockerDesktop - Get Started](https://docs.docker.com/get-started/)

### B.1.2 / Create Talosctl Bootstrap cluster ( in one container )
[from sidero documentation](https://www.sidero.dev/v0.5/getting-started/prereq-kubernetes/)

``` sh
#!/bin/bash

# Change to the one of your hosting sidero machine
# For DockerDesktop Install, the host ip
# For Minikube, the ip of the minikube host (retrieve by `minikube ip` command)
export HOST_IP="192.168.2.44"

# Create a kube in single container
talosctl cluster create \
  --name sidero-local \
  -p 69:69/udp,8081:8081/tcp,51821:51821/udp \
  --workers 0 \
  --config-patch '[{"op": "add", "path": "/cluster/allowSchedulingOnMasters", "value": true}]' \
  --endpoint $HOST_IP
```

## B.2 / (Custom) Minikube
[Minikube Documentation](https://minikube.sigs.k8s.io/docs/start/)
[Minikube Documentation Hyper-V](https://minikube.sigs.k8s.io/docs/drivers/hyperv/)
Hyper-V with custom external switch

Enable Hyper-V
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

Get your actual adapter name
```powershell
Get-NetAdapter
```

Create a new virtual switch on your adapter (share with you current OS)
```powershell
New-VMSwitch -name NewExternalSwitch  -NetAdapterName Ethernet -AllowManagementOS $true
```

Set Minikube config to use hyperv with the correct virtual switch
```powershell
minikube config set driver hyperv
minikube config set hyperv-virtual-switch NewExternalSwitch
```

# C / Install Sidero in this cluster

Before executing the command, you need to be sure that your current kubernetes context is the one where you want to install sidero.

```sh
#!/bin/bash

# Change to the one of your hosting sidero machine
# For DockerDesktop Install, the host ip
# For Minikube, the ip of the minikube host (retrieve by `minikube ip` command)
export HOST_IP="192.168.2.44"

export SIDERO_CONTROLLER_MANAGER_HOST_NETWORK=true
export SIDERO_CONTROLLER_MANAGER_API_ENDPOINT=$HOST_IP
export SIDERO_CONTROLLER_MANAGER_SIDEROLINK_ENDPOINT=$HOST_IP

clusterctl init -b talos -c talos -i sidero

```

# Add custom serverclass
[Sidero ServerClass Documentation](https://www.sidero.dev/v0.5/resource-configuration/serverclasses/)


