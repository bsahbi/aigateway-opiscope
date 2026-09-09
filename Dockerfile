# Dockerfile for llama.cpp with Qwen3.5-4B-Q4_K_M

FROM ghcr.io/ggml-org/llama.cpp:server

# Set working directory
WORKDIR /app

# Copy Qwen3.5-4B-Q4_K_M.gguf model (optional, only if present)
ARG MODEL_DIR=models
ARG MODEL_FILE
RUN if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then \
    cp -r "$MODEL_DIR" /app/models/ && \
    chown -R 1000:1000 /app/models/; \
fi

# Expose port
EXPOSE 8080

# Default command
CMD ["llama-server", "--host", "0.0.0.0", "--port", "8080"]
