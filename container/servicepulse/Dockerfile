# ==============================================================================
# Stage 1: Build & Dependency Resolution Stage
# ==============================================================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Install core build dependencies if needed (prevent pip caching to reduce footprint)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --prefix=/install -r requirements.txt

# ==============================================================================
# Stage 2: Hardened Runtime Stage
# ==============================================================================
FROM python:3.12-slim AS runtime

# Label image with metadata according to platform engineering taxonomy
LABEL maintainer="DB Platform Engineering Team" \
      workload="servicepulse" \
      version="1.1.0" \
      base_image="python:3.12-slim"

WORKDIR /app

# Create dedicated non-root user and group with deterministic UID/GID 1000
RUN groupadd -g 1000 appuser && \
    useradd -u 1000 -g appuser -d /app -s /usr/sbin/nologin appuser

# Copy installed Python packages from builder stage
COPY --from=builder /install /usr/local

# Copy application source code and package metadata with non-root ownership
COPY --chown=appuser:appuser app /app/app
COPY --chown=appuser:appuser pyproject.toml /app/pyproject.toml

# Create writable data directory for SQLite database storage and set ownership
RUN mkdir -p /app/data /tmp && \
    chown -R appuser:appuser /app/data /tmp && \
    chmod 700 /app/data /tmp

# Enforce non-root execution
USER 1000:1000

# Set deterministic runtime environment defaults
ENV PYTHONPATH=/app \
    APP_ENV=production \
    APP_HOST=0.0.0.0 \
    APP_PORT=8000 \
    LOG_LEVEL=INFO \
    DATABASE_URL=sqlite:////app/data/servicepulse.db \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Expose container HTTP port
EXPOSE 8000

# Define native container healthcheck probing the verified /health endpoint
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health', timeout=2).getcode() == 200 else 1)"

# Execution entrypoint: exec form avoiding intermediate shell interpretation
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
