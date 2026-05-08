#!/bin/bash
# p3/scripts/install.sh
set -e   # exit immediately if any command fails

echo "=== [1/6] Installing Docker ==="
apt-get update -qq
apt-get install -y -qq \
    ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key and repo
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io

# Allow vagrant user to run docker without sudo
usermod -aG docker vagrant

echo "=== [2/6] Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -sL \
    https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

echo "=== [3/6] Installing K3d ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "=== [4/6] Creating K3d cluster ==="
# Map Port 80 for the Ingress Controller
su - vagrant -c "/usr/local/bin/k3d cluster create iot-cluster \
    --port '80:80@loadbalancer' \
    --agents 2"

su - vagrant -c "/usr/local/bin/k3d kubeconfig merge iot-cluster --kubeconfig-merge-default"

echo "=== [5/6] Installing Argo CD ==="
su - vagrant -c "
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml
echo 'Waiting for Argo CD components to be created...'
sleep 15
echo 'Waiting for Argo CD pods (this may take up to 10 minutes)...'
kubectl wait --for=condition=Ready pod --all -n argocd --timeout=300s

kubectl -n argocd patch deployment argocd-server --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--insecure"}]'
"

echo "=== [6/6] Applying Argo CD Application & Ingress ==="
su - vagrant -c "
# 1. Create the 'dev' namespace explicitly
kubectl create namespace dev || true 
sleep 5
kubectl apply -f /vagrant/confs/application.yaml
kubectl apply -f /vagrant/confs/ingress.yaml
"
echo ""
echo "========================================="
echo "Waiting for admin secret to be created (this may take a few minutes)..."
sleep 10

PASSWORD=""
for i in {1..120}; do
  PASSWORD=$(su - vagrant -c "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null")
  if [ -n "$PASSWORD" ]; then
    echo "✓ Secret found!"
    echo ""
    echo "  Username: admin"
    echo "  Password: $PASSWORD"
    break
  fi
  
  if [ $((i % 10)) -eq 0 ]; then
    echo "  Still waiting... [$i/120 seconds]"
  fi
  sleep 1
done

if [ -z "$PASSWORD" ]; then
  echo "✗ Could not retrieve password (timeout)"
  echo ""
  echo "  Retrieve password manually with:"
  echo "  su - vagrant -c \"kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d\""
fi

echo "========================================="
echo "PRO SETUP COMPLETE"
echo "Application: http://app.iot.com"
echo "Argo CD UI:  http://argocd.iot.com"
echo "User: admin  |  Pass: $PASSWORD"
echo "========================================="
echo "NOTE: Make sure your host machine /etc/hosts has:"
echo "192.168.56.110 app.iot.com argocd.iot.com"
