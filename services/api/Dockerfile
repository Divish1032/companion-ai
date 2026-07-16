FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir uv
COPY services/api/pyproject.toml ./pyproject.toml
# Docker Desktop on Apple Silicon exposes no CUDA device to Linux containers.
# Select PyTorch CPU wheels explicitly so model-serving does not pull CUDA runtimes.
RUN uv pip install --system --torch-backend cpu '.[model-serving]'

COPY services/api/app ./app
COPY config ./config

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
