# ShopiNow Kubernetes Setup - Complete Step-by-Step Guide

## 🎯 What You're Going to Build

A production-grade Kubernetes deployment of ShopiNow with:
- **3 Backend Pods** (auto-scaling 2-10 based on load)
- **2 Frontend Pods** (auto-scaling 2-5 based on load)
- **1 PostgreSQL Pod** with persistent storage
- **Ingress** for external access
- **Auto-healing** and **self-recovery**
- **Load balancing** across all pods

---

## 📋 Prerequisites

### 1. Install Required Tools

#### A. kubectl (Kubernetes CLI)
```powershell
# Download kubectl for Windows
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

# Move to a directory in PATH
# Or add current directory to PATH

# Verify installation
kubectl version --client
```

#### B. Docker Desktop with Kubernetes

**Option 1: Docker Desktop (Easiest for Learning)**
1. Download Docker Desktop: https://www.docker.com/products/docker-desktop/
2. Install and start Docker Desktop
3. Go to Settings → Kubernetes → Enable Kubernetes
4. Click "Apply & Restart"
5. Wait 5-10 minutes for Kubernetes to start

**Verify:**
```powershell
kubectl get nodes
# Should show: docker-desktop   Ready    control-plane   ...
```

#### C. Build Your Docker Images Locally

Before deploying to Kubernetes, build your images:

```powershell
# Navigate to project root
cd C:\Users\user\Desktop\Website

# Build backend image
docker build -t shopinow-backend:local ./backend

# Build frontend image
docker build -t shopinow-frontend:local ./ShopiNow

# Verify images
docker images | findstr shopinow
```

---

## 🔧 Step-by-Step Deployment

### STEP 1: Understanding the Kubernetes Architecture

**WHY**: Before deploying, understand what each component does.

```
┌─────────────────────────────────────────────────────────┐
│                    INGRESS (nginx)                      │
│              Routes traffic to services                 │
└─────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────┴─────────────────┐
        ↓                                   ↓
┌───────────────────┐            ┌──────────────────────┐
│ FRONTEND SERVICE  │            │  BACKEND SERVICE     │
│  (Load Balancer)  │            │   (Load Balancer)    │
└───────────────────┘            └──────────────────────┘
        ↓                                   ↓
┌───────────────────┐            ┌──────────────────────┐
│ Frontend Pod 1    │            │  Backend Pod 1       │
│ Frontend Pod 2    │            │  Backend Pod 2       │
│                   │            │  Backend Pod 3       │
└───────────────────┘            └──────────────────────┘
                                            ↓
                                 ┌──────────────────────┐
                                 │  POSTGRES SERVICE    │
                                 │   (Headless)         │
                                 └──────────────────────┘
                                            ↓
                                 ┌──────────────────────┐
                                 │  PostgreSQL Pod      │
                                 │  + Persistent Volume │
                                 └──────────────────────┘
```

---

### STEP 2: Update Image References

**WHY**: Your manifests reference GitHub Container Registry images, but we'll use local images for learning.

**Edit these files:**

**File: `k8s/deployments/backend-deployment.yaml`**
```yaml
# Find line ~23, change from:
image: ghcr.io/your-username/shopinow-backend:latest

# To:
image: shopinow-backend:local
imagePullPolicy: Never  # Add this line below image
```

**File: `k8s/deployments/frontend-deployment.yaml`**
```yaml
# Find line ~19, change from:
image: ghcr.io/your-username/shopinow-frontend:latest

# To:
image: shopinow-frontend:local
imagePullPolicy: Never  # Add this line below image
```

**WHY imagePullPolicy: Never?**
- Tells Kubernetes to use local Docker images
- Don't try to pull from a registry
- Perfect for development/learning

---

### STEP 3: Create Namespace

**WHY**: Namespaces isolate your resources from other apps in the cluster.

```powershell
kubectl apply -f k8s/base/namespace.yaml
```

**What this does:**
- Creates a namespace called `shopinow`
- All your resources will live in this namespace
-Prevents naming conflicts with other apps

**Verify:**
```powershell
kubectl get namespace shopinow
```

---

### STEP 4: Create Secrets

**WHY**: Secrets store sensitive data (passwords, JWT keys) securely.

```powershell
kubectl apply -f k8s/secrets/shopinow-secrets.yaml
```

**What this does:**
- Stores database password encrypted
- Stores JWT secret encrypted
- Makes them available to pods as environment variables

**Verify:**
```powershell
kubectl get secrets -n shopinow
```

