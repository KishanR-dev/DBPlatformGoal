"""Service layer for request lifecycle operations.

Orchestrates domain logic, persistence, logging, and metrics.
Business logic lives here — not in route handlers or repositories.
"""

import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.errors import DatabaseError, NotFoundError
from app.core.logging import get_logger
from app.core.metrics import metrics
from app.db.models import ServiceRequestModel
from app.domain.enums import RequestStatus
from app.domain.request import validate_request_transition
from app.repositories.request_repository import RequestRepository
from app.schemas.request import CreateRequestSchema

logger = get_logger("request_service")


class RequestService:
    def __init__(self, db: Session):
        self.repo = RequestRepository(db)

    def create_request(self, data: CreateRequestSchema) -> ServiceRequestModel:
        """Create a new service request with status RECEIVED."""
        request_id = f"REQ-{uuid.uuid4().hex[:8].upper()}"

        model = ServiceRequestModel(
            request_id=request_id,
            customer_id=data.customer_id,
            request_type=data.request_type.value,
            description=data.description,
            status=RequestStatus.RECEIVED.value,
        )

        try:
            created = self.repo.create(model)
        except Exception as e:
            logger.error(
                "Failed to create request",
                extra={"event": "DATABASE_ERROR", "error": str(e)},
            )
            raise DatabaseError("Failed to persist service request.") from e

        metrics.increment("requests_total")
        metrics.increment("requests_by_status", labels={"status": RequestStatus.RECEIVED.value})
        logger.info(
            "Service request created",
            extra={
                "event": "REQUEST_CREATED",
                "request_id": request_id,
                "customer_id": data.customer_id,
                "request_type": data.request_type.value,
            },
        )
        return created

    def get_request(self, request_id: str) -> ServiceRequestModel:
        """Retrieve a request by its business ID. Raises NotFoundError if missing."""
        model = self.repo.get_by_request_id(request_id)
        if not model:
            raise NotFoundError("request", request_id)
        return model

    def list_requests(
        self, skip: int = 0, limit: int = 20
    ) -> tuple[list[ServiceRequestModel], int]:
        """Return a paginated list of requests and total count."""
        items = self.repo.list_requests(skip=skip, limit=limit)
        total = self.repo.count()
        return items, total

    def update_status(
        self,
        request_id: str,
        target_status: RequestStatus,
        failure_reason: str | None = None,
    ) -> ServiceRequestModel:
        """Transition a request to a new status. Validates the state machine."""
        model = self.get_request(request_id)
        current = RequestStatus(model.status)

        # Domain validation — raises InvalidStateTransitionError on violation
        validate_request_transition(current, target_status)

        now = datetime.now(UTC)
        old_status = model.status
        model.status = target_status.value
        model.updated_at = now

        if target_status == RequestStatus.PROCESSING:
            model.processing_started_at = now
        elif target_status == RequestStatus.COMPLETED:
            model.completed_at = now
            metrics.increment("requests_success_total")
        elif target_status == RequestStatus.FAILED:
            model.failed_at = now
            model.failure_reason = failure_reason
            metrics.increment("requests_failed_total")

        try:
            updated = self.repo.update(model)
        except Exception as e:
            logger.error(
                "Failed to update request status",
                extra={"event": "DATABASE_ERROR", "request_id": request_id, "error": str(e)},
            )
            raise DatabaseError("Failed to update request status.") from e

        # Adjust status gauge
        metrics.increment_gauge("requests_by_status", -1, labels={"status": old_status})
        metrics.increment_gauge("requests_by_status", 1, labels={"status": target_status.value})

        event_name = {
            RequestStatus.PROCESSING: "REQUEST_PROCESSING_STARTED",
            RequestStatus.COMPLETED: "REQUEST_COMPLETED",
            RequestStatus.FAILED: "REQUEST_FAILED",
        }.get(target_status, "REQUEST_STATUS_CHANGED")

        logger.info(
            f"Request status changed: {old_status} → {target_status.value}",
            extra={
                "event": event_name,
                "request_id": request_id,
                "old_status": old_status,
                "new_status": target_status.value,
            },
        )
        return updated
