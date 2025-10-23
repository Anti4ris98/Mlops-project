# Test script for MLOps Inference API
# Run this after deploying the application

Write-Host "🧪 Testing MLOps Inference API..." -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Test 1: Health check
Write-Host "`n1️⃣ Testing health endpoint..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8000/healthz" -Method Get
    Write-Host "✅ Health check passed: $($health | ConvertTo-Json)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Health check failed: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Root endpoint
Write-Host "`n2️⃣ Testing root endpoint..." -ForegroundColor Cyan
try {
    $root = Invoke-RestMethod -Uri "http://localhost:8000/" -Method Get
    Write-Host "✅ Root endpoint passed" -ForegroundColor Green
    Write-Host "   Service: $($root.service)" -ForegroundColor White
    Write-Host "   Version: $($root.version)" -ForegroundColor White
}
catch {
    Write-Host "❌ Root endpoint failed: $_" -ForegroundColor Red
}

# Test 3: Prediction with normal data
Write-Host "`n3️⃣ Testing prediction with normal data..." -ForegroundColor Cyan
try {
    $body = @{
        features = @(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 
                     1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0)
    } | ConvertTo-Json
    
    $prediction = Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method Post -Body $body -ContentType "application/json"
    
    Write-Host "✅ Prediction passed" -ForegroundColor Green
    Write-Host "   Prediction: $($prediction.prediction)" -ForegroundColor White
    Write-Host "   Probability: [$($prediction.probability -join ', ')]" -ForegroundColor White
    Write-Host "   Drift detected: $($prediction.drift_detected)" -ForegroundColor White
    Write-Host "   Drift score: $($prediction.drift_score)" -ForegroundColor White
}
catch {
    Write-Host "❌ Prediction failed: $_" -ForegroundColor Red
    exit 1
}

# Test 4: Prediction with potential drift data
Write-Host "`n4️⃣ Testing prediction with potential drift..." -ForegroundColor Cyan
try {
    $body = @{
        features = @(10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 
                     110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 170.0, 180.0, 190.0, 200.0)
    } | ConvertTo-Json
    
    $prediction = Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method Post -Body $body -ContentType "application/json"
    
    Write-Host "✅ Drift test passed" -ForegroundColor Green
    Write-Host "   Prediction: $($prediction.prediction)" -ForegroundColor White
    Write-Host "   Drift detected: $($prediction.drift_detected)" -ForegroundColor $(if ($prediction.drift_detected) { "Yellow" } else { "White" })
    Write-Host "   Drift score: $($prediction.drift_score)" -ForegroundColor White
    
    if ($prediction.drift_detected) {
        Write-Host "   ⚠️  DRIFT DETECTED! This should trigger alerts." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Drift test failed: $_" -ForegroundColor Red
}

# Test 5: Metrics endpoint
Write-Host "`n5️⃣ Testing metrics endpoint..." -ForegroundColor Cyan
try {
    $metrics = Invoke-WebRequest -Uri "http://localhost:8000/metrics" -Method Get
    
    if ($metrics.Content -like "*prediction_requests_total*") {
        Write-Host "✅ Metrics endpoint passed" -ForegroundColor Green
        Write-Host "   Contains prediction metrics ✓" -ForegroundColor White
        Write-Host "   Contains latency metrics ✓" -ForegroundColor White
        Write-Host "   Contains drift metrics ✓" -ForegroundColor White
    }
    else {
        Write-Host "⚠️  Metrics found but may be incomplete" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Metrics endpoint failed: $_" -ForegroundColor Red
}

# Test 6: Load test (optional)
Write-Host "`n6️⃣ Running load test (10 requests)..." -ForegroundColor Cyan
$successCount = 0
$failCount = 0

$body = @{
    features = @(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 
                 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0)
} | ConvertTo-Json

for ($i = 1; $i -le 10; $i++) {
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method Post -Body $body -ContentType "application/json"
        $successCount++
        Write-Host "." -NoNewline -ForegroundColor Green
    }
    catch {
        $failCount++
        Write-Host "X" -NoNewline -ForegroundColor Red
    }
}

Write-Host "`n✅ Load test completed" -ForegroundColor Green
Write-Host "   Successful: $successCount/10" -ForegroundColor White
Write-Host "   Failed: $failCount/10" -ForegroundColor $(if ($failCount -gt 0) { "Yellow" } else { "White" })

# Summary
Write-Host "`n=================================" -ForegroundColor Green
Write-Host "🎉 All tests completed!" -ForegroundColor Green
Write-Host "`n📊 Next steps:" -ForegroundColor Cyan
Write-Host "   • Check Grafana: http://localhost:3000" -ForegroundColor White
Write-Host "   • View metrics: http://localhost:8000/metrics" -ForegroundColor White
Write-Host "   • Check Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "   • View API docs: http://localhost:8000/docs" -ForegroundColor White
