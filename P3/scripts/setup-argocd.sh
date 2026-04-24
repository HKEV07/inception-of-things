#!/bin/bash

set -e

export KUBECONFIG=/home/vagrant/.kube/config
export PATH=$PATH:/usr/local/bin

echo "=== Waiting for K3d cluster ==="
until kubectl cluster-info; do
  echo "Waiting for cluster..."
  sleep 5
done

echo "=== Creating namespaces ==="
kubectl apply -f /home/vagrant/confs/argocd-namespace.yaml
kubectl apply -f /home/vagrant/confs/dev-namespace.yaml

echo "=== Installing Argo CD ==="
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Waiting for Argo CD to be ready ==="
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

echo "=== Argo CD installed ==="
echo ""
echo "=== IMPORTANT: Update the Argo CD Application manifest ==="
echo "Edit /home/vagrant/confs/argocd-application.yaml and replace:"
echo "  - YOUR_GITHUB_USERNAME with your GitHub username"
echo "  - YOUR_REPO_NAME with your repository name"
echo ""
echo "Then apply it with:"
echo "  kubectl apply -f /home/vagrant/confs/argocd-application.yaml"
echo ""
echo "=== Access Argo CD ==="
echo "Port-forward Argo CD:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Get initial admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "Access at: http://localhost:8080"
echo "Username: admin"
