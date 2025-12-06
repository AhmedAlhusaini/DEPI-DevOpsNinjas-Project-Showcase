# ShopiNow Kubernetes Deployment

Quick guide to deploy ShopiNow to Kubernetes from scratch.

---

## Installation (First Time Setup)

### 1. Install WSL2 (Windows)

On Windows PowerShell (as Administrator):

```powershell
wsl --install
# Restart computer
wsl --set-default-version 2
```

### 2. Install Docker

In WSL terminal:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

**Verify Docker:**

```bash
docker ps    # Should not error
```

### 3. Install Kubernetes (kubeadm)

```bash
# Update system
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Add Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, kubectl
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### 4. Initialize Kubernetes Cluster

```bash
# Initialize cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl (run commands shown in kubeadm output)
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Remove control-plane taint (for single-node cluster)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**Verify Kubernetes:**

```bash
kubectl get nodes    # Should show Ready
```

---

## Prerequisites Check

Before deploying, verify everything is installed:

```bash
kubectl get nodes    # Should show Ready
docker ps            # Should not error
docker --version     # Should show version
kubectl version      # Should show version
```

---

## First-Time Deployment

### 1. Build Images

```bash
# Navigate to your project directory
cd /path/to/your/project    # Example: cd /mnt/c/Users/user/Desktop/Website

docker build -t shopinow-backend:local ./backend
docker build -t shopinow-frontend:local ./ShopiNow
```

**Why:** Creates Docker images from your code. Kubernetes needs these images to run your app.

---

### 2. Import to Kubernetes

```bash
docker save shopinow-backend:local -o /tmp/backend.tar
docker save shopinow-frontend:local -o /tmp/frontend.tar
sudo ctr -n k8s.io images import /tmp/backend.tar
sudo ctr -n k8s.io images import /tmp/frontend.tar
```

**Why:** Kubernetes (kubeadm) uses containerd, not Docker. This transfers images from Docker to containerd so Kubernetes can use them.

---

### 3. Create Storage

```bash
sudo mkdir -p /var/lib/k8s-data/postgres
sudo chmod 777 /var/lib/k8s-data/postgres
```

**Why:** PostgreSQL needs a directory to store database files. Without this, your data would be lost when pods restart.

---

### 4. Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/base/
```

**Why:** Creates isolated "shopinow" namespace to organize all your app resources.

```bash
# Create storage
kubectl apply -f k8s/storage/
```

**Why:** Creates PersistentVolume (10GB disk space) and PersistentVolumeClaim (request for that space) so database data persists.

```bash
# Create secrets and config
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/
```

**Why:** Secrets store passwords/keys securely. ConfigMaps store app settings. Pods read these as environment variables.

```bash
# Deploy database
kubectl apply -f k8s/deployments/postgres-statefulset.yaml
kubectl apply -f k8s/services/postgres-service.yaml
```

**Why:** Creates PostgreSQL database pod and service. StatefulSet ensures data persists. Service creates network address "postgres-service".

```bash
# Wait for database
kubectl wait --for=condition=ready pod -l app=postgres -n shopinow --timeout=180s
```

**Why:** Backend needs database ready before starting. This waits up to 3 minutes for PostgreSQL to be ready.

```bash
# Deploy backend
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/
```

**Why:** Creates 3 backend pods (Spring Boot API) and 2 frontend pods (Angular). Services load-balance traffic across pods.

```bash
# Deploy autoscaling
kubectl apply -f k8s/autoscaling/
```

**Why:** Automatically adds/removes pods based on CPU/memory usage. Backend: 2-10 pods. Frontend: 2-5 pods.

---

### 5. Start Port-Forwards

```bash
kubectl port-forward -n shopinow service/backend-service 8080:8080 > /dev/null 2>&1 &
kubectl port-forward -n shopinow service/frontend-service 4200:80 > /dev/null 2>&1 &
```

**Why:** Kubernetes services have internal IPs you can't access from browser. Port-forward creates tunnels: localhost:8080 → backend, localhost:4200 → frontend.

---

### 6. Access Application

- Frontend: http://localhost:4200
- Backend: http://localhost:8080/api/products
- Swagger: http://localhost:8080/swagger-ui/index.html

---

## Daily Usage

**Start app** (if already deployed):

```bash
kubectl port-forward -n shopinow service/backend-service 8080:8080 > /dev/null 2>&1 &
kubectl port-forward -n shopinow service/frontend-service 4200:80 > /dev/null 2>&1 &
```

**Check status:**

```bash
kubectl get pods -n shopinow
```

**Stop port-forwards:**

```bash
pkill -f "kubectl port-forward"
```

---

## Troubleshooting

**Pods not running:**

```bash
kubectl describe pod <pod-name> -n shopinow
kubectl logs <pod-name> -n shopinow
```

**Can't access localhost:3000:**

```bash
jobs  # Check port-forwards running
```

**Restart everything:**

```bash
kubectl rollout restart deployment/backend -n shopinow
kubectl rollout restart deployment/frontend -n shopinow
```

**Certificate Error / Unable to Connect:**

If you see `x509: certificate signed by unknown authority` or connection refused:

```bash
# 1. Update WSL config
wsl -d Ubuntu-20.04 -- bash -c "mkdir -p \$HOME/.kube && sudo cp -f /etc/kubernetes/admin.conf \$HOME/.kube/config && sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"

