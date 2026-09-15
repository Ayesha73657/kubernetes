#!/bin/bash

set -e

# ==================================================
# Kubernetes Master / Control Plane Setup
# ==================================================

# CHANGE THIS
MASTER_IP="10.0.1.10"

# Pod Network CIDR
POD_CIDR="192.168.0.0/16"

echo "=========================================="
echo " Kubernetes MASTER Setup"
echo "=========================================="

echo "Master IP : $MASTER_IP"
echo "Pod CIDR  : $POD_CIDR"

# --------------------------------------------------
# 1. Verify Master IP
# --------------------------------------------------

echo ""
echo "[1/7] Checking IP addresses..."

hostname -I

echo ""
echo "Make sure the configured MASTER_IP is correct:"
echo "$MASTER_IP"

read -p "Continue? [y/N]: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Setup cancelled."
    exit 1
fi


# --------------------------------------------------
# 2. Initialize Kubernetes
# --------------------------------------------------

echo ""
echo "[2/7] Initializing Kubernetes Control Plane..."

sudo kubeadm init \
    --apiserver-advertise-address="$MASTER_IP" \
    --pod-network-cidr="$POD_CIDR"


# --------------------------------------------------
# 3. Configure kubectl
# --------------------------------------------------

echo ""
echo "[3/7] Configuring kubectl..."

mkdir -p "$HOME/.kube"

sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"

sudo chown \
    "$(id -u):$(id -g)" \
    "$HOME/.kube/config"


# --------------------------------------------------
# 4. Verify Kubernetes
# --------------------------------------------------

echo ""
echo "[4/7] Checking Kubernetes..."

kubectl get nodes


# --------------------------------------------------
# 5. Install Calico
# --------------------------------------------------

echo ""
echo "[5/7] Installing Calico CNI..."

# Calico CRDs
kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/v1_crd_projectcalico_org.yaml

# Tigera Operator
kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/tigera-operator.yaml


# --------------------------------------------------
# 6. Create Calico Installation
# --------------------------------------------------

echo ""
echo "[6/7] Creating Calico configuration..."

cat <<EOF > /tmp/calico-custom-resources.yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: $POD_CIDR
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF

kubectl create -f /tmp/calico-custom-resources.yaml


# --------------------------------------------------
# 7. Wait and verify
# --------------------------------------------------

echo ""
echo "[7/7] Waiting for Kubernetes components..."

sleep 20

echo ""
echo "=========================================="
echo " Kubernetes Nodes"
echo "=========================================="

kubectl get nodes -o wide

echo ""
echo "=========================================="
echo " Kubernetes Pods"
echo "=========================================="

kubectl get pods -A

echo ""
echo "=========================================="
echo " GENERATING WORKER JOIN COMMAND"
echo "=========================================="

JOIN_COMMAND=$(kubeadm token create --print-join-command)

echo ""
echo "$JOIN_COMMAND"
echo ""

echo "=========================================="
echo " SAVE THE ABOVE JOIN COMMAND"
echo " Run it on Worker 1 and Worker 2"
echo "=========================================="

echo "$JOIN_COMMAND" > "$HOME/worker-join-command.sh"

chmod +x "$HOME/worker-join-command.sh"

echo ""
echo "Join command saved here:"
echo "$HOME/worker-join-command.sh"

echo ""
echo "Master setup completed."
