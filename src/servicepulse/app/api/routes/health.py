"""Health check endpoint.

Reports component-level health status. Returns 503 if any component is unhealthy.
"""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.database import get_db

router = APIRouter(tags=["Health"])


@router.get(
    "/health",
    summary="System health check",
    description="Returns health status of the application and its dependencies.",
    responses={
        200: {"description": "All components healthy"},
        503: {"description": "One or more components unhealthy"},
    },
)
def health_check(response: Response, db: Session = Depends(get_db)):
    settings = get_settings()
    components = {"application": "healthy"}

    # Database connectivity check
    try:
        db.execute(text("SELECT 1"))
        components["database"] = "healthy"
    except Exception:
        components["database"] = "unhealthy"

    overall = "healthy" if all(v == "healthy" for v in components.values()) else "unhealthy"

    if overall != "healthy":
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "status": overall,
        "version": settings.app_version,
        "environment": settings.app_env,
        "timestamp": datetime.now(UTC).isoformat(),
        "components": components,
    }
