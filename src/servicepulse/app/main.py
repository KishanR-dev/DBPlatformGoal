"""ServicePulse — Main application entry point.

FastAPI application setup with middleware, routes, and startup/shutdown hooks.
"""

import time
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.routes import health, incidents, metrics, requests
from app.core.config import get_settings
from app.core.errors import register_error_handlers
from app.core.logging import get_logger, setup_logging
from app.core.metrics import metrics as metrics_collector
from app.db.database import init_db

logger = get_logger("main")

_settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncGenerator[None, None]:
    """Lifespan context manager for application startup and shutdown."""
    setup_logging(_settings.log_level)
    logger.info(
        "Starting application",
        extra={"event": "APP_STARTUP", "environment": _settings.app_env},
    )
    init_db()
    metrics_collector.increment("app_startup_total")
    yield
    logger.info(
        "Shutting down",
        extra={"event": "APP_SHUTDOWN", "environment": _settings.app_env},
    )


app = FastAPI(
    title=_settings.app_name,
    version=_settings.app_version,
    description=_settings.app_name,
    redoc_url=None,
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Middleware
# ---------------------------------------------------------------------------


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """Assign correlation IDs to requests and pass them through."""

    async def dispatch(self, request: Request, call_next):
        # Prefer client-supplied ID, otherwise generate one
        correlation_id = request.headers.get("X-Correlation-ID") or request.headers.get(
            "X-Request-ID"
        )
        if not correlation_id:
            import uuid

            correlation_id = str(uuid.uuid4())[:8]

        request.state.correlation_id = correlation_id

        # Log request start
        request.state.start_time = time.perf_counter()
        logger.info(
            "Request received",
            extra={
                "event": "HTTP_REQUEST_START",
                "correlation_id": correlation_id,
                "method": request.method,
                "path": request.url.path,
            },
        )

        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id

        # Log request completion
        duration_ms = (time.perf_counter() - request.state.start_time) * 1000
        logger.info(
            "Request completed",
            extra={
                "event": "HTTP_REQUEST_COMPLETE",
                "correlation_id": correlation_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round(duration_ms, 2),
            },
        )

        # Track HTTP metrics
        metrics_collector.increment(
            "http_requests_total",
            labels={
                "method": request.method,
                "endpoint": request.url.path,
                "status": str(response.status_code),
            },
        )
        metrics_collector.observe(
            "http_request_duration",
            duration_ms,
            labels={"endpoint": request.url.path},
        )

        return response


class MetricsMiddleware(BaseHTTPMiddleware):
    """Track overall request counts and durations."""

    async def dispatch(self, request: Request, call_next):
        metrics_collector.increment("total_requests")
        start = time.perf_counter()
        response = await call_next(request)
        duration = (time.perf_counter() - start) * 1000
        metrics_collector.increment("processed_requests")
        metrics_collector.observe("request_latency", duration)
        return response


app.add_middleware(CorrelationIdMiddleware)
app.add_middleware(MetricsMiddleware)


# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------

register_error_handlers(app)


# ---------------------------------------------------------------------------
# API Routes
# ---------------------------------------------------------------------------

app.include_router(health.router)
app.include_router(requests.router, prefix="/api/v1")
app.include_router(incidents.router, prefix="/api/v1")
app.include_router(metrics.router, prefix="/api/v1")


@app.get("/", include_in_schema=False)
def root():
    return {
        "service": _settings.app_name,
        "version": _settings.app_version,
        "status": "running",
        "docs": "/docs",
        "health": "/health",
    }
