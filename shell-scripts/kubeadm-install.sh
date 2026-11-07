
#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
# Kubernetes node preparation
# Installs containerd, kubeadm, kubelet and kubectl.
# Does NOT initialize or join a cluster.
# =========================================================

K8S_MINOR="${K8S_MINOR:-v1.33}"

log() {
  echo
  echo "[$(date '+%F %T')] $*"
}

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as root: sudo bash $0"
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "ERROR: Cannot identify the operating system."
  exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "ERROR: This script supports Ubuntu only."
  exit 1
fi

log "Installing prerequisite packages"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  curl \
  gpg \
  socat \
  conntrack \
  apt-transport-https \
  tree

log "Disabling swap"

swapoff -a

# Comment out active swap entries in /etc/fstab
if [[ -f /etc/fstab ]]; then
  sed -ri \
    '/^[[:space:]]*[^#].*[[:space:]]swap[[:space:]]/ s/^/# disabled-for-kubernetes: /' \
    /etc/fstab
fi

log "Configuring kernel modules"

cat > /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

log "Configuring Kubernetes networking"

cat > /etc/sysctl.d/kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

log "Adding Docker repository for containerd"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor --yes \
      -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release
UBUNTU_CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y containerd.io

log "Configuring containerd"

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

# Enable the systemd cgroup driver.
# The generated default config has a SystemdCgroup setting.
if grep -q 'SystemdCgroup = false' /etc/containerd/config.toml; then
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' \
    /etc/containerd/config.toml
fi

if ! grep -q 'SystemdCgroup = true' /etc/containerd/config.toml; then
  echo "ERROR: Could not enable SystemdCgroup. Inspect containerd config."
  exit 1
fi

systemctl enable --now containerd
systemctl restart containerd

log "Adding Kubernetes ${K8S_MINOR} repository"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor --yes \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /
EOF

apt-get update

log "Installing kubeadm, kubelet and kubectl"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
  kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

log "Validating installation"

echo
echo "=== Versions ==="
containerd --version
kubeadm version
kubelet --version
kubectl version --client

echo
echo "=== Services ==="
systemctl is-active containerd
systemctl is-enabled kubelet

echo
echo "=== Kernel settings ==="
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables

echo
echo "=== Swap status (should be empty) ==="
swapon --show

echo
log "NODE PREPARATION COMPLETED"
echo "No Kubernetes cluster has been initialized or joined."
echo
echo "Next steps:"
echo "  Control plane: sudo kubeadm init ..."
echo "  Workers:       run the kubeadm join command from the control plane."
echo "  CNI:           install a compatible network plugin."