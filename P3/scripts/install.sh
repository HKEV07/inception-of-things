#!/bin/bash

set -e

echo "=== Installing Docker ==="
apt-get update -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

# Add vagrant user to docker group
usermod -aG docker vagrant

echo "=== Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

echo "=== Installing K3d ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "=== Creating K3d cluster ==="
sudo -u vagrant bash << 'SETUP'
export PATH=$PATH:/usr/local/bin

# Create a K3d cluster with port mappings
k3d cluster create inception \
    --servers 1 \
    --agents 1 \
    --port 8888:8888@loadbalancer \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer

# Wait for cluster to be ready
sleep 15

# Get kubeconfig
mkdir -p ~/.kube
k3d kubeconfig get inception > ~/.kube/config
chmod 600 ~/.kube/config

echo "K3d cluster 'inception' created successfully!"
SETUP

echo "=== Installation complete ==="
