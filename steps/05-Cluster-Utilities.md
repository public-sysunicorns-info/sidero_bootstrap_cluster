
# Install Metallb

```sh
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb --create-namespace -n metallb-system
```

Set IpAddressPool and L2Advertising

Setup Static Routing on your router

# Instal Nginx Ingress Controller
```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-release bitnami/nginx-ingress-controller --create-namespace -n nginx-system
```