#!/bin/bash

echo "=== PART 3 TESTING SCRIPT ==="
echo ""

export KUBECONFIG=/home/vagrant/.kube/config

# 1. Check cluster
echo "1. Check K3d cluster status:"
kubectl cluster-info
echo ""

# 2. Check nodes
echo "2. Check nodes:"
kubectl get nodes
echo ""

# 3. Check namespaces
echo "3. Check namespaces:"
kubectl get namespaces
echo ""

# 4. Check Argo CD installation
echo "4. Check Argo CD deployment:"
kubectl get deployment -n argocd
echo ""

# 5. Check Argo CD pod status
echo "5. Check Argo CD pods:"
kubectl get pods -n argocd
echo ""

# 6. Check Argo CD service
echo "6. Check Argo CD service:"
kubectl get svc -n argocd
echo ""

# 7. Get Argo CD admin password
echo "7. Argo CD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
echo ""

# 8. Check if Application is created
echo "8. Check Argo CD Application:"
kubectl get applications -n argocd
echo ""

# 9. Check dev namespace
echo "9. Check dev namespace pods:"
kubectl get pods -n dev
echo ""

# 10. Check services in dev
echo "10. Check services in dev namespace:"
kubectl get svc -n dev
echo ""

echo "=== TESTING COMPLETE ==="
