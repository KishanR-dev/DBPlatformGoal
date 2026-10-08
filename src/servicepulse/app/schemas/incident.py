"""Pydantic schemas for incident API input/output."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.domain.enums import IncidentSeverity, IncidentStatus
from app.schemas.common import PaginatedResponse

# -- Input schemas --


class CreateIncidentSchema(BaseModel):
    """Input for creating a new incident."""

    title: str = Field(..., min_length=1, max_length=200, description="Incident title")
    description: str = Field(..., min_length=1, max_length=2000, description="Detailed description")
    severity: IncidentSeverity = Field(..., description="Incident severity")
    affected_service: str | None = Field(None, max_length=100, description="Affected service name")
    related_request_id: str | None = Field(None, max_length=20, description="Related request ID")


class UpdateIncidentSchema(BaseModel):
    """Partial update for an incident."""

    status: IncidentStatus | None = Field(None, description="Target status")
    root_cause: str | None = Field(None, max_length=5000, description="Root cause analysis")
    remediation: str | None = Field(None, max_length=5000, description="Remediation steps taken")
    prevention: str | None = Field(None, max_length=5000, description="Prevention measures")


# -- Output schemas --


class IncidentResponse(BaseModel):
    """Full incident response."""

    incident_id: str
    title: str
    description: str
    severity: str
    status: str
    affected_service: str | None = None
    related_request_id: str | None = None
    detected_at: datetime
    resolved_at: datetime | None = None
    root_cause: str | None = None
    remediation: str | None = None
    prevention: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class IncidentListResponse(PaginatedResponse):
    """Paginated list of incidents."""

    items: list[IncidentResponse]
