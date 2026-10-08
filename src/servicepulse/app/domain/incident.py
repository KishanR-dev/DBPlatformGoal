"""Incident domain logic — state machine and validation rules."""

from app.core.errors import InvalidStateTransitionError
from app.domain.enums import IncidentStatus

INCIDENT_TRANSITIONS: dict[IncidentStatus, set[IncidentStatus]] = {
    IncidentStatus.OPEN: {IncidentStatus.INVESTIGATING},
    IncidentStatus.INVESTIGATING: {IncidentStatus.MITIGATED},
    IncidentStatus.MITIGATED: {IncidentStatus.RESOLVED},
    IncidentStatus.RESOLVED: set(),
}


def validate_incident_transition(current: IncidentStatus, target: IncidentStatus) -> None:
    """Raise InvalidStateTransitionError if the transition is not allowed."""
    allowed = INCIDENT_TRANSITIONS.get(current, set())
    if target not in allowed:
        raise InvalidStateTransitionError(current.value, target.value)