# 2. Update Windows config (Run in PowerShell)
wsl -d Ubuntu-20.04 -- cat /home/$USER/.kube/config > $env:USERPROFILE\.kube\config
```

---

## Cleanup

### Complete Cleanup (Delete Everything)

**Delete Kubernetes Resources:**

```bash
# Delete namespace (removes all pods, services, deployments, etc.)
kubectl delete namespace shopinow

# Delete PersistentVolume
kubectl delete pv postgres-pv

# Stop all port-forwards
pkill -f "kubectl port-forward"

# Remove storage directory
sudo rm -rf /var/lib/k8s-data/postgres
```

**Verify Cleanup:**

```bash
# Check namespace deleted
kubectl get namespace shopinow
# Should show: Error from server (NotFound)

# Check no pods remain
kubectl get pods -n shopinow
# Should show: No resources found

# Check PV deleted
kubectl get pv
# Should show no postgres-pv

# Check port-forwards stopped
jobs
# Should show empty
```

---

### Clean Up Docker Images (Optional)

**Only needed if you want to rebuild from scratch:**

```bash
# Remove local Docker images
docker rmi shopinow-backend:local
docker rmi shopinow-frontend:local

# Remove from containerd (Kubernetes image store)
sudo ctr -n k8s.io images rm shopinow-backend:local
sudo ctr -n k8s.io images rm shopinow-frontend:local

# Clean up temporary files
rm -f /tmp/backend.tar /tmp/frontend.tar
```

**Why:** Removes images to save disk space. You'll need to rebuild if deploying again.

---

### Quick One-Command Cleanup

```bash
kubectl delete namespace shopinow && kubectl delete pv postgres-pv && pkill -f "kubectl port-forward" && sudo rm -rf /var/lib/k8s-data/postgres && echo "✅ Cleanup complete!"
```

**Use this to quickly remove everything and start fresh.**

---

### Partial Cleanup (Keep Images)

**If you just want to restart without rebuilding images:**

```bash
# Delete and recreate namespace
kubectl delete namespace shopinow
kubectl apply -f k8s/base/namespace.yaml

# Recreate storage directory
sudo rm -rf /var/lib/k8s-data/postgres
sudo mkdir -p /var/lib/k8s-data/postgres
sudo chmod 777 /var/lib/k8s-data/postgres

# Redeploy from Step 4 in First-Time Deployment
```

This keeps your Docker images but cleans up Kubernetes resources.

---

## One-Command Deploy

After building images:

```bash
cd /mnt/c/Users/user/Desktop/Website && kubectl apply -f k8s/base/ && kubectl apply -f k8s/storage/ && kubectl apply -f k8s/secrets/ && kubectl apply -f k8s/configmaps/ && kubectl apply -f k8s/deployments/postgres-statefulset.yaml && kubectl apply -f k8s/services/postgres-service.yaml && kubectl wait --for=condition=ready pod -l app=postgres -n shopinow --timeout=180s && kubectl apply -f k8s/deployments/ && kubectl apply -f k8s/services/ && kubectl apply -f k8s/autoscaling/ && kubectl port-forward -n shopinow service/backend-service 8080:8080 > /dev/null 2>&1 & kubectl port-forward -n shopinow service/frontend-service 3000:80 > /dev/null 2>&1 &
```

## Kills all processes bound to port 8080 in WSL/Linux.

netstat -ano | findstr :8080

taskkill /PID 41640 /F
taskkill /PID 18024 /F
