"""Incident management API routes."""

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_incident_service
from app.schemas.incident import (
    CreateIncidentSchema,
    IncidentListResponse,
    IncidentResponse,
    UpdateIncidentSchema,
)
from app.services.incident_service import IncidentService

router = APIRouter(prefix="/incidents", tags=["Incidents"])


@router.post(
    "",
    response_model=IncidentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create an incident",
    description="Create a new operational incident for investigation.",
    responses={422: {"description": "Validation error"}},
)
def create_incident(
    data: CreateIncidentSchema,
    service: IncidentService = Depends(get_incident_service),
) -> IncidentResponse:
    model = service.create_incident(data)
    return IncidentResponse.model_validate(model)


@router.get(
    "/{incident_id}",
    response_model=IncidentResponse,
    summary="Retrieve an incident",
    description="Get full details of an incident including RCA fields.",
    responses={404: {"description": "Incident not found"}},
)
def get_incident(
    incident_id: str,
    service: IncidentService = Depends(get_incident_service),
) -> IncidentResponse:
    model = service.get_incident(incident_id)
    return IncidentResponse.model_validate(model)


@router.get(
    "",
    response_model=IncidentListResponse,
    summary="List incidents",
    description="Paginated list of incidents, ordered by most recent first.",
)
def list_incidents(
    skip: int = Query(0, ge=0, description="Records to skip"),
    limit: int = Query(20, ge=1, le=100, description="Records to return"),
    service: IncidentService = Depends(get_incident_service),
) -> IncidentListResponse:
    items, total = service.list_incidents(skip=skip, limit=limit)
    return IncidentListResponse(
        items=[IncidentResponse.model_validate(i) for i in items],
        total=total,
        skip=skip,
        limit=limit,
    )


@router.patch(
    "/{incident_id}",
    response_model=IncidentResponse,
    summary="Update an incident",
    description="Update incident status, root cause, remediation, or prevention fields.",
    responses={
        404: {"description": "Incident not found"},
        409: {"description": "Invalid state transition"},
    },
)
def update_incident(
    incident_id: str,
    data: UpdateIncidentSchema,
    service: IncidentService = Depends(get_incident_service),
) -> IncidentResponse:
    model = service.update_incident(incident_id, data)
    return IncidentResponse.model_validate(model)
