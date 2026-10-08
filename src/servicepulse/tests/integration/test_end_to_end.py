"""End-to-end integration tests for the request lifecycle."""

import pytest

from app.domain.enums import RequestStatus


@pytest.mark.integration
class TestRequestLifecycle:
    """Test complete request lifecycle from creation to completion."""

    def test_full_lifecycle(self, client, sample_request_data):
        # 1. Create request
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        assert create_resp.status_code == 201
        request_id = create_resp.json()["request_id"]

        # 2. Retrieve request
        get_resp = client.get(f"/api/v1/requests/{request_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["status"] == RequestStatus.RECEIVED.value

        # 3. Update to processing
        update_resp = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "PROCESSING"},
        )
        assert update_resp.status_code == 200
        assert update_resp.json()["status"] == RequestStatus.PROCESSING.value

        # 4. Complete the request
        complete_resp = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "COMPLETED"},
        )
        assert complete_resp.status_code == 200
        assert complete_resp.json()["status"] == RequestStatus.COMPLETED.value

        # Verify completed_at timestamp exists
        final = client.get(f"/api/v1/requests/{request_id}")
        assert final.json()["completed_at"] is not None

    def test_failure_path(self, client, sample_request_data):
        # Create
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        request_id = create_resp.json()["request_id"]

        # First transition to PROCESSING
        client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "PROCESSING"},
        )

        # Now fail it
        fail_resp = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "FAILED", "failure_reason": "Connection timeout"},
        )
        assert fail_resp.status_code == 200
        data = fail_resp.json()
        assert data["status"] == RequestStatus.FAILED.value
        assert data["failure_reason"] == "Connection timeout"


@pytest.mark.integration
class TestIncidentLifecycle:
    """Test incident creation and resolution."""

    def test_full_incident_workflow(self, client, sample_incident_data):
        # 1. Create incident
        create_resp = client.post("/api/v1/incidents", json=sample_incident_data)
        assert create_resp.status_code == 201
        incident_id = create_resp.json()["incident_id"]

        # 2. Investigate
        update_resp = client.patch(
            f"/api/v1/incidents/{incident_id}",
            json={"status": "INVESTIGATING"},
        )
        assert update_resp.status_code == 200

        # 3. Mitigate
        mitigate_resp = client.patch(
            f"/api/v1/incidents/{incident_id}",
            json={"status": "MITIGATED", "remediation": "Restarted service"},
        )
        assert mitigate_resp.status_code == 200

        # 4. Resolve with RCA
        resolve_resp = client.patch(
            f"/api/v1/incidents/{incident_id}",
            json={
                "status": "RESOLVED",
                "root_cause": "Connection pool exhausted",
                "prevention": "Added connection timeout and pool monitoring",
            },
        )
        assert resolve_resp.status_code == 200
        data = resolve_resp.json()
        assert data["status"] == "RESOLVED"
        assert data["root_cause"] == "Connection pool exhausted"
