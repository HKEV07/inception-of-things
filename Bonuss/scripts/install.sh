#!/bin/bash
# bonus/scripts/install.sh
set -e

# ── 1. Docker ────────────────────────────────────────────────────────────────
echo "=== [1/6] Installing Docker ==="
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release git

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
usermod -aG docker vagrant

# ── 2. kubectl ───────────────────────────────────────────────────────────────
echo "=== [2/6] Installing kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -sL \
    https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/kubectl

# ── 3. K3d + Helm ────────────────────────────────────────────────────────────
echo "=== [3/6] Installing K3d and Helm ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ── 4. K3d cluster ───────────────────────────────────────────────────────────
echo "=== [4/6] Creating K3d cluster ==="
su - vagrant -c "
  k3d cluster create iot-cluster \
    --port '8888:30000@loadbalancer' \
    --port '8080:30080@loadbalancer' \
    --agents 2

  k3d kubeconfig merge iot-cluster --kubeconfig-merge-default
  echo 'export KUBECONFIG=\$HOME/.kube/config' >> /home/vagrant/.bashrc
"

# ── 5. Argo CD ───────────────────────────────────────────────────────────────
echo "=== [5/6] Installing Argo CD ==="
su - vagrant -c "
  kubectl create namespace argocd
  kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  kubectl wait --for=condition=Ready pods \
    --all -n argocd --timeout=300s
"

# ── 6. GitLab via Helm ───────────────────────────────────────────────────────
echo "=== [6/6] Installing GitLab ==="
su - vagrant -c "
  kubectl create namespace gitlab

  helm repo add gitlab https://charts.gitlab.io/
  helm repo update

  helm upgrade --install gitlab gitlab/gitlab \
    --namespace gitlab \
    --timeout 600s \
    --set global.hosts.domain=192.168.56.110.nip.io \
    --set global.hosts.externalIP=192.168.56.110 \
    --set global.ingress.enabled=false \
    --set nginx-ingress.enabled=false \
    --set certmanager-issuer.email=admin@gitlab.local \
    --set global.ingress.configureCertmanager=false \
    --set gitlab-runner.install=false \
    --set prometheus.install=false \
    --set registry.enabled=false \
    --set gitlab.webservice.service.type=NodePort \
    --set gitlab.webservice.service.nodePort=30080 \
    --set global.shell.port=30022 \
    --set global.edition=ce

  echo 'Waiting for GitLab webservice pod to be scheduled...'
  sleep 60

  kubectl wait --for=condition=Ready pods \
    -l app=webservice \
    -n gitlab \
    --timeout=600s
"

# ── Print summary ─────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo " Argo CD admin password:"
su - vagrant -c "
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 --decode && echo
"
echo ""
echo " GitLab root password:"
su - vagrant -c "
  kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
    -o jsonpath='{.data.password}' | base64 --decode && echo
"
echo "========================================="
echo ""
echo "Next steps after vagrant ssh:"
echo "  1. bash /vagrant/scripts/gitlab-setup.sh"
echo "  2. bash /vagrant/scripts/start-argocd.sh"
echo "  3. Open https://192.168.56.110:8080 on your Mac"