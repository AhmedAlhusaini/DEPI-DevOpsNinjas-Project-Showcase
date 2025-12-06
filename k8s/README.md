# ShopiNow Kubernetes Deployment

This directory contains all Kubernetes manifests to deploy ShopiNow to a Kubernetes cluster.

## 📁 Directory Structure

```
k8s/
├── SETUP_GUIDE.md              # Complete step-by-step tutorial
├── deploy.ps1                  # One-click deployment script
├── base/
│   └── namespace.yaml          # Namespace definition
├── secrets/
│   └── shopinow-secrets.yaml   # Secrets (DB password, JWT)
├── configmaps/
│   ├── backend-config.yaml     # Backend configuration
│   └── postgres-config.yaml    # Database configuration
├── storage/
│   └── postgres-pvc.yaml       # Persistent volume claim for DB
├── deployments/
│   ├── postgres-statefulset.yaml   # Database StatefulSet
│   ├── backend-deployment.yaml     # Backend Deployment (3 replicas)
│   └── frontend-deployment.yaml    # Frontend Deployment (2 replicas)
├── services/
│   ├── postgres-service.yaml   # Database Service (headless)
│   ├── backend-service.yaml    # Backend Service (ClusterIP)
│   └── frontend-service.yaml   # Frontend Service (ClusterIP)
├── ingress/
│   └── shopinow-ingress.yaml   # Ingress for external access
└── autoscaling/
    ├── backend-hpa.yaml        # Backend autoscaling (2-10 pods)
    └── frontend-hpa.yaml       # Frontend autoscaling (2-5 pods)
```

## 🚀 Quick Start

### Prerequisites
1. Kubernetes cluster (Docker Desktop, Minikube, or cloud provider)
2. kubectl installed
3. Docker images built locally or pushed to registry

### One-Command Deployment

```powershell
# Deploy everything
.\k8s\deploy.ps1
```

### Manual Deployment

```powershell
# 1. Create namespace
kubectl apply -f k8s/base/

# 2. Create secrets and configs
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# 3. Create storage
kubectl apply -f k8s/storage/

# 4. Deploy database
kubectl apply -f k8s/deployments/postgres-statefulset.yaml
kubectl apply -f k8s/services/postgres-service.yaml

# Wait for DB to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n shopinow --timeout=120s

# 5. Deploy backend
kubectl apply -f k8s/deployments/backend-deployment.yaml
kubectl apply -f k8s/services/backend-service.yaml

# 6. Deploy frontend
kubectl apply -f k8s/deployments/frontend-deployment.yaml
kubectl apply -f k8s/services/frontend-service.yaml

# 7. Setup ingress
kubectl apply -f k8s/ingress/

# 8. Enable autoscaling (optional)
kubectl apply -f k8s/autoscaling/
```

## 🔧 Configuration

### Using Local Docker Images

Edit deployment files and change:
```yaml
image: ghcr.io/your-username/shopinow-backend:latest
```

To:
```yaml
image: shopinow-backend:local
imagePullPolicy: Never
```

### Updating Secrets

Edit `k8s/secrets/shopinow-secrets.yaml` and change:
- `db-password`: Your database password
- `jwt-secret`: Your JWT secret (256-bit minimum)

### Updating Configuration

Edit `k8s/configmaps/backend-config.yaml` to change:
- `CORS_ALLOWED_ORIGINS`: Your allowed domains
- `JAVA_OPTS`: JVM memory settings

## 🌐 Accessing the Application

1. Install nginx ingress controller:
```powershell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```

2. Add to hosts file (`C:\Windows\System32\drivers\etc\hosts`):
```
127.0.0.1 shopinow.local
```

3. Access application:
- **Frontend**: http://shopinow.local
- **API**: http://shopinow.local/api/products
- **Swagger**: http://shopinow.local/swagger-ui.html

## 📊 Monitoring

### View All Resources
```powershell
kubectl get all -n shopinow
```

