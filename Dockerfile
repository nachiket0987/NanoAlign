# NanoAlign Containerized LLM Post-Training & Evaluation Environment
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies & Python 3.12
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3-pip \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# Copy dependency definition and lockfile
COPY pyproject.toml uv.lock ./

# Sync dependencies using uv
RUN uv sync --frozen

# Copy source code and scripts
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY README.md ./

# Expose default port for optional vLLM / API serving
EXPOSE 8000

# Default command: run identity SFT baseline
CMD ["uv", "run", "python", "-m", "src.identity_sft"]
