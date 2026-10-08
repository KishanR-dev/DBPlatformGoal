"""Metrics endpoint.

Exposes application metrics in Prometheus text format and as JSON.
Designed for consumption by the future Command Center (Project 5).
"""

from fastapi import APIRouter, Depends
from fastapi.responses import PlainTextResponse
from sqlalchemy.orm import Session

from app.core.metrics import metrics as metrics_collector
from app.db.database import get_db
from app.domain.enums import IncidentStatus, RequestStatus
from app.repositories.incident_repository import IncidentRepository
from app.repositories.request_repository import RequestRepository

router = APIRouter(tags=["Metrics"])


def _refresh_db_gauges(db: Session) -> None:
    """Sync gauge values from the database for accurate point-in-time reporting."""
    req_repo = RequestRepository(db)
    inc_repo = IncidentRepository(db)

    for s in RequestStatus:
        count = req_repo.count_by_status(s.value)
        metrics_collector.set_gauge("requests_by_status", count, labels={"status": s.value})

    for s in IncidentStatus:
        count = inc_repo.count_by_status(s.value)
        metrics_collector.set_gauge("incidents_by_status", count, labels={"status": s.value})

    metrics_collector.set_gauge("incidents_open", inc_repo.count_open())


@router.get(
    "/metrics",
    response_class=PlainTextResponse,
    summary="Prometheus-compatible metrics",
    description="Application metrics in Prometheus text exposition format.",
)
def get_metrics(db: Session = Depends(get_db)) -> str:
    _refresh_db_gauges(db)
    return metrics_collector.to_prometheus()


@router.get(
    "/metrics/json",
    summary="Metrics as JSON",
    description="Application metrics as a JSON object for programmatic consumption.",
)
def get_metrics_json(db: Session = Depends(get_db)) -> dict:
    _refresh_db_gauges(db)
    return metrics_collector.snapshot()
