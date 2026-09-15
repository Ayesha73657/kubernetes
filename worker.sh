#!/bin/bash

set -e

# ==================================================
# Kubernetes Worker Setup
# ==================================================

echo "=========================================="
echo " Kubernetes WORKER Setup"
echo "=========================================="

echo ""
echo "Current hostname:"
hostname

echo ""
echo "Current IP:"
hostname -I

echo ""
echo "Before continuing:"
echo "1. Kubernetes common setup must be completed."
echo "2. Master must already be initialized."
echo "3. You must have the kubeadm join command."
echo ""

# --------------------------------------------------
# Ask for join command
# --------------------------------------------------

read -p "Paste kubeadm join command: " JOIN_COMMAND

if [[ -z "$JOIN_COMMAND" ]]; then
    echo "ERROR: Join command cannot be empty."
    exit 1
fi


# --------------------------------------------------
# Verify Master API Server connectivity
# --------------------------------------------------

echo ""
echo "Checking Kubernetes API Server connectivity..."

echo ""
echo "IMPORTANT:"
echo "The command will use the Master API Server."
echo ""

# Extract API server from join command
MASTER_ENDPOINT=$(echo "$JOIN_COMMAND" | awk '{print $3}')

echo "Master endpoint:"
echo "$MASTER_ENDPOINT"

MASTER_HOST=$(echo "$MASTER_ENDPOINT" | cut -d: -f1)

MASTER_PORT=$(echo "$MASTER_ENDPOINT" | cut -d: -f2)

echo ""
echo "Testing port $MASTER_PORT on $MASTER_HOST..."

if command -v nc >/dev/null 2>&1; then

    if nc -z -w 5 "$MASTER_HOST" "$MASTER_PORT"; then
        echo "API Server is reachable."
    else
        echo "ERROR: Cannot reach Kubernetes API Server."
        echo ""
        echo "Check:"
        echo " - AWS Security Group"
        echo " - Master private IP"
        echo " - TCP port 6443"
        echo " - Network connectivity"
        exit 1
    fi

else

    echo "netcat is not installed."
    echo "Skipping port test."

fi


# --------------------------------------------------
# Join cluster
# --------------------------------------------------

echo ""
echo "=========================================="
echo " Joining Kubernetes Cluster"
echo "=========================================="

sudo $JOIN_COMMAND


# --------------------------------------------------
# Verify kubelet
# --------------------------------------------------

echo ""
echo "Checking kubelet..."

sudo systemctl enable kubelet

sudo systemctl --no-pager status kubelet


# --------------------------------------------------
# Final message
# --------------------------------------------------

echo ""
echo "=========================================="
echo " Worker joined successfully!"
echo "=========================================="

echo ""
echo "Go to the MASTER and run:"
echo ""
echo "kubectl get nodes -o wide"
echo ""
