"""Service request domain logic — state machine and validation rules."""

from app.core.errors import InvalidStateTransitionError
from app.domain.enums import RequestStatus

# Valid state transitions: {current_status: {allowed_target_statuses}}
REQUEST_TRANSITIONS: dict[RequestStatus, set[RequestStatus]] = {
    RequestStatus.RECEIVED: {RequestStatus.PROCESSING},
    RequestStatus.PROCESSING: {RequestStatus.COMPLETED, RequestStatus.FAILED},
    RequestStatus.COMPLETED: set(),
    RequestStatus.FAILED: set(),
}


def validate_request_transition(current: RequestStatus, target: RequestStatus) -> None:
    """Raise InvalidStateTransitionError if the transition is not allowed."""
    allowed = REQUEST_TRANSITIONS.get(current, set())
    if target not in allowed:
        raise InvalidStateTransitionError(current.value, target.value)
