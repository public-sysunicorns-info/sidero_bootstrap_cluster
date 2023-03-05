#!/usr/bin/env bash

set -eu

if [[ -f /usr/local/bin/kubectl ]];then
    sudo rm /usr/local/bin/kubectl
fi

sudo curl -Lo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$(\
  curl -L -s https://dl.k8s.io/release/stable.txt\
  )/bin/linux/amd64/kubectl"

sudo chmod +x /usr/local/bin/kubectl



if [[ -f /usr/local/bin/clusterctl ]];then
    sudo rm /usr/local/bin/clusterctl
fi

sudo curl -Lo /usr/local/bin/clusterctl \
  "https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.1/clusterctl-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64"

sudo chmod +x /usr/local/bin/clusterctl



if [[ -f /usr/local/bin/talosctl ]];then
    sudo rm /usr/local/bin/talosctl
fi

sudo curl -Lo /usr/local/bin/talosctl https://github.com/talos-systems/talos/releases/latest/download/talosctl-$(uname -s | tr "[:upper:]" "[:lower:]")-amd64
sudo chmod +x /usr/local/bin/talosctl

