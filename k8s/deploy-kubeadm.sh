#!/bin/bash
# Complete Kubernetes Deployment Script for WSL + kubeadm
# ShopiNow E-Commerce Platform

set -e  # Exit on error

echo "🚀 ShopiNow Kubernetes Deployment (WSL + kubeadm)"
echo "=================================================="

# Step 1: Prerequisites
echo ""
echo "📋 Step 1: Checking prerequisites..."
cd /mnt/c/Users/user/Desktop/Website

# Check if images exist
if ! docker images | grep -q "shopinow-backend.*local"; then
    echo "❌ Backend image not found. Building..."
    docker build -t shopinow-backend:local ./backend
else
    echo "✅ Backend image found"
fi

if ! docker images | grep -q "shopinow-frontend.*local"; then
    echo "❌ Frontend image not found. Building..."
    docker build -t shopinow-frontend:local ./ShopiNow
else
    echo "✅ Frontend image found"
fi

# Step 2: Fix CNI networking (remove Calico, ensure Flannel)
echo ""
echo "🔧 Step 2: Fixing CNI networking..."
sudo rm -f /etc/cni/net.d/10-calico.conflist 2>/dev/null || true
sudo rm -f /etc/cni/net.d/calico-kubeconfig 2>/dev/null || true
echo "✅ Removed Calico CNI configs (if any)"

# Restart kubelet
echo "Restarting kubelet..."
sudo systemctl restart kubelet
sleep 3

# Ensure Flannel is installed
if ! kubectl get pods -n kube-flannel &>/dev/null; then
    echo "Installing Flannel CNI..."
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    sleep 10
fi

# Restart Flannel pods
echo "Restarting Flannel..."
kubectl delete pod --all -n kube-flannel 2>/dev/null || true
sleep 20

# Step 3: Remove control plane taint
echo ""
echo "🔓 Step 3: Removing control plane taint..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true
echo "✅ Taint removed"

# Step 4: Wait for system pods
echo ""
echo "⏳ Step 4: Waiting for system pods to be ready..."
# Restart CoreDNS
kubectl delete pod --all -n kube-system -l k8s-app=kube-dns 2>/dev/null || true
sleep 15

# Wait for CoreDNS to be ready
echo "Waiting for CoreDNS..."
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s || true

# Step 5: Clean up previous deployment
echo ""  
echo "🧹 Step 5: Cleaning up previous deployment..."
kubectl delete namespace shopinow 2>/dev/null || true
kubectl delete pv postgres-pv 2>/dev/null || true
sleep 5

# Step 6: Create storage directory
echo ""
echo "💾 Step 6: Creating storage directory..."
sudo mkdir -p /var/lib/k8s-data/postgres
sudo chmod 777 /var/lib/k8s-data/postgres
echo "✅ Storage directory created"

# Step 7: Deploy application
echo ""
echo "📦 Step 7: Deploying application..."

# Namespace
echo "Creating namespace..."
kubectl apply -f k8s/base/namespace.yaml

# Storage
echo "Creating persistent storage..."
kubectl apply -f k8s/storage/postgres-pv-manual.yaml
kubectl apply -f k8s/storage/postgres-pvc.yaml
sleep 2

# Verify storage binding
echo "Verifying storage binding..."
kubectl get pv
kubectl get pvc -n shopinow

# Secrets and ConfigMaps
echo "Creating secrets and configmaps..."
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# PostgreSQL
echo "Deploying PostgreSQL..."
kubectl apply -f k8s/deployments/postgres-statefulset.yaml
kubectl apply -f k8s/services/postgres-service.yaml

# Wait for PostgreSQL
echo "Waiting for PostgreSQL to be ready (this may take 1-2 minutes)..."
kubectl wait --for=condition=ready pod -l app=postgres -n shopinow --timeout=180s

# Backend
echo "Deploying backend (3 replicas)..."
kubectl apply -f k8s/deployments/backend-deployment.yaml
kubectl apply -f k8s/services/backend-service.yaml
sleep 10

# Frontend
echo "Deploying frontend (2 replicas)..."
kubectl apply -f k8s/deployments/frontend-deployment.yaml
kubectl apply -f k8s/services/frontend-service.yaml
sleep 10

# Ingress Controller
echo "Installing nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml
sleep 15

# Wait for ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s || echo "⚠️  Ingress controller may still be starting"

# Deploy ingress
echo "Deploying ingress..."
kubectl apply -f k8s/ingress/

# Autoscaling (optional)
echo "Deploying autoscaling..."
kubectl apply -f k8s/autoscaling/ 2>/dev/null || echo "⚠️  Autoscaling may require metrics-server"

# Step 8: Show status
echo ""
echo "✅ Deployment complete!"
echo "======================="
echo ""
echo "📋 Pod Status:"
kubectl get pods -n shopinow
echo ""
echo "📋 Services:"
kubectl get services -n shopinow
echo ""
echo "📋 Ingress:"
kubectl get ingress -n shopinow
echo ""
echo "📋 PersistentVolumes:"
kubectl get pv
kubectl get pvc -n shopinow
echo ""
echo "🎉 ShopiNow is deployed!"
echo ""
echo "📝 Next Steps:"
echo "1. Wait for all pods to show 1/1 Running (check with: kubectl get pods -n shopinow -w)"
echo "2. Add '127.0.0.1 shopinow.local' to /etc/hosts (or Windows hosts file)"
echo "3. Get ingress port: kubectl get svc -n ingress-nginx"
echo "4. Access app at: http://shopinow.local:<NodePort>"
echo ""
echo "🔍 Troubleshooting commands:"
echo "  kubectl logs -f deployment/backend -n shopinow"
echo "  kubectl logs -f deployment/frontend -n shopinow"
echo "  kubectl describe pod <pod-name> -n shopinow"
echo ""
