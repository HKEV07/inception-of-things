#!/bin/bash

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 30

# Set kubeconfig
export KUBECONFIG=/home/vagrant/.kube/config

# Wait for kubectl to be available
until kubectl cluster-info; do
  echo "Waiting for Kubernetes cluster..."
  sleep 5
done

echo "Kubernetes cluster is ready!"

# Deploy applications
echo "Deploying applications..."
kubectl apply -f /home/vagrant/confg/app-1.yaml
kubectl apply -f /home/vagrant/confg/app-2.yaml
kubectl apply -f /home/vagrant/confg/app-3.yaml
kubectl apply -f /home/vagrant/confg/agress.yaml

# echo "Deployment complete!"
# kubectl get deployments -n kube-system
# kubectl get services -n kube-system
# kubectl get ingress -n kube-system
