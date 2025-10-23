#!/usr/bin/env python3
"""
Model training script for MLOps quality project.
Generates synthetic classification data and trains RandomForestClassifier.
"""
import pickle
import os
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import numpy as np

def train_model():
    """Train a simple RandomForest model on synthetic data."""
    print("🔬 Generating synthetic dataset...")
    X, y = make_classification(
        n_samples=1000,
        n_features=20,
        n_informative=15,
        n_redundant=5,
        n_classes=2,
        random_state=42
    )
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    print("🚀 Training RandomForestClassifier...")
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"✅ Model accuracy: {accuracy:.4f}")
    print(f"\n{classification_report(y_test, y_pred)}")
    
    # Save model
    model_dir = Path(__file__).parent
    model_path = model_dir / "model.pkl"
    
    with open(model_path, "wb") as f:
        pickle.dump(model, f)
    
    print(f"💾 Model saved to {model_path}")
    
    # Save reference data for drift detection
    reference_data = X_train[:100]  # Use subset as reference
    ref_path = model_dir / "reference_data.pkl"
    with open(ref_path, "wb") as f:
        pickle.dump(reference_data, f)
    
    print(f"💾 Reference data saved to {ref_path}")
    
    return model_path, accuracy

if __name__ == "__main__":
    train_model()
