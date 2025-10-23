#!/bin/bash
set -e

echo "🚀 Starting MLOps Quality Project on Minikube..."
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed. Please install it first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first."
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install it first."
    exit 1
fi

# 1. Start Minikube
echo -e "${BLUE}📦 Starting Minikube...${NC}"
minikube status &> /dev/null || minikube start --memory=8192 --cpus=4 --driver=docker

# Wait for Minikube to be ready
echo "⏳ Waiting for Minikube to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s

# 2. Use Minikube Docker environment
echo -e "${BLUE}🐳 Configuring Docker to use Minikube environment...${NC}"
eval $(minikube docker-env)

# 3. Train the model first
echo -e "${BLUE}🔬 Training ML model...${NC}"
python model/train.py

# 4. Build Docker image
echo -e "${BLUE}🔨 Building Docker image...${NC}"
docker build -t aiops-inference:latest .

# 5. Add Helm repositories
echo -e "${BLUE}📚 Adding Helm repositories...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 6. Deploy Prometheus + Grafana stack
echo -e "${BLUE}📈 Deploying Prometheus + Grafana monitoring stack...${NC}"
if ! helm list -n monitoring | grep -q monitoring; then
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        -n monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --wait \
        --timeout=5m
else
    echo "✅ Monitoring stack already installed"
fi

# 7. Deploy ArgoCD
echo -e "${BLUE}🔄 Deploying ArgoCD...${NC}"
if ! kubectl get namespace argocd &> /dev/null; then
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    echo "⏳ Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
else
    echo "✅ ArgoCD already installed"
fi

# 8. Deploy application Helm chart
echo -e "${BLUE}🚀 Deploying application Helm chart...${NC}"
helm upgrade --install aiops-inference ./helm -n aiops --create-namespace --wait

# 9. Wait for application pods to be ready
echo -e "${YELLOW}⏳ Waiting for application pods to be ready...${NC}"
kubectl wait --for=condition=Ready pods -l app=aiops-inference -n aiops --timeout=180s || true

# 10. Get ArgoCD admin password
echo -e "${BLUE}🔐 Retrieving ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Not available yet")

# 11. Setup port-forwarding in background
echo -e "${GREEN}🔗 Setting up port-forwarding...${NC}"

# Kill existing port-forwards
pkill -f "kubectl port-forward" || true
sleep 2

# Start port-forwards
nohup kubectl port-forward svc/aiops-inference 8000:8000 -n aiops > /dev/null 2>&1 &
nohup kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring > /dev/null 2>&1 &
nohup kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring > /dev/null 2>&1 &
nohup kubectl port-forward svc/argocd-server 8080:443 -n argocd > /dev/null 2>&1 &

# Wait for port-forwards to establish
sleep 5

# 12. Display service URLs
echo ""
echo -e "${GREEN}✅ All services are running!${NC}"
echo "================================================"
echo -e "${BLUE}📊 Service URLs:${NC}"
echo ""
echo -e "  🔮 FastAPI Inference:  ${YELLOW}http://localhost:8000${NC}"
echo -e "     Swagger UI:         ${YELLOW}http://localhost:8000/docs${NC}"
echo -e "     Metrics:            ${YELLOW}http://localhost:8000/metrics${NC}"
echo ""
echo -e "  📈 Grafana:            ${YELLOW}http://localhost:3000${NC}"
echo -e "     Username: ${GREEN}admin${NC}"
echo -e "     Password: ${GREEN}prom-operator${NC}"
echo ""
echo -e "  📊 Prometheus:         ${YELLOW}http://localhost:9090${NC}"
echo ""
echo -e "  🔄 ArgoCD:             ${YELLOW}https://localhost:8080${NC}"
echo -e "     Username: ${GREEN}admin${NC}"
echo -e "     Password: ${GREEN}${ARGOCD_PASSWORD}${NC}"
echo ""
echo "================================================"
echo ""
echo -e "${YELLOW}📝 Testing the API:${NC}"
echo ""
echo "curl -X POST http://localhost:8000/predict \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"features\": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]}'"
echo ""
echo "================================================"
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo "  kubectl get pods -n aiops              # Check application pods"
echo "  kubectl logs -f <pod-name> -n aiops    # View logs"
echo "  make retrain                           # Retrain and redeploy model"
echo "  make test                              # Test the API"
echo ""
echo -e "${GREEN}Press ENTER to stop all services and port-forwarding...${NC}"

read -r

# Cleanup
echo ""
echo -e "${BLUE}🧹 Cleaning up port-forwards...${NC}"
pkill -f "kubectl port-forward" || true

echo -e "${GREEN}✅ Done!${NC}"
