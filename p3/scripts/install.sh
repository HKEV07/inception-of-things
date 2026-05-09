# Update and install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Re-update and install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Ensure vagrant user can use docker
sudo usermod -aG docker vagrant

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

k3d cluster create mycluster -p "8888:30007@loadbalancer"

# Share cluster access with vagrant user
mkdir -p /home/vagrant/.kube
k3d kubeconfig get mycluster > /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

kubectl create namespace argocd
kubectl create namespace dev

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml

kubectl wait --for=condition=Ready pod --all -n argocd --timeout=300s


kubectl apply -f /vagrant/confs/application.yaml


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
echo ""
echo "Starting persistent port forwarding..."
su - vagrant -c "
nohup kubectl port-forward svc/argocd-server \
  -n argocd 8080:443 \
  --address 0.0.0.0 \
  > /tmp/argocd-portforward.log 2>&1 &
  
nohup kubectl port-forward svc/wil-playground-service \
  -n dev 8888:8888 \
  --address 0.0.0.0 \
  > /tmp/app-portforward.log 2>&1 &
" 2>/dev/null || true
sleep 2

echo ""
echo "Access from host:"
echo "  Argo CD:     https://192.168.56.110:8080"
echo "  Application: http://192.168.56.110:8888"
echo ""
echo "Argo CD Login: admin / $PASSWORD"
echo "========================================="
