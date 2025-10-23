# MLOps Quality Project

Production-ready MLOps inference service with drift detection, monitoring, and GitOps deployment on Kubernetes.

---

## 🚀 Quick Start

### Prerequisites
- Docker Desktop (running)
- Minikube: `winget install Kubernetes.minikube`
- kubectl: `winget install Kubernetes.kubectl`
- Helm: `winget install Helm.Helm`
- Python 3.10+: `winget install Python.Python.3.10`

### Launch (4 steps)

1. **Start Docker Desktop** and wait until ready
2. **Open PowerShell as Administrator**
3. **Run:**
```powershell
cd E:\Mlops-project
.\run_local.ps1
```
4. **Wait 5-10 minutes** ⏱️

---

## 🌐 Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **API (Swagger)** | http://localhost:8000/docs | - |
| **Grafana** | http://localhost:3000 | admin / prom-operator |
| **Prometheus** | http://localhost:9090 | - |
| **ArgoCD** | https://localhost:8080 | admin / (see terminal) |

---

## 🧪 Test API

```powershell
# Automated tests
.\test_api.ps1

# Manual test
Invoke-RestMethod -Uri http://localhost:8000/healthz

# Prediction
$body = '{"features": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]}'
Invoke-RestMethod -Uri http://localhost:8000/predict -Method POST -Body $body -ContentType "application/json"
```

---

## 📊 What's Deployed

The script automatically deploys:
- ✅ **Minikube** - Local Kubernetes cluster
- ✅ **ML Model** - RandomForest classifier (auto-trained)
- ✅ **FastAPI** - REST API for inference
- ✅ **Drift Detection** - Kolmogorov-Smirnov test
- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Visualization dashboards
- ✅ **ArgoCD** - GitOps continuous deployment

---

## 🎯 Features

### ML Service
- REST API with FastAPI
- Real-time drift detection
- Prometheus metrics export
- JSON structured logging
- Health checks

### Monitoring
- **Request rate** and **latency** (P50, P95)
- **Drift events** detection and alerting
- **Model health** status
- **Resource usage** (CPU/Memory)

### Infrastructure
- **Kubernetes** deployment with Helm
- **Docker** containerization
- **GitOps** with ArgoCD
- **Auto-scaling** (HPA)

---

## 📁 Project Structure

```
E:\Mlops-project\
├── run_local.ps1       ← Main deployment script
├── test_api.ps1        ← API testing
├── test_docker.ps1     ← Docker testing
├── app/
│   └── main.py         ← FastAPI service
├── model/
│   └── train.py        ← Model training
├── helm/               ← Kubernetes manifests
├── Dockerfile          ← Container definition
└── README.md           ← This file
```

---

## 🔄 Useful Commands

### View Status
```powershell
kubectl get pods -n aiops
kubectl logs -f deployment/aiops-inference -n aiops
```

### Retrain Model
```powershell
python model\train.py
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
docker build -t aiops-inference:latest .
kubectl rollout restart deployment/aiops-inference -n aiops
```

### Stop Services
```powershell
# Press ENTER in the script window, or:
minikube stop

# Complete cleanup:
minikube delete
```

---

## 🐛 Troubleshooting

### "docker not running"
→ Open Docker Desktop and wait 2 minutes

### "minikube won't start"
```powershell
minikube delete
minikube start --memory=8192 --cpus=4 --driver=docker
```

### "port already in use"
```powershell
Get-Job | Stop-Job | Remove-Job
```

### View logs
```powershell
kubectl logs -n aiops <pod-name>
kubectl describe pod -n aiops <pod-name>
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│         Minikube Cluster             │
├─────────────────────────────────────┤
│                                      │
│  FastAPI ──► Prometheus ──► Grafana │
│     │                                │
│     ▼                                │
│  Drift Detection                     │
│                                      │
│  ArgoCD (GitOps)                     │
│                                      │
└─────────────────────────────────────┘
```

---

## 📖 Technical Details

### FastAPI Service
- **Framework**: FastAPI 0.109.0
- **Model**: RandomForestClassifier (scikit-learn)
- **Drift Detection**: KS test (threshold: 0.05)
- **Metrics**: Prometheus exposition format

### Docker Image
- **Base**: python:3.10-slim
- **Size**: ~398MB
- **Health Check**: Automatic every 30s

### Kubernetes
- **Replicas**: 2 (auto-scaling 2-5)
- **Resources**: 250m CPU / 256Mi RAM
- **Probes**: Liveness and readiness checks

---

## 🎓 For Presentation

### Key Points
1. **Complete MLOps pipeline** - Training, deployment, monitoring
2. **Drift detection** - Automatic data quality monitoring
3. **GitOps** - ArgoCD for continuous deployment
4. **Observability** - Prometheus + Grafana dashboards
5. **Production-ready** - Health checks, auto-scaling, logging

### Demo Flow
1. Show `.\run_local.ps1` deployment
2. Open http://localhost:8000/docs (Swagger)
3. Make predictions via API
4. Show Grafana dashboard (http://localhost:3000)
5. Demonstrate drift detection

---

## 📄 License

MIT License

---

**Ready for production! 🎉**

For issues, check logs: `kubectl logs -n aiops deployment/aiops-inference`
