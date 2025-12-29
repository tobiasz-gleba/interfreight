#!/bin/bash

set -e

# Use a stable k3s version known to work with Flux
INSTALL_K3S_EXEC="--disable traefik --disable local-storage --write-kubeconfig-mode 644"

echo "Updating system and installing dependencies..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl open-iscsi

curl -sfL https://get.k3s.io | sh -s - $INSTALL_K3S_EXEC

sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

echo "Verifying k3s installation..."
k3s --version

if ! sudo systemctl is-active --quiet k3s; then
    echo "Starting k3s service..."
    sudo systemctl start k3s
fi

kubectl get nodes

echo "k3s cluster installation complete!"

sudo ufw allow 6443/tcp

# Cluster configuration
MASTER_HOSTNAME="linux-server"

# List of worker nodes to add to the cluster
# Add more nodes here in the future
WORKER_NODES=()

echo ""
echo "=========================================="
echo "Installing k3s worker nodes"
echo "=========================================="

# Get the master node token
K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)

# Use master hostname for K3S_URL
K3S_URL="https://${MASTER_HOSTNAME}:6443"

echo "Master hostname: $MASTER_HOSTNAME"
echo "K3S URL: $K3S_URL"
echo "Number of worker nodes to install: ${#WORKER_NODES[@]}"
echo ""

# Install k3s on each worker node
for WORKER_NODE in "${WORKER_NODES[@]}"; do
    echo "Installing worker node: $WORKER_NODE"
    echo "----------------------------------------"
    
    ssh $WORKER_NODE << EOF
set -e

echo "Updating system and installing dependencies..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl open-iscsi


curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

echo "Verifying k3s agent installation..."
sudo systemctl status k3s-agent --no-pager

echo "k3s agent installation complete!"
EOF

    echo "✓ Worker node $WORKER_NODE installed successfully!"
    echo ""
done

echo ""
echo "=========================================="
echo "All worker nodes installation complete!"
echo "=========================================="
echo "Verifying nodes in the cluster..."
sleep 5
kubectl get nodes