### View Logs
```powershell
# Backend logs
kubectl logs -f deployment/backend -n shopinow

# Frontend logs
kubectl logs -f deployment/frontend -n shopinow

# Database logs
kubectl logs statefulset/postgres -n shopinow
```

### Check Autoscaling
```powershell
kubectl get hpa -n shopinow
```

### Resource Usage
```powershell
kubectl top pods -n shopinow
kubectl top nodes
```

## 🔍 Troubleshooting

### Pods Not Starting
```powershell
kubectl describe pod <pod-name> -n shopinow
kubectl logs <pod-name> -n shopinow
```

### Service Not Accessible
```powershell
kubectl get services -n shopinow
kubectl describe service <service-name> -n shopinow
```

### Database Connection Issues
```powershell
# Connect to database pod
kubectl exec -it postgres-0 -n shopinow -- psql -U postgres -d shopinow

# Check if backend can reach database
kubectl exec -it <backend-pod> -n shopinow -- nc -zv postgres-service 5432
```

### Ingress Not Working
```powershell
kubectl get ingress -n shopinow
kubectl describe ingress shopinow-ingress -n shopinow
kubectl get pods -n ingress-nginx
```

## 🧪 Testing Features

### Test Auto-Healing
```powershell
# Delete a pod
kubectl delete pod <pod-name> -n shopinow

# Watch it recreate automatically
kubectl get pods -n shopinow -w
```

### Test Scaling
```powershell
# Manual scale
kubectl scale deployment backend --replicas=5 -n shopinow

# Check status
kubectl get pods -n shopinow
```

### Test Rolling Updates
```powershell
# Update image
kubectl set image deployment/backend backend=shopinow-backend:v2 -n shopinow

# Watch rollout
kubectl rollout status deployment/backend -n shopinow

# Rollback if needed
kubectl rollout undo deployment/backend -n shopinow
```

## 📚 Learn More

See **SETUP_GUIDE.md** for:
- Detailed explanations of each component
- Why each step is needed
- Kubernetes concepts explained
- Best practices
- Advanced tutorials

## 🧹 Cleanup

### Delete Everything
```powershell
kubectl delete namespace shopinow
```

### Delete Ingress Controller
```powershell
kubectl delete namespace ingress-nginx
```

## 📋 Default Configuration

### Backend
- **Replicas**: 3
- **CPU**: 200m (request) - 1000m (limit)
- **Memory**: 512Mi (request) - 1Gi (limit)
- **Autoscaling**: 2-10 pods at 70% CPU

### Frontend
- **Replicas**: 2
- **CPU**: 100m (request) - 500m (limit)
- **Memory**: 128Mi (request) - 256Mi (limit)
- **Autoscaling**: 2-5 pods at 70% CPU

### Database
- **Replicas**: 1 (StatefulSet)
- **Storage**: 10Gi
- **CPU**: 250m (request) - 1000m (limit)
- **Memory**: 512Mi (request) - 1Gi (limit)

## 🔐 Security Notes

> ⚠️ **WARNING**: This configuration is for learning/development purposes.

For production:
1. Use external secret management (Vault, AWS Secrets Manager)
2. Enable SSL/TLS with cert-manager
3. Implement network policies
4. Use private container registries
5. Enable RBAC (Role-Based Access Control)
6. Regular security scanning
7. Database read replicas and backups

## 🎯 What This Gives You

✅ **High Availability**: Multiple replicas of each service
✅ **Auto-Scaling**: Automatically scale based on load
✅ **Self-Healing**: Pods restart if they crash
✅ **Load Balancing**: Traffic distributed across pods
✅ **Rolling Updates**: Zero-downtime deployments
✅ **Persistent Storage**: Database data survives restarts
✅ **Service Discovery**: Services find each other via DNS
✅ **Resource Management**: CPU/memory limits prevent resource exhaustion

---

**Ready to deploy?** Start with the [SETUP_GUIDE.md](./SETUP_GUIDE.md)!
