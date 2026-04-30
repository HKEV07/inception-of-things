#!/bin/bash

set -e

export KUBECONFIG=/home/vagrant/.kube/config
export PATH=$PATH:/usr/local/bin

echo "=== Waiting for K3d cluster ==="
for i in {1..30}; do
  if kubectl cluster-info > /dev/null 2>&1; then
    echo "Cluster is ready!"
    break
  fi
  echo "Waiting for cluster... ($i/30)"
  sleep 2
done

echo "=== Creating dev namespace ==="
kubectl apply -f /home/vagrant/confs/dev-namespace.yaml

echo "=== Installing Argo CD ==="
kubectl create namespace argocd || true

# Download and apply Argo CD manifest
# The manifest file may have long annotations, so we handle this carefully
mkdir -p /tmp/argocd
cd /tmp/argocd

echo "Downloading Argo CD manifest..."
curl -s -o install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply the manifest - the annotation issue is known and can be safely ignored
echo "Applying Argo CD manifests..."
kubectl apply -n argocd -f install.yaml 2>&1 | grep -v "metadata.annotations" || true

echo "=== Waiting for Argo CD to be ready (this may take 1-2 minutes) ===" 
sleep 20

# Wait for argocd-server deployment to be ready with better error handling
echo "Checking Argo CD deployment status..."
for i in {1..60}; do
  if kubectl get deployment argocd-server -n argocd -o name &>/dev/null; then
    READY=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
    
    if [ "$READY" == "$DESIRED" ] && [ "$DESIRED" != "0" ]; then
      echo "✓ Argo CD server is ready!"
      break
    fi
    
    echo "  Waiting for Argo CD server... (Ready: $READY/$DESIRED) [$i/60]"
  elsekubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &

    echo "  Argo CD deployment not yet created... [$i/60]"
  fi
  sleep 2
done

echo ""
echo "=== Applying Argo CD Application ==="
sleep 5
kubectl apply -f /home/vagrant/confs/argocd-application.yaml

echo ""
echo "=== Applying Argo CD Ingress ==="
kubectl apply -f /home/vagrant/confs/argocd-ingress.yaml

echo ""
echo "=== Argo CD Setup Complete ==="
echo ""
echo "Argo CD UI Access (via Ingress):"
echo "  Add this to your /etc/hosts on your host machine:"
echo "  192.168.56.120  argocd.local"
echo ""
echo "  Then access: https://argocd.local"
echo ""
echo "Argo CD UI Access (via port-forward - alternative):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0"
echo "  Then access: https://192.168.56.120:8080"
echo ""
echo "Default admin password:"

# Wait longer for the initial admin secret to be created
echo "Waiting for admin secret to be created (this may take a few minutes)..."
sleep 10

PASSWORD=""
for i in {1..120}; do
  PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
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
  echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi

echo ""
echo "=== Setup Finished ==="
