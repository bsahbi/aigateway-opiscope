# Infrastructure: llama-server

This document describes the llama.cpp server deployment for the OpiScope AI Gateway.

## Overview

The inference layer uses [llama.cpp](https://github.com/ggml-org/llama.cpp) via its prebuilt Docker image `ghcr.io/ggml-org/llama.cpp:server`. This provides an OpenAI-compatible REST API (`/v1/chat/completions`, `/v1/models`, `/health`) backed by GGUF models.

## Docker Image

### Base Image

```
FROM ghcr.io/ggml-org/llama.cpp:server
```

The official image includes the `llama-server` binary. No build step required on the host.

### Dockerfile

```dockerfile
FROM ghcr.io/ggml-org/llama.cpp:server

WORKDIR /app

ARG MODEL_DIR=models
ARG MODEL_FILE
RUN if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then \
    cp -r "$MODEL_DIR" /app/models/ && \
    chown -R 1000:1000 /app/models/; \
fi

EXPOSE 8080
CMD ["llama-server", "--host", "0.0.0.0", "--port", "8080"]
```

## Running the Container

### Build

```bash
docker build -t llama-server:latest .
```

### Run (with model mounted)

```bash
docker run -d \
  --name llama-server \
  -p 8080:8080 \
  -v /path/to/models:/models \
  llama-server:latest \
  --model /models/Qwen3.5-4B-Q4_K_M.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size 4096 \
  --threads 8
```

### Run (model baked in at build time)

```bash
docker build -t llama-server:latest \
  --build-arg MODEL_DIR=models \
  --build-arg MODEL_FILE=Qwen3.5-4B-Q4_K_M.gguf .
```

## Verification

### Health Check

```bash
curl http://localhost:8080/health
# {"status":"ok"}
```

### List Models

```bash
curl http://localhost:8080/v1/models
# {"data":[{"id":"Qwen3.5-4B-Q4_K_M.gguf",...}],"object":"list"}
```

### Chat Completions

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```

## Deployment

### Target Machine

- **Host**: `192.168.1.10` (Windows, referred to as "Qwen")
- **Container runtime**: Docker Desktop (linux builder)

### Deploy Flow

1. Commit Dockerfile to feature branch
2. Open PR → merge to `master`
3. On target machine: `docker pull` / `docker build` + `docker run`
4. Verify `/health` returns `{"status":"ok"}`
5. Verify `/v1/models` lists the loaded model

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `--host` | `0.0.0.0` | Bind address |
| `--port` | `8080` | Listen port |
| `--ctx-size` | `4096` | Context window size |
| `--threads` | `8` | CPU threads |
| `--model` | — | Path to GGUF model file |

## Model: Qwen3.5-4B-Q4_K_M

- **Format**: GGUF (Q4_K_M quantization)
- **Size**: ~2.5 GB
- **Context**: 4096 tokens
- **Provider**: [Qwen](https://huggingface.co/Qwen)

## See Also

- [llama.cpp Docker docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/docker.md)
- [OpiScopeAIGateway Design](../OpiScopeAIGateway-design.md)
