"""Service layer for incident lifecycle operations."""

import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.errors import DatabaseError, NotFoundError
from app.core.logging import get_logger
from app.core.metrics import metrics
from app.db.models import IncidentModel
from app.domain.enums import IncidentStatus
from app.domain.incident import validate_incident_transition
from app.repositories.incident_repository import IncidentRepository
from app.schemas.incident import CreateIncidentSchema, UpdateIncidentSchema

logger = get_logger("incident_service")


class IncidentService:
    def __init__(self, db: Session):
        self.repo = IncidentRepository(db)

    def create_incident(self, data: CreateIncidentSchema) -> IncidentModel:
        """Create a new incident with status OPEN."""
        incident_id = f"INC-{uuid.uuid4().hex[:8].upper()}"

        model = IncidentModel(
            incident_id=incident_id,
            title=data.title,
            description=data.description,
            severity=data.severity.value,
            status=IncidentStatus.OPEN.value,
            affected_service=data.affected_service,
            related_request_id=data.related_request_id,
        )

        try:
            created = self.repo.create(model)
        except Exception as e:
            logger.error(
                "Failed to create incident",
                extra={"event": "DATABASE_ERROR", "error": str(e)},
            )
            raise DatabaseError("Failed to persist incident.") from e

        metrics.increment_gauge("incidents_open", 1)
        metrics.increment("incidents_total")
        logger.info(
            "Incident created",
            extra={
                "event": "INCIDENT_CREATED",
                "incident_id": incident_id,
                "severity": data.severity.value,
                "title": data.title,
            },
        )
        return created

    def get_incident(self, incident_id: str) -> IncidentModel:
        model = self.repo.get_by_incident_id(incident_id)
        if not model:
            raise NotFoundError("incident", incident_id)
        return model

    def list_incidents(self, skip: int = 0, limit: int = 20) -> tuple[list[IncidentModel], int]:
        items = self.repo.list_incidents(skip=skip, limit=limit)
        total = self.repo.count()
        return items, total

    def update_incident(self, incident_id: str, data: UpdateIncidentSchema) -> IncidentModel:
        """Update incident fields. If status is provided, validate the transition."""
        model = self.get_incident(incident_id)
        now = datetime.now(UTC)

        if data.status is not None:
            current = IncidentStatus(model.status)
            validate_incident_transition(current, data.status)
            model.status = data.status.value

            if data.status == IncidentStatus.RESOLVED:
                model.resolved_at = now
                metrics.increment_gauge("incidents_open", -1)
                logger.info(
                    "Incident resolved",
                    extra={"event": "INCIDENT_RESOLVED", "incident_id": incident_id},
                )

        if data.root_cause is not None:
            model.root_cause = data.root_cause
        if data.remediation is not None:
            model.remediation = data.remediation
        if data.prevention is not None:
            model.prevention = data.prevention

        model.updated_at = now

        try:
            updated = self.repo.update(model)
        except Exception as e:
            logger.error(
                "Failed to update incident",
                extra={"event": "DATABASE_ERROR", "incident_id": incident_id, "error": str(e)},
            )
            raise DatabaseError("Failed to update incident.") from e

        return updated
