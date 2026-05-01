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
# Run docker commands as vagrant (needs docker group)
su - vagrant -c "k3d cluster create iot-cluster \
    --port '8888:30000@loadbalancer' \
    --agents 2"

# Export kubeconfig for vagrant user
su - vagrant -c "k3d kubeconfig merge iot-cluster \
    --kubeconfig-merge-default"

echo "=== [5/6] Installing Argo CD ==="
su - vagrant -c "
kubectl create namespace argocd
kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml
# Wait for all Argo CD pods to be ready
kubectl wait --for=condition=Ready pods \
    --all -n argocd --timeout=300s
"

echo "=== [6/6] Applying Argo CD Application ==="
su - vagrant -c "
kubectl apply -f /vagrant/confs/application.yaml
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

echo ""
echo "========================================="
echo ""
echo "To access Argo CD UI from your host machine:"
echo "  1. Run inside VM:  bash /vagrant/scripts/start-argocd.sh"
echo "  2. Open on Mac:    https://192.168.56.110:8080"
echo "  3. Login:          admin / (password above)"

#!/bin/bash
# Run this manually after vagrant ssh to expose Argo CD UI

export KUBECONFIG=/home/vagrant/.kube/config

# Kill any previous port-forward on 8080
pkill -f "port-forward.*argocd-server" 2>/dev/null && echo "Killed old port-forward"

echo "Starting Argo CD port-forward in background..."
nohup kubectl port-forward svc/argocd-server \
  -n argocd 8080:443 \
  --address 0.0.0.0 \
  > /tmp/argocd-portforward.log 2>&1 &

PF_PID=$!
sleep 2

# Verify it actually started
if kill -0 $PF_PID 2>/dev/null; then
  echo "✓ Port-forward running (PID $PF_PID)"
  echo "✓ Open https://192.168.56.110:8080 on your Mac"
  echo "  Logs: tail -f /tmp/argocd-portforward.log"
else
  echo "✗ Port-forward failed — check logs:"
  cat /tmp/argocd-portforward.log
fi
