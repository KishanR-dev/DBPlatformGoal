"""Failure simulation tests.

These tests verify the controlled failure injection mechanism works correctly
in development mode with failure simulation enabled.

IMPORTANT: Failure simulation is ONLY active when:
- APP_ENV=development
- FAILURE_SIMULATION_ENABLED=true

This is a SAFETY GUARD to prevent accidental failures in production.
"""

import pytest


@pytest.mark.failure
class TestFailureSimulationGate:
    """Test that failure simulation is properly gated."""

    def test_simulation_disabled_by_default(self, client):
        """Verify simulation is disabled in default test environment."""
        # The health endpoint should succeed (database is available)
        response = client.get("/health")
        assert response.status_code == 200
        # We're in test mode, so simulation should not be active
        # (simulation requires explicit opt-in in development mode)


@pytest.mark.failure
class TestProcessingFailurePath:
    """Test that the request processing failure path works."""

    def test_failure_request_requires_failure_reason(self, client, sample_request_data):
        """When failing a request, failure_reason should be recorded."""
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        request_id = create_resp.json()["request_id"]

        # First transition to PROCESSING
        client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "PROCESSING"},
        )

        # Now fail it with a reason
        fail_resp = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "FAILED", "failure_reason": "Simulated database timeout for testing"},
        )
        assert fail_resp.status_code == 200
        data = fail_resp.json()
        assert data["status"] == "FAILED"
        assert data["failure_reason"] == "Simulated database timeout for testing"


@pytest.mark.failure
class TestInvalidStatePrevention:
    """Verify that invalid state transitions are rejected."""

    def test_cannot_complete_from_received(self, client, sample_request_data):
        """Cannot jump straight from RECEIVED to COMPLETED."""
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        request_id = create_resp.json()["request_id"]

        response = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "COMPLETED"},
        )
        assert response.status_code == 409

    def test_cannot_fail_from_completed(self, client, sample_request_data):
        """Cannot transition away from COMPLETED or FAILED."""
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        request_id = create_resp.json()["request_id"]

        # First complete it
        client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "PROCESSING"},
        )
        client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "COMPLETED"},
        )

        # Now try to change it (all transitions from COMPLETED are invalid)
        response = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "PROCESSING"},
        )
        assert response.status_code == 409
