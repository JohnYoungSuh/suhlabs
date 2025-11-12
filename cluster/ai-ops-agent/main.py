from fastapi import FastAPI
from datetime import datetime
import os

app = FastAPI(
    title="AI Ops Agent",
    version="0.1.0",
    description="Natural language infrastructure automation"
)

@app.get("/")
def root():
    return {
        "service": "AI Ops Agent",
        "version": "0.1.0",
        "status": "operational"
    }

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": os.getenv("ENVIRONMENT", "development")
    }

@app.get("/ready")
def ready():
    # Later: Check Ollama connectivity, Vault, etc.
    return {"ready": True}
