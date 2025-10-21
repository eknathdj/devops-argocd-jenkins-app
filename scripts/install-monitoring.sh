#!/bin/bash

echo "Installing Prometheus & Grafana..."

# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring || true

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123

echo "Monitoring stack installed!"
echo ""
echo "Access Grafana:"
echo "kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "Username: admin"
echo "Password: admin123"