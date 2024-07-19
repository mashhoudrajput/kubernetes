#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <server_ip> <control_plane_ip>"
    exit 1
fi

SERVER_IP=$1
CONTROL_PLANE_IP=$2
CONTROL_PLANE_ENDPOINT="172.31.45.81:6443"
SSH_USER="root"
DETAILS_FILE="kubeadm-join-details.txt"

# Function to check SSH connectivity
check_ssh() {
    if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$1 "exit"; then
        return 0
    else
        echo "Unable to SSH into $1"
        exit 1
    fi
}

# Function to read details from file
read_details_from_file() {
    if [ -f "$DETAILS_FILE" ]; then
        source "$DETAILS_FILE"
        if [ -n "$token" ] && [ -n "$hash_key" ] && [ -n "$certificate_key" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to write details to file
write_details_to_file() {
    echo "token=$token" > "$DETAILS_FILE"
    echo "hash_key=$hash_key" >> "$DETAILS_FILE"
    echo "certificate_key=$certificate_key" >> "$DETAILS_FILE"
}

# Function to validate token
validate_token() {
    ssh $SSH_USER@$CONTROL_PLANE_IP "kubeadm token list | grep -q $token"
}

# Function to validate certificate key
validate_certificate_key() {
    ssh $SSH_USER@$CONTROL_PLANE_IP "kubectl get secret -n kube-system kubeadm-certs -o jsonpath='{.data}'" &> /dev/null
}

# Check SSH connectivity
check_ssh $SERVER_IP

# Get the node's hostname
NODE_NAME=$(ssh $SSH_USER@$SERVER_IP "hostname")

# Check if the node is already part of the cluster
if ssh $SSH_USER@$CONTROL_PLANE_IP "kubectl get nodes | grep -w $NODE_NAME"; then
    echo "Node $NODE_NAME is already part of the cluster."
else
    if read_details_from_file && validate_token && validate_certificate_key; then
        echo "Using existing valid details from $DETAILS_FILE"
    else
        certificate_key=$(ssh $SSH_USER@$CONTROL_PLANE_IP "kubeadm init phase upload-certs --upload-certs | tail -n 1")
        join_command=$(ssh $SSH_USER@$CONTROL_PLANE_IP "kubeadm token create --print-join-command --certificate-key $certificate_key")
        token=$(echo $join_command | grep -oP '(?<=--token\s)[^\s]+')
        hash_key=$(echo $join_command | grep -oP '(?<=--discovery-token-ca-cert-hash\s)[^\s]+')
        write_details_to_file
    fi

    # Construct the kubeadm join command
    KUBEADM_JOIN_CMD="kubeadm join $CONTROL_PLANE_ENDPOINT --token $token --discovery-token-ca-cert-hash $hash_key --control-plane --certificate-key $certificate_key"
    echo $KUBEADM_JOIN_CMD

    # Validate the kubeadm join command by checking token, hash_key, and certificate_key
    token_valid=$(ssh $SSH_USER@$CONTROL_PLANE_IP "kubeadm token list | grep -q $token && echo valid || echo invalid")
    certificate_key_valid=$(validate_certificate_key && echo valid || echo invalid)

    if [ "$token_valid" == "valid" ]; then
        echo "Token is valid."
    else
        echo "Token is invalid."
        exit 1
    fi

    if [[ $hash_key =~ ^sha256:[a-f0-9]{64}$ ]]; then
        echo "Hash key is valid."
    else
        echo "Hash key is invalid."
        exit 1
    fi

    if [ "$certificate_key_valid" == "valid" ]; then
        echo "Certificate key is valid."
    else
        echo "Certificate key is invalid."
        exit 1
    fi

    ssh $SSH_USER@$SERVER_IP "$KUBEADM_JOIN_CMD"
    ssh $SSH_USER@$SERVER_IP "mkdir -p \$HOME/.kube && sudo rm \$HOME/.kube/config && sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config && sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
fi

