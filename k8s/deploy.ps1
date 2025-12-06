# Apply all manifests in order
Write-Host "🚀 Deploying ShopiNow to Kubernetes..." -ForegroundColor Green

# 1. Create namespace
Write-Host "`n📦 Creating namespace..." -ForegroundColor Yellow
kubectl apply -f k8s/base/namespace.yaml

# 2. Create secrets and configmaps
Write-Host "`n🔐 Creating secrets and configmaps..." -ForegroundColor Yellow
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# 3. Create storage
Write-Host "`n💾 Creating persistent storage..." -ForegroundColor Yellow
kubectl apply -f k8s/storage/

# 4. Deploy database
Write-Host "`n🗄️  Deploying PostgreSQL..." -ForegroundColor Yellow
kubectl apply -f k8s/deployments/postgres-statefulset.yaml
kubectl apply -f k8s/services/postgres-service.yaml

# Wait for database to be ready
Write-Host "`n⏳ Waiting for PostgreSQL to be ready..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod -l app=postgres -n shopinow --timeout=120s

# 5. Deploy backend
Write-Host "`n⚙️  Deploying backend..." -ForegroundColor Yellow
kubectl apply -f k8s/deployments/backend-deployment.yaml
kubectl apply -f k8s/services/backend-service.yaml

# 6. Deploy frontend
Write-Host "`n🎨 Deploying frontend..." -ForegroundColor Yellow
kubectl apply -f k8s/deployments/frontend-deployment.yaml
kubectl apply -f k8s/services/frontend-service.yaml

# 7. Deploy ingress
Write-Host "`n🌐 Creating ingress..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/

# 8. Deploy autoscaling (optional)
Write-Host "`n📊 Setting up autoscaling..." -ForegroundColor Yellow
kubectl apply -f k8s/autoscaling/

# 9. Show status
Write-Host "`n✅ Deployment complete! Checking status..." -ForegroundColor Green
Write-Host "`n📋 Pods:" -ForegroundColor Cyan
kubectl get pods -n shopinow

Write-Host "`n📋 Services:" -ForegroundColor Cyan
kubectl get services -n shopinow

Write-Host "`n📋 Ingress:" -ForegroundColor Cyan
kubectl get ingress -n shopinow

Write-Host "`n🎉 ShopiNow is deployed!" -ForegroundColor Green
Write-Host "To access the application:" -ForegroundColor Yellow
Write-Host "  - Add '127.0.0.1 shopinow.local' to your hosts file" -ForegroundColor White
Write-Host "  - Visit: http://shopinow.local" -ForegroundColor White
Write-Host "`nTo check logs:" -ForegroundColor Yellow
Write-Host "  kubectl logs -f deployment/backend -n shopinow" -ForegroundColor White
Write-Host "  kubectl logs -f deployment/frontend -n shopinow" -ForegroundColor White
