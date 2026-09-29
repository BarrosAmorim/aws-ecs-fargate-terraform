# ===================================================
# Estágio 1 (Builder): Compila dependências necessárias
# ===================================================
FROM python:3.12-slim AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Instala ferramentas necessárias para compilar pacotes como psutil
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc python3-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Instala os pacotes em um diretório isolado (/install)
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ===================================================
# Estágio 2 (Runner): Imagem final mínima e segura
# ===================================================
FROM python:3.12-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/install/bin:${PATH}" \
    PYTHONPATH="/install/lib/python3.12/site-packages"

# Cria um grupo e um usuário comum sem privilégios administrativos (UID 10001)
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/bash -m appuser

# Copia apenas as bibliotecas já compiladas do primeiro estágio
COPY --from=builder /install /install

# Copia o código da aplicação e define o novo usuário como dono do arquivo
COPY --chown=appuser:appgroup main.py .

# Troca a execução para o usuário não-root
USER 10001:10001

# Documenta a porta que a aplicação escuta internamente
EXPOSE 8000

# Executa o servidor ASGI Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]