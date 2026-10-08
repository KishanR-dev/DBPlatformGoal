"""Pydantic schemas for service request API input/output."""

from __future__ import annotations

import re
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.domain.enums import RequestStatus, RequestType
from app.schemas.common import PaginatedResponse

# -- Input schemas --


class CreateRequestSchema(BaseModel):
    """Input for creating a new service request."""

    customer_id: str = Field(
        ...,
        min_length=5,
        max_length=50,
        description="Customer identifier (format: CUST-XXX)",
        examples=["CUST-001"],
    )
    request_type: RequestType = Field(
        ...,
        description="Type of service request",
        examples=["SERVICE"],
    )
    description: str = Field(
        ...,
        min_length=1,
        max_length=1000,
        description="Description of the service request",
        examples=["Unable to access account"],
    )

    @field_validator("customer_id")
    @classmethod
    def validate_customer_id(cls, v: str) -> str:
        if not re.match(r"^CUST-\d{3,}$", v):
            raise ValueError("customer_id must match pattern CUST-XXX (e.g., CUST-001)")
        return v


class UpdateStatusSchema(BaseModel):
    """Input for updating request status."""

    status: RequestStatus = Field(
        ...,
        description="Target status",
        examples=["PROCESSING"],
    )
    failure_reason: str | None = Field(
        None,
        max_length=500,
        description="Reason for failure (required when transitioning to FAILED)",
    )


# -- Output schemas --


class RequestResponse(BaseModel):
    """Full service request response."""

    request_id: str
    customer_id: str
    request_type: str
    description: str
    status: str
    created_at: datetime
    updated_at: datetime
    processing_started_at: datetime | None = None
    completed_at: datetime | None = None
    failed_at: datetime | None = None
    failure_reason: str | None = None

    model_config = {"from_attributes": True}


class RequestListResponse(PaginatedResponse):
    """Paginated list of service requests."""

    items: list[RequestResponse]
