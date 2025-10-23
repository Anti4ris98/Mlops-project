#!/usr/bin/env python3
"""
FastAPI inference service with drift detection, metrics, and health checks.
"""
import pickle
import os
import json
import logging
import sys
import time
from pathlib import Path
from typing import List, Dict, Any

import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
from scipy import stats

# JSON logging setup
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s"}',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('prediction_requests_total', 'Total prediction requests')
REQUEST_LATENCY = Histogram('prediction_latency_seconds', 'Prediction latency')
DRIFT_EVENTS = Counter('drift_events_total', 'Total drift events detected')
MODEL_HEALTH = Gauge('model_health', 'Model health status (1=healthy, 0=unhealthy)')

app = FastAPI(title="MLOps Inference Service", version="1.0.0")

# Global variables
model = None
reference_data = None
drift_threshold = float(os.getenv("DRIFT_THRESHOLD", "0.05"))
model_path = os.getenv("MODEL_PATH", "/app/model/model.pkl")
reference_path = os.getenv("REFERENCE_PATH", "/app/model/reference_data.pkl")

class PredictionRequest(BaseModel):
    features: List[float]

class PredictionResponse(BaseModel):
    prediction: int
    probability: List[float]
    drift_detected: bool
    drift_score: float

@app.on_event("startup")
async def load_model():
    """Load model and reference data on startup."""
    global model, reference_data
    
    try:
        logger.info(f"Loading model from {model_path}")
        with open(model_path, "rb") as f:
            model = pickle.load(f)
        
        logger.info(f"Loading reference data from {reference_path}")
        with open(reference_path, "rb") as f:
            reference_data = pickle.load(f)
        
        MODEL_HEALTH.set(1)
        logger.info("Model and reference data loaded successfully")
    except Exception as e:
        MODEL_HEALTH.set(0)
        logger.error(f"Failed to load model: {str(e)}")
        raise

def detect_drift(features: np.ndarray) -> tuple[bool, float]:
    """
    Simple drift detection using Kolmogorov-Smirnov test.
    Compares feature distribution to reference data.
    """
    if reference_data is None:
        return False, 0.0
    
    try:
        # Calculate KS statistic for each feature
        ks_scores = []
        for i in range(reference_data.shape[1]):
            ks_stat, p_value = stats.ks_2samp(
                reference_data[:, i],
                features[:, i] if features.ndim > 1 else [features[i]]
            )
            ks_scores.append(ks_stat)
        
        # Average KS score
        avg_ks_score = np.mean(ks_scores)
        drift = avg_ks_score > drift_threshold
        
        if drift:
            DRIFT_EVENTS.inc()
            logger.warning(f"Drift detected! KS score: {avg_ks_score:.4f}")
        
        return drift, float(avg_ks_score)
    except Exception as e:
        logger.error(f"Drift detection failed: {str(e)}")
        return False, 0.0

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """Make prediction with drift detection."""
    start_time = time.time()
    REQUEST_COUNT.inc()
    
    try:
        if model is None:
            raise HTTPException(status_code=503, detail="Model not loaded")
        
        # Prepare features
        features_array = np.array(request.features).reshape(1, -1)
        
        # Check drift
        drift_detected, drift_score = detect_drift(features_array)
        
        # Make prediction
        prediction = int(model.predict(features_array)[0])
        probabilities = model.predict_proba(features_array)[0].tolist()
        
        # Record latency
        latency = time.time() - start_time
        REQUEST_LATENCY.observe(latency)
        
        logger.info({
            "event": "prediction",
            "prediction": prediction,
            "drift_detected": drift_detected,
            "drift_score": drift_score,
            "latency": latency
        })
        
        return PredictionResponse(
            prediction=prediction,
            probability=probabilities,
            drift_detected=drift_detected,
            drift_score=drift_score
        )
    
    except Exception as e:
        logger.error(f"Prediction failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/healthz")
async def health_check():
    """Health check endpoint for Kubernetes."""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "healthy"}

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/")
async def root():
    """Root endpoint with service info."""
    return {
        "service": "MLOps Inference Service",
        "version": "1.0.0",
        "endpoints": {
            "predict": "/predict",
            "health": "/healthz",
            "metrics": "/metrics"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
