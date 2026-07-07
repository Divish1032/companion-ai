FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir uv
COPY services/realtime-agent/pyproject.toml ./pyproject.toml
RUN uv pip install --system .

COPY services/realtime-agent/app ./app
COPY config ./config

EXPOSE 8001
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
