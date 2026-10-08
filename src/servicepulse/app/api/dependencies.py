"""FastAPI dependency injection for database sessions and services."""

from fastapi import Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.services.incident_service import IncidentService
from app.services.request_service import RequestService


def get_request_service(db: Session = Depends(get_db)) -> RequestService:
    return RequestService(db)


def get_incident_service(db: Session = Depends(get_db)) -> IncidentService:
    return IncidentService(db)
