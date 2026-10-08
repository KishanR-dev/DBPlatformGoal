"""Centralized application error types and FastAPI exception handlers."""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

# ---------------------------------------------------------------------------
# Exception hierarchy
# ---------------------------------------------------------------------------


class ServicePulseError(Exception):
    """Base exception for all application errors."""

    def __init__(self, code: str, message: str, status_code: int = 500, **extra):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.extra = extra
        super().__init__(message)


class ValidationError(ServicePulseError):
    def __init__(self, message: str, **extra):
        super().__init__("VALIDATION_ERROR", message, status_code=422, **extra)


class NotFoundError(ServicePulseError):
    def __init__(self, resource: str, identifier: str):
        super().__init__(
            f"{resource.upper()}_NOT_FOUND",
            f"The requested {resource} was not found.",
            status_code=404,
            **{f"{resource}_id": identifier},
        )


class InvalidStateTransitionError(ServicePulseError):
    def __init__(self, current: str, target: str):
        super().__init__(
            "INVALID_STATE_TRANSITION",
            f"Cannot transition from {current} to {target}.",
            status_code=409,
            current_status=current,
            target_status=target,
        )


class DatabaseError(ServicePulseError):
    def __init__(self, message: str = "A database error occurred."):
        super().__init__("DATABASE_ERROR", message, status_code=500)


class ProcessingError(ServicePulseError):
    def __init__(self, message: str = "Request processing failed."):
        super().__init__("PROCESSING_ERROR", message, status_code=500)


class FailureSimulationError(ServicePulseError):
    def __init__(self, message: str = "Simulated failure triggered."):
        super().__init__("SIMULATED_FAILURE", message, status_code=500)


# ---------------------------------------------------------------------------
# FastAPI exception handlers
# ---------------------------------------------------------------------------


def _build_error_body(error: ServicePulseError, correlation_id: str | None) -> dict:
    body: dict = {"code": error.code, "message": error.message}
    if correlation_id:
        body["correlation_id"] = correlation_id
    body.update(error.extra)
    return {"error": body}


async def servicepulse_error_handler(request: Request, exc: ServicePulseError) -> JSONResponse:
    correlation_id = getattr(request.state, "correlation_id", None)
    return JSONResponse(
        status_code=exc.status_code,
        content=_build_error_body(exc, correlation_id),
    )


async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    """Catch-all for unexpected errors. Never exposes stack traces."""
    correlation_id = getattr(request.state, "correlation_id", None)
    body: dict = {
        "code": "INTERNAL_ERROR",
        "message": "An unexpected error occurred.",
    }
    if correlation_id:
        body["correlation_id"] = correlation_id
    return JSONResponse(status_code=500, content={"error": body})


def register_error_handlers(app: FastAPI) -> None:
    """Attach all exception handlers to the FastAPI application."""
    app.add_exception_handler(ServicePulseError, servicepulse_error_handler)
    app.add_exception_handler(Exception, unhandled_error_handler)
