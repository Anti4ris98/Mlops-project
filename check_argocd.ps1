# Check ArgoCD Status Script
Write-Host "🔍 Checking ArgoCD Status..." -ForegroundColor Green

# Check if ArgoCD is installed
Write-Host "`n1️⃣ Checking ArgoCD installation..." -ForegroundColor Cyan
$argoCDInstalled = kubectl get namespace argocd 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ ArgoCD namespace exists" -ForegroundColor Green
    
    # Check pods
    Write-Host "`n2️⃣ Checking ArgoCD pods..." -ForegroundColor Cyan
    kubectl get pods -n argocd
    
    # Check applications
    Write-Host "`n3️⃣ Checking ArgoCD applications..." -ForegroundColor Cyan
    $apps = kubectl get applications -n argocd 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $apps
    } else {
        Write-Host "   ⚠️  No applications found or error occurred" -ForegroundColor Yellow
    }
    
    # Get ArgoCD password
    Write-Host "`n4️⃣ ArgoCD Admin Password:" -ForegroundColor Cyan
    try {
        $passwordBase64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
        $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($passwordBase64))
        Write-Host "   Password: " -NoNewline -ForegroundColor White
        Write-Host $password -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  Could not retrieve password" -ForegroundColor Yellow
    }
    
    # Check if application exists
    Write-Host "`n5️⃣ Checking aiops-inference application..." -ForegroundColor Cyan
    $appExists = kubectl get application aiops-inference -n argocd 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Application exists" -ForegroundColor Green
        kubectl get application aiops-inference -n argocd -o yaml | Select-String "health|sync"
    } else {
        Write-Host "   ❌ Application not found - deploying..." -ForegroundColor Yellow
        kubectl apply -f argocd/application.yaml
        Write-Host "   ✅ Application deployed!" -ForegroundColor Green
    }
    
    Write-Host "`n🌐 Access ArgoCD UI:" -ForegroundColor Cyan
    Write-Host "   URL: " -NoNewline -ForegroundColor White
    Write-Host "https://localhost:8080" -ForegroundColor Yellow
    Write-Host "   Username: " -NoNewline -ForegroundColor White
    Write-Host "admin" -ForegroundColor Green
    Write-Host "   Password: " -NoNewline -ForegroundColor White
    Write-Host $password -ForegroundColor Green
    
} else {
    Write-Host "   ❌ ArgoCD is not installed" -ForegroundColor Red
    Write-Host "   Run: .\run_local.ps1 to install" -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline
