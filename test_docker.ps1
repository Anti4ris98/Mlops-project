# Test Docker container locally
# Run this script to build and test the Docker image

Write-Host "🐳 Testing Docker Container" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Step 1: Train model (if not exists)
Write-Host "`n1️⃣ Checking model files..." -ForegroundColor Cyan
if (-not (Test-Path "model/model.pkl") -or -not (Test-Path "model/reference_data.pkl")) {
    Write-Host "   Training model..." -ForegroundColor Yellow
    python model/train.py
}
else {
    Write-Host "   ✅ Model files found" -ForegroundColor Green
}

# Step 2: Build Docker image
Write-Host "`n2️⃣ Building Docker image..." -ForegroundColor Cyan
docker build -t aiops-inference:latest .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Docker image built successfully" -ForegroundColor Green

# Step 3: Check image size
$imageInfo = docker images aiops-inference:latest --format "{{.Size}}"
Write-Host "   Image size: $imageInfo" -ForegroundColor White

# Step 4: Stop old container if exists
Write-Host "`n3️⃣ Cleaning up old containers..." -ForegroundColor Cyan
docker stop aiops-test 2>$null | Out-Null
docker rm aiops-test 2>$null | Out-Null

# Step 5: Run container
Write-Host "`n4️⃣ Starting container..." -ForegroundColor Cyan
docker run -d --name aiops-test -p 8000:8000 aiops-inference:latest

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start container" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Container started" -ForegroundColor Green
Write-Host "   Waiting for startup..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Step 6: Check container status
Write-Host "`n5️⃣ Checking container status..." -ForegroundColor Cyan
$containerStatus = docker ps --filter "name=aiops-test" --format "{{.Status}}"
Write-Host "   Status: $containerStatus" -ForegroundColor White

# Step 7: Test endpoints
Write-Host "`n6️⃣ Testing API endpoints..." -ForegroundColor Cyan

# Test health endpoint
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8000/healthz" -ErrorAction Stop
    Write-Host "   ✅ Health check: $($health.status)" -ForegroundColor Green
}
catch {
    Write-Host "   ❌ Health check failed: $_" -ForegroundColor Red
    docker logs aiops-test --tail 20
    exit 1
}

# Test root endpoint
try {
    $root = Invoke-RestMethod -Uri "http://localhost:8000/" -ErrorAction Stop
    Write-Host "   ✅ Root endpoint: $($root.service) v$($root.version)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  Root endpoint warning: $_" -ForegroundColor Yellow
}

# Test prediction endpoint
Write-Host "`n7️⃣ Testing prediction..." -ForegroundColor Cyan
try {
    $body = @{
        features = @(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 
                     1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0)
    } | ConvertTo-Json
    
    $prediction = Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop
    
    Write-Host "   ✅ Prediction successful" -ForegroundColor Green
    Write-Host "      Prediction: $($prediction.prediction)" -ForegroundColor White
    Write-Host "      Probability: [$($prediction.probability -join ', ')]" -ForegroundColor White
    Write-Host "      Drift detected: $($prediction.drift_detected)" -ForegroundColor $(if ($prediction.drift_detected) { "Yellow" } else { "White" })
    Write-Host "      Drift score: $([math]::Round($prediction.drift_score, 4))" -ForegroundColor White
}
catch {
    Write-Host "   ❌ Prediction failed: $_" -ForegroundColor Red
    exit 1
}

# Step 8: View logs
Write-Host "`n8️⃣ Recent logs:" -ForegroundColor Cyan
docker logs aiops-test --tail 5 | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkGray }

# Step 9: Summary
Write-Host "`n============================" -ForegroundColor Green
Write-Host "🎉 All tests passed!" -ForegroundColor Green
Write-Host "`n📊 Container Info:" -ForegroundColor Cyan
Write-Host "   Name: aiops-test" -ForegroundColor White
Write-Host "   Image: aiops-inference:latest" -ForegroundColor White
Write-Host "   Port: 8000 -> 8000" -ForegroundColor White
Write-Host "   Status: Running" -ForegroundColor Green

Write-Host "`n🌐 Access URLs:" -ForegroundColor Cyan
Write-Host "   API: http://localhost:8000" -ForegroundColor Yellow
Write-Host "   Docs: http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host "   Health: http://localhost:8000/healthz" -ForegroundColor Yellow
Write-Host "   Metrics: http://localhost:8000/metrics" -ForegroundColor Yellow

Write-Host "`n💡 Useful commands:" -ForegroundColor Cyan
Write-Host "   docker logs aiops-test -f          # Follow logs" -ForegroundColor White
Write-Host "   docker exec -it aiops-test bash    # Enter container" -ForegroundColor White
Write-Host "   docker stop aiops-test             # Stop container" -ForegroundColor White
Write-Host "   docker rm aiops-test               # Remove container" -ForegroundColor White

Write-Host "`n🛑 To stop and remove the container:" -ForegroundColor Yellow
Write-Host "   docker stop aiops-test && docker rm aiops-test" -ForegroundColor White
Write-Host ""
