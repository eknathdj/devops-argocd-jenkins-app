#!/bin/bash

set -e

echo "Installing ArgoCD..."

# Create namespace
kubectl create namespace argocd || echo "Namespace already exists"

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial admin password
echo ""
echo "ArgoCD installed successfully!"
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "To access ArgoCD UI:"
echo "1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "2. Open browser: https://localhost:8081"
echo "3. Username: admin"
echo "4. Password: (shown above)"