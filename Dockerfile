FROM python:3.10-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    fastapi==0.109.0 \
    uvicorn==0.27.0 \
    scikit-learn==1.4.0 \
    numpy==1.26.3 \
    scipy==1.12.0 \
    prometheus-client==0.19.0 \
    pydantic==2.5.3

# Copy application code
COPY app/ /app/app/
COPY model/ /app/model/

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')"

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
