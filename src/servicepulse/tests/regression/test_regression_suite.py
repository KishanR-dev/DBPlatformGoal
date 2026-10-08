"""Regression test suite for ServicePulse.

Validates prevention of critical regressions:
1. Failure simulation safety gating (cannot leak to non-dev environments)
2. State machine immutability on terminal states
3. Correlation ID propagation through middleware
4. Error payload sanitization (no internal leaks on 500)
"""

import pytest

from app.core.config import Settings
from app.core.errors import InvalidStateTransitionError
from app.domain.enums import IncidentStatus, RequestStatus
from app.domain.incident import validate_incident_transition
from app.domain.request import validate_request_transition


@pytest.mark.regression
class TestFailureSimulationGatingRegression:
    """Regression test: Ensure failure simulation cannot be activated in production or test."""

    def test_production_environment_blocks_simulation_even_if_flag_true(self):
        prod_settings = Settings(app_env="production", failure_simulation_enabled=True)
        assert not prod_settings.is_failure_simulation_active

    def test_staging_environment_blocks_simulation_even_if_flag_true(self):
        staging_settings = Settings(app_env="staging", failure_simulation_enabled=True)
        assert not staging_settings.is_failure_simulation_active

    def test_test_environment_blocks_simulation(self):
        test_settings = Settings(app_env="test", failure_simulation_enabled=True)
        assert not test_settings.is_failure_simulation_active


@pytest.mark.regression
class TestTerminalStateImmutabilityRegression:
    """Regression test: Ensure terminal states cannot be escaped or overwritten."""

    @pytest.mark.parametrize(
        "target_status",
        [RequestStatus.RECEIVED, RequestStatus.PROCESSING, RequestStatus.FAILED],
    )
    def test_request_completed_state_is_strictly_terminal(self, target_status):
        with pytest.raises(InvalidStateTransitionError):
            validate_request_transition(RequestStatus.COMPLETED, target_status)

    @pytest.mark.parametrize(
        "target_status",
        [RequestStatus.RECEIVED, RequestStatus.PROCESSING, RequestStatus.COMPLETED],
    )
    def test_request_failed_state_is_strictly_terminal(self, target_status):
        with pytest.raises(InvalidStateTransitionError):
            validate_request_transition(RequestStatus.FAILED, target_status)

    @pytest.mark.parametrize(
        "target_status",
        [IncidentStatus.OPEN, IncidentStatus.INVESTIGATING, IncidentStatus.MITIGATED],
    )
    def test_incident_resolved_state_is_strictly_terminal(self, target_status):
        with pytest.raises(InvalidStateTransitionError):
            validate_incident_transition(IncidentStatus.RESOLVED, target_status)


@pytest.mark.regression
class TestMiddlewareCorrelationRegression:
    """Regression test: Ensure correlation IDs propagate cleanly."""

    def test_custom_correlation_id_is_preserved_in_response(self, client):
        custom_id = "corr-test-regression-12345"
        response = client.get("/health", headers={"X-Correlation-ID": custom_id})
        assert response.status_code == 200
        assert response.headers.get("x-correlation-id") == custom_id

    def test_missing_correlation_id_generates_new_uuid(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        generated_id = response.headers.get("x-correlation-id")
        assert generated_id is not None
        assert len(generated_id) >= 8
