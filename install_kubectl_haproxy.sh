#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <haproxy_server_ip> <kmaster1_ip>"
    exit 1
fi

HAPROXY_SERVER_IP=$1
KMASTER1_IP=$2
SSH_USER="root"

# Function to install kubectl
install_kubectl() {
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl telnet net-tools jq
    sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
}

# SSH into the HAProxy server and install kubectl
ssh $SSH_USER@$HAPROXY_SERVER_IP "$(typeset -f install_kubectl); install_kubectl"
echo "kubectl installed on $HAPROXY_SERVER_IP"

# Copy Kubernetes configuration from kmaster1 to the HAProxy server
scp $SSH_USER@$KMASTER1_IP:/etc/kubernetes/admin.conf /tmp/admin.conf

# SSH into the HAProxy server and configure kubectl
ssh $SSH_USER@$HAPROXY_SERVER_IP "sudo mkdir -p /etc/kubernetes"
scp /tmp/admin.conf $SSH_USER@$HAPROXY_SERVER_IP:/etc/kubernetes/admin.conf
ssh $SSH_USER@$HAPROXY_SERVER_IP "mkdir -p \$HOME/.kube && sudo rm -f \$HOME/.kube/config && sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config && sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo "kubectl configured on $HAPROXY_SERVER_IP using the configuration from kmaster1"

