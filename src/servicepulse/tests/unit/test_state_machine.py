"""Unit tests for state machine validation."""

import pytest

from app.domain.enums import IncidentStatus, RequestStatus
from app.domain.incident import validate_incident_transition
from app.domain.request import InvalidStateTransitionError, validate_request_transition


@pytest.mark.unit
class TestRequestStateMachine:
    """Tests for service request state transitions."""

    def test_valid_received_to_processing(self):
        validate_request_transition(RequestStatus.RECEIVED, RequestStatus.PROCESSING)

    def test_valid_processing_to_completed(self):
        validate_request_transition(RequestStatus.PROCESSING, RequestStatus.COMPLETED)

    def test_valid_processing_to_failed(self):
        validate_request_transition(RequestStatus.PROCESSING, RequestStatus.FAILED)

    def test_invalid_completed_to_processing(self):
        with pytest.raises(InvalidStateTransitionError):
            validate_request_transition(RequestStatus.COMPLETED, RequestStatus.PROCESSING)

    def test_invalid_failed_to_completed(self):
        with pytest.raises(InvalidStateTransitionError):
            validate_request_transition(RequestStatus.FAILED, RequestStatus.COMPLETED)

    def test_invalid_received_to_completed(self):
        with pytest.raises(InvalidStateTransitionError):
            validate_request_transition(RequestStatus.RECEIVED, RequestStatus.COMPLETED)

    def test_invalid_received_to_failed(self):
        with pytest.raises(InvalidStateTransitionError):
            validate_request_transition(RequestStatus.RECEIVED, RequestStatus.FAILED)

    def test_no_transitions_from_completed(self):
        for target in RequestStatus:
            if target != RequestStatus.COMPLETED:
                with pytest.raises(InvalidStateTransitionError):
                    validate_request_transition(RequestStatus.COMPLETED, target)

    def test_no_transitions_from_failed(self):
        for target in RequestStatus:
            if target != RequestStatus.FAILED:
                with pytest.raises(InvalidStateTransitionError):
                    validate_request_transition(RequestStatus.FAILED, target)


@pytest.mark.unit
class TestIncidentStateMachine:
    """Tests for incident state transitions."""

    def test_valid_open_to_investigating(self):
        validate_incident_transition(IncidentStatus.OPEN, IncidentStatus.INVESTIGATING)

    def test_valid_investigating_to_mitigated(self):
        validate_incident_transition(IncidentStatus.INVESTIGATING, IncidentStatus.MITIGATED)

    def test_valid_mitigated_to_resolved(self):
        validate_incident_transition(IncidentStatus.MITIGATED, IncidentStatus.RESOLVED)

    def test_invalid_resolved_to_mitigated(self):
        with pytest.raises(InvalidStateTransitionError):
            validate_incident_transition(IncidentStatus.RESOLVED, IncidentStatus.MITIGATED)

    def test_no_transitions_from_resolved(self):
        for target in IncidentStatus:
            if target != IncidentStatus.RESOLVED:
                with pytest.raises(InvalidStateTransitionError):
                    validate_incident_transition(IncidentStatus.RESOLVED, target)
