# Diário de Bordo: Passo a Passo da Aplicação (Pasta app)

Neste documento eu registrei tudo o que fiz na pasta `app/`, explicando o motivo de cada arquivo, os comandos que usei, os problemas que encontrei e os testes que realizei na minha máquina.

---

## 1. O que eu construí na pasta app

Criei uma API simples em Python para servir como a aplicação que vai rodar dentro dos containers da AWS. A pasta ficou com a seguinte estrutura:

```text
app/
├── .dockerignore    # Arquivos que o Docker não deve copiar na hora de gerar a imagem
├── Dockerfile       # Instruções para empacotar a aplicação com segurança
├── main.py          # O código Python da API com as rotas
└── requirements.txt # Lista de bibliotecas que o Python precisa baixar
```

---

## 2. Passo a Passo dos Arquivos

### Passo 2.1: As dependências (`app/requirements.txt`)
Criei este arquivo para listar as três ferramentas que o meu código precisa para rodar:

```text
fastapi>=0.110.0,<0.112.0
uvicorn[standard]>=0.28.0,<0.30.0
psutil>=5.9.8,<6.0.0
```

* **FastAPI:** O framework que usei para criar as rotas web de forma rápida.
* **Uvicorn:** O servidor que faz a aplicação rodar e escutar na porta de rede.
* **Psutil:** Uma biblioteca que serve para ler informações do computador (quanto de memória e processador estão sendo usados).
* **Por que fixei as versões?** Para garantir que, se eu ou outra pessoa rodar o projeto daqui a seis meses, o Python baixe as mesmas versões e nada quebre de surpresa.

---

### Passo 2.2: O código da API (`app/main.py`)
Escrevi o código da API com duas rotas principais e a documentação web:

```python
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
    """Rota para o Load Balancer checar se a aplicação está viva."""
    return {"status": "healthy", "timestamp": time.time()}


@app.get("/diag", status_code=status.HTTP_200_OK)
def diagnostics():
    """Rota para inspecionar informações de máquina e segurança."""
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
```

* **`/health`:** É a rota de "estou vivo". O balanceador da AWS vai bater nela de tempos em tempos. Se ela responder status 200, a AWS sabe que o container está saudável.
* **`/diag`:** Mostra quanto tempo a API está ligada (`uptime_seconds`), o nome da máquina/container (`hostname`) e o número do usuário no sistema operacional (`running_user_id`).
* **`/api-docs`:** Mudei o endereço da tela interativa do FastAPI para `/api-docs` para não confundir com a minha pasta física `docs/` do projeto.

---

### Passo 2.3: Ignorando arquivos desnecessários (`app/.dockerignore`)
Criei o `.dockerignore` para impedir que arquivos temporários do meu computador fossem jogados para dentro da imagem Docker:

```text
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv/
.pytest_cache/
.coverage
htmlcov/
tests/
.git
.gitignore
```

---

### Passo 2.4: O Dockerfile Seguro (`app/Dockerfile`)
Não criei um Dockerfile comum. Montei ele em duas partes (multi-stage) e configurei para não rodar como administrador (root):

```dockerfile
# ===================================================
# Estágio 1 (Builder): Compila as ferramentas
# ===================================================
FROM python:3.12-slim AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc python3-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ===================================================
# Estágio 2 (Runner): Imagem final limpa e segura
# ===================================================
FROM python:3.12-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/install/bin:${PATH}" \
    PYTHONPATH="/install/lib/python3.12/site-packages"

# Crio um usuário comum (UID 10001) para não usar root
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/bash -m appuser

# Copio apenas as bibliotecas prontas do primeiro estágio
COPY --from=builder /install /install

# Copio o código e defino o usuário comum como dono dele
COPY --chown=appuser:appgroup main.py .

# Mudo a execução para o usuário seguro
USER 10001:10001

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

* **Por que duas etapas (multi-stage)?** A biblioteca `psutil` precisa de ferramentas extras (`gcc`) para ser instalada. No estágio 1 eu compilo tudo. No estágio 2 eu copio só o resultado final. A imagem final fica muito menor e sem ferramentas soltas que invasores poderiam usar.
* **Por que `USER 10001:10001`?** Por padrão, containers rodam como `root` (o chefe supremo do sistema). Se um invasor achar uma brecha no código, ele vira root. Criando o usuário `appuser` (número 10001), o processo fica sem privilégios administrativos.
* **`PYTHONUNBUFFERED=1`:** Garante que qualquer print ou log saia imediatamente na tela, sem ficar preso na memória temporária.

---

## 3. Problema que encontrei e como resolvi

No meu primeiro teste de build, o Docker exibiu este aviso:
```text
UndefinedVar: Usage of undefined variable '$PYTHONPATH'
```

* **O que aconteceu:** Eu tentei juntar `${PYTHONPATH}` no final de uma linha, mas essa variável ainda não existia na imagem base.
* **Como resolvi:** Em vez de tentar juntar uma variável vazia, coloquei apenas o caminho direto onde as pastas estavam instaladas:
  `PYTHONPATH="/install/lib/python3.12/site-packages"`.
* O aviso sumiu e o build rodou completamente limpo.

---

## 4. Testes que fiz no meu computador

Para ter certeza de que tudo funcionava antes de pensar na nuvem da AWS, rodei quatro comandos no meu terminal:

1. **Construí a imagem Docker:**
   ```bash
   docker build -t aws-ecs-fargate-api:local -f app/Dockerfile app/
   ```

2. **Iniciei o container em segundo plano:**
   ```bash
   docker run -d --name test-api -p 8000:8000 aws-ecs-fargate-api:local
   ```

3. **Testei a rota `/health`:**
   ```bash
   curl -s http://localhost:8000/health
   ```
   *Resultado que obtive:* `{"status":"healthy","timestamp":1790263600.5165477}`. Provou que a aplicação subiu e responde rápido.

4. **Testei a rota `/diag` (Segurança confirmada):**
   ```bash
   curl -s http://localhost:8000/diag
   ```
   *Resultado que obtive:*
   ```json
   {
     "app": {
       "name": "aws-ecs-fargate-api",
       "uptime_seconds": 67.32
     },
     "runtime": {
       "hostname": "e69688e80633",
       "running_user_id": 10001,
       "environment": "local"
     },
     "system_resources": {
       "cpu_percent": 0.0,
       "memory_total_mb": 8062.33,
       "memory_available_mb": 5640.52,
       "memory_used_percent": 30.0
     }
   }
   ```
   * **O que esse teste me provou:**
     * O campo `"running_user_id": 10001` comprovou que o container não roda como root.
     * O `"hostname": "e69688e80633"` mostrou o ID único daquele container de teste.
     * O `"uptime_seconds"` foi aumentando conforme o tempo passava.

5. **Limpeza do teste:**
   Depois de validar, desliguei e removi o container local para liberar a porta do computador:
   ```bash
   docker stop test-api
   docker rm test-api
   ```