**Security note:**
- Secrets are base64 encoded (not encrypted by default)
- In production, use external secret managers (Vault, AWS Secrets Manager)
- Never commit secrets to Git!

---

### STEP 5: Create ConfigMaps

**WHY**: ConfigMaps store non-sensitive configuration separately from code.

```powershell
kubectl apply -f k8s/configmaps/
```

**What this does:**
- Stores Spring Boot profile (prod)
- Stores CORS settings
- Stores JVM options
- Allows changing config without rebuilding images

**Verify:**
```powershell
kubectl get configmap -n shopinow
kubectl describe configmap backend-config -n shopinow
```

**Benefits:**
- Change config without redeploying
- Same image works in dev/staging/prod with different configs
- Easier to manage environment-specific settings

---

### STEP 6: Create Persistent Storage

**WHY**: Database data must survive pod restarts and failures.

```powershell
kubectl apply -f k8s/storage/postgres-pvc.yaml
```

**What this does:**
- Requests 10GB of persistent storage
- Kubernetes provisions a volume
- Volume survives pod deletion/recreation

**Verify:**
```powershell
kubectl get pvc -n shopinow
# STATUS should be "Bound"
```

**How it works:**
```
Pod Deleted → New Pod Created → Attaches Same Volume → Data Persists!
```

---

### STEP 7: Deploy PostgreSQL Database

**WHY**: Use StatefulSet (not Deployment) for databases to ensure stable storage and network identity.

```powershell
# Deploy the StatefulSet
kubectl apply -f k8s/deployments/postgres-statefulset.yaml

# Create the Service
kubectl apply -f k8s/services/postgres-service.yaml
```

**What this does:**
- Creates 1 PostgreSQL pod
- Attaches persistent volume
- Creates headless service for stable DNS (postgres-service)

**Wait for it to be ready:**
```powershell
kubectl wait --for=condition=ready pod -l app=postgres -n shopinow --timeout=120s
```

**Verify:**
```powershell
kubectl get pods -n shopinow
kubectl get statefulset -n shopinow
kubectl logs statefulset/postgres -n shopinow
```

**Why StatefulSet vs Deployment?**
- **StatefulSet**: Stable pod names (postgres-0), ordered startup/shutdown, persistent storage
- **Deployment**: Random pod names, no storage guarantees, good for stateless apps

---

### STEP 8: Deploy Backend Application

**WHY**: Deploy multiple backend replicas for load balancing and high availability.

```powershell
# Deploy backend
kubectl apply -f k8s/deployments/backend-deployment.yaml

# Create backend service
kubectl apply -f k8s/services/backend-service.yaml
```

**What this does:**
- Creates 3 backend pods (replicas: 3)
- Init container waits for database to be ready
- Health checks ensure pods are healthy
- Service load balances traffic across all 3 pods

**Watch deployment:**
```powershell
kubectl get pods -n shopinow -w
# Press Ctrl+C to stop watching
```

**Check logs:**
```powershell
kubectl logs -f deployment/backend -n shopinow
```

**Why init container?**
- Ensures database is ready before backend starts
- Prevents "connection refused" errors
- Clean startup sequence

---

### STEP 9: Deploy Frontend Application

**WHY**: Frontend serves the user interface with high availability.

```powershell
# Deploy frontend
kubectl apply -f k8s/deployments/frontend-deployment.yaml

# Create frontend service
kubectl apply -f k8s/services/frontend-service.yaml
```

**What this does:**
- Creates 2 frontend pods
- Nginx serves Angular SPA
- Service load balances traffic

**Verify:**
```powershell
kubectl get pods -n shopinow
kubectl get services -n shopinow
```

---

### STEP 10: Install Nginx Ingress Controller

**WHY**: Ingress routes external traffic to your services based on URL paths.

**For Docker Desktop Kubernetes:**
```powershell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```

**Wait for ingress controller:**
```powershell
kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=120s
```

**What this does:**
- Installs nginx ingress controller
- Acts as a reverse proxy/load balancer
- Routes traffic based on hostname and path

**Verify:**
```powershell
kubectl get pods -n ingress-nginx
```

---

### STEP 11: Create Ingress Resource

**WHY**: Define routing rules for your application.

```powershell
kubectl apply -f k8s/ingress/shopinow-ingress.yaml
```

**What this does:**
- Routes `/api/*` to backend service
- Routes `/*` to frontend service
- Makes app accessible at `http://shopinow.local`

