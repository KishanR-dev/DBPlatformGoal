"""Repository for ServiceRequest persistence.

All database access for service requests is isolated here.
"""

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import ServiceRequestModel


class RequestRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, model: ServiceRequestModel) -> ServiceRequestModel:
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return model

    def get_by_request_id(self, request_id: str) -> ServiceRequestModel | None:
        return (
            self.db.query(ServiceRequestModel)
            .filter(ServiceRequestModel.request_id == request_id)
            .first()
        )

    def list_requests(self, skip: int = 0, limit: int = 20) -> list[ServiceRequestModel]:
        return (
            self.db.query(ServiceRequestModel)
            .order_by(ServiceRequestModel.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def count(self) -> int:
        return self.db.query(func.count(ServiceRequestModel.id)).scalar() or 0

    def count_by_status(self, status: str) -> int:
        return (
            self.db.query(func.count(ServiceRequestModel.id))
            .filter(ServiceRequestModel.status == status)
            .scalar()
            or 0
        )

    def update(self, model: ServiceRequestModel) -> ServiceRequestModel:
        self.db.commit()
        self.db.refresh(model)
        return model
