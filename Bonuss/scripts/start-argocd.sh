#!/bin/bash
# bonus/scripts/start-argocd.sh
set -e

export KUBECONFIG=/home/vagrant/.kube/config

# Kill any existing port-forward on 8080
pkill -f "port-forward.*argocd-server" 2>/dev/null \
  && echo "Killed old port-forward" || true

echo "Starting Argo CD port-forward in background..."
nohup kubectl port-forward svc/argocd-server \
  -n argocd 8080:443 \
  --address 0.0.0.0 \
  > /tmp/argocd-portforward.log 2>&1 &

PF_PID=$!
sleep 2

if kill -0 $PF_PID 2>/dev/null; then
  echo "✓ Port-forward running (PID $PF_PID)"
  echo "✓ Open https://192.168.56.110:8080 on your Mac"
  echo "  Logs: tail -f /tmp/argocd-portforward.log"
else
  echo "✗ Port-forward failed — check logs:"
  cat /tmp/argocd-portforward.log
  exit 1
fi

echo ""
echo " Argo CD password reminder:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode && echo