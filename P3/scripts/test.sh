#!/bin/bash

export KUBECONFIG=/home/vagrant/.kube/config
export PATH=$PATH:/usr/local/bin

echo "=========================================="
echo "PART 3 TESTING - K3d and Argo CD"
echo "=========================================="
echo ""

# 1. Check K3d cluster
echo "1. K3d Cluster Status:"
kubectl cluster-info | head -3
echo ""

# 2. Check nodes
echo "2. Cluster Nodes:"
kubectl get nodes -o wide
echo ""

# 3. Check namespaces
echo "3. Namespaces:"
kubectl get namespaces
echo ""

# 4. Check Argo CD pods
echo "4. Argo CD Pods:"
kubectl get pods -n argocd --no-headers 2>/dev/null | head -5
echo ""

# 5. Check Argo CD Application
echo "5. Argo CD Applications:"
kubectl get applications -n argocd
echo ""

# 6. Check dev namespace
echo "6. Dev Namespace Pods:"
kubectl get pods -n dev
echo ""

# 7. Check deployment status
echo "7. Deployment Status in dev:"
kubectl get deployment -n dev
echo ""

# 8. Get pod details
echo "8. Pod Details (if running):"
kubectl get pods -n dev -o wide 2>/dev/null || echo "No pods running yet"
echo ""

# 9. Test the application (if port-forward available)
echo "9. Testing Application (port 8888):"
echo "Note: To test, run in another terminal:"
echo "  kubectl port-forward svc/playground -n dev 8888:8888"
echo "Then curl http://localhost:8888/"
echo ""

# 10. Access Argo CD
echo "10. To Access Argo CD UI:"
echo "Run in another terminal:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Then visit: https://localhost:8080"
echo "Username: admin"
echo "Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(password not yet available)"
echo ""
kubectl get pods -n dev
echo ""

# 10. Check services in dev
echo "10. Check services in dev namespace:"
kubectl get svc -n dev
echo ""

echo "=== TESTING COMPLETE ==="
