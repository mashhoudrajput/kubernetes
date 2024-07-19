#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server_ip>"
    exit 1
fi

SERVER_IP=$1
SSH_USER="root"

# Uninstall Docker and Kubernetes
ssh $SSH_USER@$SERVER_IP "sudo kubeadm reset -f && sudo systemctl stop kubelet && sudo systemctl stop docker && sudo apt-mark unhold kubelet kubeadm kubectl && sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni kube* docker-ce docker-ce-cli containerd.io && sudo apt-get autoremove -y && sudo rm -rf ~/.kube /etc/systemd/system/kubelet.service.d /etc/systemd/system/kubelet.service /usr/bin/kube* /usr/local/bin/kubectl /var/lib/dockershim /var/lib/kubelet /var/lib/etcd /etc/kubernetes /var/run/kubernetes /etc/cni/net.d && sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli containerd containerd.io && sudo apt-get autoremove -y --purge docker-engine docker docker.io docker-ce && sudo rm -rf /var/lib/docker /etc/docker /var/run/docker.sock /usr/bin/docker-compose"
echo "Docker and Kubernetes uninstalled on $SERVER_IP"

