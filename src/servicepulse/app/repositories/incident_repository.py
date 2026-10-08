"""Repository for Incident persistence."""

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import IncidentModel


class IncidentRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, model: IncidentModel) -> IncidentModel:
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return model

    def get_by_incident_id(self, incident_id: str) -> IncidentModel | None:
        return self.db.query(IncidentModel).filter(IncidentModel.incident_id == incident_id).first()

    def list_incidents(self, skip: int = 0, limit: int = 20) -> list[IncidentModel]:
        return (
            self.db.query(IncidentModel)
            .order_by(IncidentModel.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def count(self) -> int:
        return self.db.query(func.count(IncidentModel.id)).scalar() or 0

    def count_by_status(self, status: str) -> int:
        return (
            self.db.query(func.count(IncidentModel.id))
            .filter(IncidentModel.status == status)
            .scalar()
            or 0
        )

    def count_open(self) -> int:
        """Count incidents that are not RESOLVED."""
        return (
            self.db.query(func.count(IncidentModel.id))
            .filter(IncidentModel.status != "RESOLVED")
            .scalar()
            or 0
        )

    def update(self, model: IncidentModel) -> IncidentModel:
        self.db.commit()
        self.db.refresh(model)
        return model
