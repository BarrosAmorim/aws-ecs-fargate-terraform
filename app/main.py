import os
import socket
import time
import psutil
from fastapi import FastAPI, status
from fastapi.responses import JSONResponse

app = FastAPI(
    title="ECS Fargate Health & Diagnostics API",
    version="1.0.0",
    docs_url="/api-docs",
    redoc_url=None
)

START_TIME = time.time()


@app.get("/health", status_code=status.HTTP_200_OK)
def health_check():
    """
    Endpoint consumido pelo Application Load Balancer para verificar a saude da task.
    Retorna apenas o status e timestamp para resposta rapida com baixo consumo de CPU.
    """
    return {"status": "healthy", "timestamp": time.time()}


@app.get("/diag", status_code=status.HTTP_200_OK)
def diagnostics():
    """
    Retorna informacoes de runtime para validar que o container roda com
    usuario nao-root e verificar alocacao de recursos da task.
    """
    memory = psutil.virtual_memory()
    uptime_seconds = round(time.time() - START_TIME, 2)

    return JSONResponse(
        content={
            "app": {
                "name": "aws-ecs-fargate-api",
                "uptime_seconds": uptime_seconds
            },
            "runtime": {
                "hostname": socket.gethostname(),
                "running_user_id": os.getuid(),
                "environment": os.getenv("ENVIRONMENT", "local")
            },
            "system_resources": {
                "cpu_percent": psutil.cpu_percent(interval=None),
                "memory_total_mb": round(memory.total / (1024 * 1024), 2),
                "memory_available_mb": round(memory.available / (1024 * 1024), 2),
                "memory_used_percent": memory.percent
            }
        }
    )