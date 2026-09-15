#!/bin/bash

set -e

echo "=========================================="
echo " Kubernetes Common Setup"
echo " Run this script on ALL 3 nodes"
echo "=========================================="

# --------------------------------------------------
# 1. Update system
# --------------------------------------------------

echo "[1/10] Updating Ubuntu..."

sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg \
    containerd


# --------------------------------------------------
# 2. Disable Swap
# --------------------------------------------------

echo "[2/10] Disabling swap..."

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "Swap status:"
free -h


# --------------------------------------------------
# 3. Load Kernel Modules
# --------------------------------------------------

echo "[3/10] Loading kernel modules..."

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter


# --------------------------------------------------
# 4. Configure Kubernetes Networking
# --------------------------------------------------

echo "[4/10] Configuring kernel networking..."

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "IP forwarding:"
sysctl net.ipv4.ip_forward


# --------------------------------------------------
# 5. Configure containerd
# --------------------------------------------------

echo "[5/10] Configuring containerd..."

sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Enable systemd cgroup driver
sudo sed -i \
's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

echo "containerd status:"
sudo systemctl --no-pager status containerd


# --------------------------------------------------
# 6. Kubernetes Repository
# --------------------------------------------------

echo "[6/10] Configuring Kubernetes repository..."

sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL \
https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
| sudo gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' \
| sudo tee /etc/apt/sources.list.d/kubernetes.list


# --------------------------------------------------
# 7. Install Kubernetes
# --------------------------------------------------

echo "[7/10] Installing Kubernetes packages..."

sudo apt-get update

sudo apt-get install -y \
    kubelet \
    kubeadm \
    kubectl

# Prevent automatic upgrades
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet


# --------------------------------------------------
# 8. Verify installations
# --------------------------------------------------

echo "[8/10] Checking versions..."

echo "------------------------------------------"
echo "containerd"
containerd --version

echo "------------------------------------------"
echo "kubeadm"
kubeadm version

echo "------------------------------------------"
echo "kubelet"
kubelet --version

echo "------------------------------------------"
echo "kubectl"
kubectl version --client


# --------------------------------------------------
# 9. Verify Networking
# --------------------------------------------------

echo "[9/10] Checking network configuration..."

echo "------------------------------------------"
echo "IP Forwarding:"
sysctl net.ipv4.ip_forward

echo "------------------------------------------"
echo "Loaded modules:"
lsmod | grep overlay || true
lsmod | grep br_netfilter || true


# --------------------------------------------------
# 10. Final Status
# --------------------------------------------------

echo "[10/10] Final service status..."

echo "------------------------------------------"
sudo systemctl --no-pager is-active containerd

echo "------------------------------------------"
sudo systemctl --no-pager is-enabled containerd

echo "------------------------------------------"

echo "=========================================="
echo " Common Kubernetes setup completed!"
echo "=========================================="

echo ""
echo "IMPORTANT:"
echo "Now:"
echo "  Master  -> run k8s-master.sh"
echo "  Worker1 -> run k8s-worker.sh"
echo "  Worker2 -> run k8s-worker.sh"
echo ""