**Verify:**
```powershell
kubectl get ingress -n shopinow
kubectl describe ingress shopinow-ingress -n shopinow
```

---

### STEP 12: Configure Local DNS

**WHY**: Map `shopinow.local` to localhost so ingress works.

**Edit hosts file:**
```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```

**Add this line:**
```
127.0.0.1 shopinow.local
```

**Save and close.**

---

### STEP 13: Deploy Autoscaling (Optional)

**WHY**: Automatically scale pods based on CPU/memory usage.

```powershell
kubectl apply -f k8s/autoscaling/backend-hpa.yaml
kubectl apply -f k8s/autoscaling/frontend-hpa.yaml
```

**What this does:**
- Backend: Scale 2-10 pods based on 70% CPU usage
- Frontend: Scale 2-5 pods based on 70% CPU usage

**Note:** Requires Metrics Server:
```powershell
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

For Docker Desktop, you may need to edit metrics-server deployment:
```powershell
kubectl edit deployment metrics-server -n kube-system
# Add: - --kubelet-insecure-tls under args:
```

**Verify:**
```powershell
kubectl get hpa -n shopinow
```

---

### STEP 14: Access Your Application!

**WHY**: Time to see your Kubernetes deployment in action!

**Open browser and navigate to:**
```
http://shopinow.local
```

**API endpoint:**
```
http://shopinow.local/api/products
```

**Swagger UI:**
```
http://shopinow.local/swagger-ui.html
```

---

## 🔍 Monitoring & Troubleshooting

### Check All Resources
```powershell
kubectl get all -n shopinow
```

### Check Pod Logs
```powershell
# Backend logs
kubectl logs -f deployment/backend -n shopinow

# Frontend logs
kubectl logs -f deployment/frontend -n shopinow

# Database logs
kubectl logs statefulset/postgres -n shopinow
```

### Check Pod Details
```powershell
kubectl describe pod <pod-name> -n shopinow
```

### Execute Commands in Pod
```powershell
# Connect to database
kubectl exec -it postgres-0 -n shopinow -- psql -U postgres -d shopinow

# List tables
\dt

# Check data
SELECT * FROM products;

# Exit
\q
```

### Port Forward for Direct Access
```powershell
# Access backend directly
kubectl port-forward service/backend-service 8080:8080 -n shopinow
# Visit: http://localhost:8080/api/products

# Access frontend directly
kubectl port-forward service/frontend-service 8081:80 -n shopinow
# Visit: http://localhost:8081
```

### Check Autoscaling Status
```powershell
kubectl get hpa -n shopinow -w
```

### Check Resource Usage
```powershell
kubectl top pods -n shopinow
kubectl top nodes
```

---

## 🧪 Testing Kubernetes Features

### Test High Availability
```powershell
# Delete a backend pod
kubectl delete pod <backend-pod-name> -n shopinow

# Watch it get recreated automatically
kubectl get pods -n shopinow -w
```

**WHY**: Kubernetes auto-recreates deleted pods to maintain desired state.

### Test Load Balancing
```powershell
# Make multiple requests
for ($i=1; $i -le 10; $i++) {
    Invoke-WebRequest -Uri http://shopinow.local/api/products
}

# Check logs of different pods
kubectl logs deployment/backend -n shopinow --tail=20
```

**WHY**: Service distributes traffic across all backend pods.

### Test Scaling
```powershell
# Manual scale
kubectl scale deployment backend --replicas=5 -n shopinow

# Watch pods
kubectl get pods -n shopinow -w

