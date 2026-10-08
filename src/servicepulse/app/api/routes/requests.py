"""Service request API routes.

Route handlers delegate to the service layer — no business logic here.
"""

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_request_service
from app.schemas.request import (
    CreateRequestSchema,
    RequestListResponse,
    RequestResponse,
    UpdateStatusSchema,
)
from app.services.request_service import RequestService

router = APIRouter(prefix="/requests", tags=["Service Requests"])


@router.post(
    "",
    response_model=RequestResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a service request",
    description="Submit a new customer service request. Returns a unique request ID.",
    responses={422: {"description": "Validation error"}},
)
def create_request(
    data: CreateRequestSchema,
    service: RequestService = Depends(get_request_service),
) -> RequestResponse:
    model = service.create_request(data)
    return RequestResponse.model_validate(model)


@router.get(
    "/{request_id}",
    response_model=RequestResponse,
    summary="Retrieve a service request",
    description="Get full details of a service request by its ID.",
    responses={404: {"description": "Request not found"}},
)
def get_request(
    request_id: str,
    service: RequestService = Depends(get_request_service),
) -> RequestResponse:
    model = service.get_request(request_id)
    return RequestResponse.model_validate(model)


@router.get(
    "",
    response_model=RequestListResponse,
    summary="List service requests",
    description="Paginated list of service requests, ordered by most recent first.",
)
def list_requests(
    skip: int = Query(0, ge=0, description="Records to skip"),
    limit: int = Query(20, ge=1, le=100, description="Records to return"),
    service: RequestService = Depends(get_request_service),
) -> RequestListResponse:
    items, total = service.list_requests(skip=skip, limit=limit)
    return RequestListResponse(
        items=[RequestResponse.model_validate(i) for i in items],
        total=total,
        skip=skip,
        limit=limit,
    )


@router.patch(
    "/{request_id}/status",
    response_model=RequestResponse,
    summary="Update request status",
    description="Transition a request to a new status. Only valid transitions are accepted.",
    responses={
        404: {"description": "Request not found"},
        409: {"description": "Invalid state transition"},
    },
)
def update_request_status(
    request_id: str,
    data: UpdateStatusSchema,
    service: RequestService = Depends(get_request_service),
) -> RequestResponse:
    model = service.update_status(
        request_id=request_id,
        target_status=data.status,
        failure_reason=data.failure_reason,
    )
    return RequestResponse.model_validate(model)
