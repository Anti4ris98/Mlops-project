# MLOps Quality Project - Local Deployment Script for Windows
# Requires: Minikube, kubectl, Helm, Docker Desktop, Python 3.10+

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting MLOps Quality Project on Minikube..." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# 1. Start Minikube
Write-Host "`n📦 Starting Minikube..." -ForegroundColor Cyan
minikube start --memory=8192 --cpus=4 --driver=docker

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Minikube failed to start. Trying to delete and recreate..." -ForegroundColor Red
    minikube delete
    minikube start --memory=8192 --cpus=4 --driver=docker
}

Write-Host "⏳ Waiting for Minikube to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s

# 2. Use Minikube Docker environment
Write-Host "`n🐳 Configuring Docker to use Minikube environment..." -ForegroundColor Cyan
$env:MINIKUBE_ACTIVE_DOCKERD = "minikube"
minikube docker-env --shell powershell | Out-String | Invoke-Expression

# 3. Train the model
Write-Host "`n🔬 Training ML model..." -ForegroundColor Cyan
python model/train.py

# 4. Build Docker image
Write-Host "`n🔨 Building Docker image..." -ForegroundColor Cyan
docker build -t aiops-inference:latest .

# 5. Add Helm repositories
Write-Host "`n📚 Adding Helm repositories..." -ForegroundColor Cyan
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 6. Deploy Prometheus + Grafana
Write-Host "`n📈 Deploying Prometheus + Grafana monitoring stack..." -ForegroundColor Cyan
$monitoringExists = helm list -n monitoring 2>&1 | Select-String "monitoring"
if (-not $monitoringExists) {
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
        -n monitoring `
        --create-namespace `
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false `
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false `
        --wait `
        --timeout=5m
}
else {
    Write-Host "✅ Monitoring stack already installed" -ForegroundColor Green
}

# 7. Deploy ArgoCD
Write-Host "`n🔄 Deploying ArgoCD..." -ForegroundColor Cyan
$argoCDExists = kubectl get namespace argocd 2>&1
if ($LASTEXITCODE -ne 0) {
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    Write-Host "⏳ Waiting for ArgoCD to be ready..."
    Start-Sleep -Seconds 10
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
}
else {
    Write-Host "✅ ArgoCD already installed" -ForegroundColor Green
}

# 8. Deploy application
Write-Host "`n🚀 Deploying application Helm chart..." -ForegroundColor Cyan
helm upgrade --install aiops-inference ./helm -n aiops --create-namespace --wait

# 9. Wait for app pods
Write-Host "⏳ Waiting for application pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=Ready pods -l app=aiops-inference -n aiops --timeout=180s

# 10. Get ArgoCD password
Write-Host "`n🔐 Retrieving ArgoCD admin password..." -ForegroundColor Cyan
try {
    $argoCDPasswordBase64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
    $argoCDPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($argoCDPasswordBase64))
}
catch {
    $argoCDPassword = "Not available yet"
}

# 11. Setup port-forwarding
Write-Host "`n🔗 Setting up port-forwarding..." -ForegroundColor Green

# Kill existing port-forwards
Get-Job | Where-Object { $_.Name -like "PortForward*" } | Stop-Job | Remove-Job

# Start port-forwards as background jobs
Start-Job -Name "PortForward1" -ScriptBlock { kubectl port-forward svc/aiops-inference 8000:8000 -n aiops } | Out-Null
Start-Job -Name "PortForward2" -ScriptBlock { kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring } | Out-Null
Start-Job -Name "PortForward3" -ScriptBlock { kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring } | Out-Null
Start-Job -Name "PortForward4" -ScriptBlock { kubectl port-forward svc/argocd-server 8080:443 -n argocd } | Out-Null

Start-Sleep -Seconds 5

# 12. Display service URLs
Write-Host "`n"
Write-Host "✅ All services are running!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "📊 Service URLs:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  🔮 FastAPI Inference:  " -NoNewline; Write-Host "http://localhost:8000" -ForegroundColor Yellow
Write-Host "     Swagger UI:         " -NoNewline; Write-Host "http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host "     Metrics:            " -NoNewline; Write-Host "http://localhost:8000/metrics" -ForegroundColor Yellow
Write-Host ""
Write-Host "  📈 Grafana:            " -NoNewline; Write-Host "http://localhost:3000" -ForegroundColor Yellow
Write-Host "     Username: " -NoNewline; Write-Host "admin" -ForegroundColor Green
Write-Host "     Password: " -NoNewline; Write-Host "prom-operator" -ForegroundColor Green
Write-Host ""
Write-Host "  📊 Prometheus:         " -NoNewline; Write-Host "http://localhost:9090" -ForegroundColor Yellow
Write-Host ""
Write-Host "  🔄 ArgoCD:             " -NoNewline; Write-Host "https://localhost:8080" -ForegroundColor Yellow
Write-Host "     Username: " -NoNewline; Write-Host "admin" -ForegroundColor Green
Write-Host "     Password: " -NoNewline; Write-Host $argoCDPassword -ForegroundColor Green
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Testing the API:" -ForegroundColor Yellow
Write-Host ""
Write-Host 'curl -X POST http://localhost:8000/predict `' -ForegroundColor White
Write-Host '  -H "Content-Type: application/json" `' -ForegroundColor White
Write-Host '  -d "{\"features\": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]}"' -ForegroundColor White
Write-Host ""
Write-Host "Or use PowerShell's Invoke-RestMethod:"
Write-Host '$body = @{ features = @(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0) } | ConvertTo-Json' -ForegroundColor White
Write-Host 'Invoke-RestMethod -Uri http://localhost:8000/predict -Method POST -Body $body -ContentType "application/json"' -ForegroundColor White
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Useful commands:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -n aiops              # Check application pods"
Write-Host "  kubectl logs -f <pod-name> -n aiops    # View logs"
Write-Host "  python model/train.py                  # Retrain model"
Write-Host ""
Write-Host "Press ENTER to stop all services and port-forwarding..." -ForegroundColor Green

Read-Host

# Cleanup
Write-Host "`n🧹 Cleaning up port-forwards..." -ForegroundColor Cyan
Get-Job | Where-Object { $_.Name -like "PortForward*" } | Stop-Job | Remove-Job

Write-Host "✅ Done!" -ForegroundColor Green