# Scale back
kubectl scale deployment backend --replicas=3 -n shopinow
```

---

## 🎓 Understanding Each Component

### 1. **Namespace** (`namespace.yaml`)
**What**: Logical cluster partition
**Why**: Isolates resources, prevents naming conflicts
**When deleted**: All resources in it are deleted

### 2. **Secret** (`shopinow-secrets.yaml`)
**What**: Encrypted key-value store
**Why**: Secure storage for passwords, tokens
**Access**: Pods read via environment variables or volume mounts

### 3. **ConfigMap** (`backend-config.yaml`, `postgres-config.yaml`)
**What**: Non-sensitive configuration
**Why**: Decouple config from image
**Benefit**: Change config without rebuilding

### 4. **PersistentVolumeClaim** (`postgres-pvc.yaml`)
**What**: Request for storage
**Why**: Database data survives pod restarts
**How**: Kubernetes provisions volume from available storage

### 5. **StatefulSet** (`postgres-statefulset.yaml`)
**What**: Manages stateful applications
**Why**: Stable pod names, ordered deployment, persistent storage
**Use for**: Databases, message queues, any stateful app

### 6. **Deployment** (`backend-deployment.yaml`, `frontend-deployment.yaml`)
**What**: Manages stateless applications
**Why**: Rolling updates, scaling, self-healing
**Use for**: Web apps, APIs, microservices

### 7. **Service** (`*service.yaml`)
**What**: Stable network endpoint for pods
**Why**: Pods have dynamic IPs, services provide stable DNS
**Types**:
- **ClusterIP**: Internal only (backend, frontend)
- **NodePort**: Exposes on node IP:Port
- **LoadBalancer**: Cloud load balancer
- **Headless** (ClusterIP: None): Direct pod access (database)

### 8. **Ingress** (`shopinow-ingress.yaml`)
**What**: HTTP(S) router
**Why**: Single entry point, path-based routing, SSL termination
**Requires**: Ingress controller (nginx)

### 9. **HorizontalPodAutoscaler** (`*-hpa.yaml`)
**What**: Automatic pod scaling
**Why**: Handle traffic spikes, save resources during low traffic
**Based on**: CPU, memory, or custom metrics

---

## 📊 Resource Requests & Limits Explained

In `backend-deployment.yaml`:
```yaml
resources:
  requests:
    cpu: "200m"      # Minimum CPU (0.2 cores)
    memory: "512Mi"  # Minimum RAM
  limits:
    cpu: "1000m"     # Maximum CPU (1 core)
    memory: "1Gi"    # Maximum RAM
```

**WHY?**
- **Requests**: Kubernetes ensures node has these resources before scheduling
- **Limits**: Prevents pod from consuming too much, getting OOMKilled

**Units:**
- CPU: `1000m` = 1 core, `500m` = 0.5 cores
- Memory: `Mi` = Mebibytes, `Gi` = Gibibytes

---

## 🚀 Advanced: Rolling Updates

**Update backend image:**
```powershell
# Build new image
docker build -t shopinow-backend:v2 ./backend

# Update deployment
kubectl set image deployment/backend backend=shopinow-backend:v2 -n shopinow

# Watch rollout
kubectl rollout status deployment/backend -n shopinow
```

**WHY zero downtime?**
- Kubernetes updates pods one at a time
- Old pods stay running until new ones are ready
- Traffic always routed to healthy pods

**Rollback if needed:**
```powershell
kubectl rollout undo deployment/backend -n shopinow
```

---

## 🧹 Cleanup

### Delete Everything
```powershell
# Delete namespace (deletes all resources)
kubectl delete namespace shopinow

# Delete ingress controller
kubectl delete namespace ingress-nginx

# Delete persistent volumes (if needed)
kubectl delete pv --all
```

### Selective Deletion
```powershell
# Delete specific resource
kubectl delete deployment backend -n shopinow
kubectl delete service backend-service -n shopinow
```

---

## 🎯 Summary: What You Learned

### ✅ Kubernetes Concepts
- [x] Namespaces for resource isolation
- [x] Secrets for sensitive data
- [x] ConfigMaps for configuration
- [x] Persistent storage for databases
- [x] StatefulSets vs Deployments
- [x] Services for networking
- [x] Ingress for external access
- [x] Auto-scaling with HPA
- [x] Resource limits and requests
- [x] Health checks (liveness/readiness)

### ✅ Kubernetes Features You Used
- [x] **Self-healing**: Deleted pods auto-recreate
- [x] **Load balancing**: Traffic distributed across pods
- [x] **Scaling**: Manual and automatic
- [x] **Rolling updates**: Zero-downtime deployments
- [x] **Persistent storage**: Data survives pod restarts
- [x] **Service discovery**: Pods find each other via DNS

### ✅ Operational Skills
- [x] Deploy multi-tier application
- [x] Monitor with kubectl
- [x] Troubleshoot pods and services
- [x] Scale applications
- [x] Perform rolling updates

---

## 🚀 Next Steps

1. **Add Monitoring**: Deploy Prometheus + Grafana
2. **Add Logging**: Deploy ELK stack
3. **Add CI/CD**: Automate deployments with GitHub Actions
4. **Try Helm**: Package manager for Kubernetes
5. **Explore**: Service Mesh (Istio), GitOps (ArgoCD)

Congratulations! You've successfully deployed ShopiNow to Kubernetes! 🎉
