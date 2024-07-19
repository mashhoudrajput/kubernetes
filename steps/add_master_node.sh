#!/bin/bash

set -e

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <path_of_folder> <new_master_node_hostname> <new_master_node_ip> <existing_master_node_ip>"
    exit 1
fi

FOLDER_PATH=$1
NEW_MASTER_NODE_HOSTNAME=$2
NEW_MASTER_NODE_IP=$3
EXISTING_MASTER_NODE_IP=$4
SSH_USER="root"

# Change to the specified directory
cd $FOLDER_PATH

# Check if node is already part of the cluster
if ssh $SSH_USER@$NEW_MASTER_NODE_IP "kubectl get nodes | grep -q $NEW_MASTER_NODE_HOSTNAME"; then
    echo "Node $NEW_MASTER_NODE_HOSTNAME is already part of the cluster. Exiting."
    exit 1
fi

# Execute the steps in sequence
./set_hostname.sh $NEW_MASTER_NODE_HOSTNAME $NEW_MASTER_NODE_IP
./configure_sysctl.sh $NEW_MASTER_NODE_IP
./install_docker.sh $NEW_MASTER_NODE_IP
./configure_containerd.sh $NEW_MASTER_NODE_IP
./install_kubernetes.sh $NEW_MASTER_NODE_IP
./join_master.sh $NEW_MASTER_NODE_IP $EXISTING_MASTER_NODE_IP

echo "New master node setup complete."

