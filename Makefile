.PHONY: help train build deploy forward retrain clean test

help:
	@echo "MLOps Quality Project - Makefile"
	@echo "================================="
	@echo "train       - Train the ML model"
	@echo "build       - Build Docker image (in Minikube)"
	@echo "deploy      - Deploy Helm chart to Minikube"
	@echo "forward     - Setup port-forwarding"
	@echo "retrain     - Retrain model and redeploy"
	@echo "clean       - Clean up resources"
	@echo "test        - Test the inference endpoint"

train:
	@echo "🔬 Training model..."
	python model/train.py

build:
	@echo "🐳 Building Docker image in Minikube..."
	eval $$(minikube docker-env) && docker build -t aiops-inference:latest .

deploy:
	@echo "📦 Deploying Helm chart..."
	helm upgrade --install aiops-inference ./helm -n aiops --create-namespace

forward:
	@echo "🔗 Setting up port-forwards..."
	@echo "FastAPI: http://localhost:8000"
	@echo "Grafana: http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"
	@echo "ArgoCD: https://localhost:8080"
	@kubectl port-forward svc/aiops-inference 8000:8000 -n aiops &
	@kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &
	@kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &
	@kubectl port-forward svc/argocd-server 8080:443 -n argocd &

retrain:
	@echo "🔄 Retraining model and redeploying..."
	$(MAKE) train
	$(MAKE) build
	kubectl rollout restart deployment/aiops-inference -n aiops
	@echo "✅ Retrain complete"

clean:
	@echo "🧹 Cleaning up..."
	helm uninstall aiops-inference -n aiops || true
	kubectl delete namespace aiops || true

test:
	@echo "🧪 Testing inference endpoint..."
	@curl -X POST http://localhost:8000/predict \
		-H "Content-Type: application/json" \
		-d '{"features": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]}'
