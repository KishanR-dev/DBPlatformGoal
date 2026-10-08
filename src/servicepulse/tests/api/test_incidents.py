"""API tests for the incident management endpoints."""

import pytest


@pytest.mark.api
class TestCreateIncident:
    """Tests for POST /api/v1/incidents."""

    def test_create_incident_success(self, client, sample_incident_data):
        response = client.post("/api/v1/incidents", json=sample_incident_data)
        assert response.status_code == 201
        data = response.json()
        assert data["incident_id"].startswith("INC-")
        assert data["title"] == sample_incident_data["title"]
        assert data["severity"] == "HIGH"
        assert data["status"] == "OPEN"
        assert data["affected_service"] == "request_processing"

    def test_create_incident_validation_error(self, client):
        response = client.post(
            "/api/v1/incidents",
            json={
                "title": "",  # Empty title
                "description": "Short",
                "severity": "HIGH",
            },
        )
        assert response.status_code == 422


@pytest.mark.api
class TestGetIncident:
    """Tests for GET /api/v1/incidents/{incident_id}."""

    def test_get_incident_success(self, client, sample_incident_data):
        create_res = client.post("/api/v1/incidents", json=sample_incident_data)
        incident_id = create_res.json()["incident_id"]

        response = client.get(f"/api/v1/incidents/{incident_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["incident_id"] == incident_id
        assert data["title"] == sample_incident_data["title"]

    def test_get_incident_not_found(self, client):
        response = client.get("/api/v1/incidents/INC-NONEXISTENT")
        assert response.status_code == 404
        assert response.json()["error"]["code"] == "INCIDENT_NOT_FOUND"


@pytest.mark.api
class TestListIncidents:
    """Tests for GET /api/v1/incidents."""

    def test_list_incidents_empty(self, client):
        response = client.get("/api/v1/incidents")
        assert response.status_code == 200
        data = response.json()
        assert data["items"] == []
        assert data["total"] == 0

    def test_list_incidents_with_items(self, client, sample_incident_data):
        client.post("/api/v1/incidents", json=sample_incident_data)
        client.post(
            "/api/v1/incidents",
            json={
                "title": "Secondary incident",
                "description": "Secondary description",
                "severity": "LOW",
                "affected_service": "api",
            },
        )

        response = client.get("/api/v1/incidents")
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert len(data["items"]) == 2


@pytest.mark.api
class TestUpdateIncident:
    """Tests for PATCH /api/v1/incidents/{incident_id}."""

    def test_update_incident_status_success(self, client, sample_incident_data):
        create_res = client.post("/api/v1/incidents", json=sample_incident_data)
        incident_id = create_res.json()["incident_id"]

        # Transition OPEN -> INVESTIGATING
        response = client.patch(
            f"/api/v1/incidents/{incident_id}",
            json={
                "status": "INVESTIGATING",
                "root_cause": "Database connection pool saturated",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "INVESTIGATING"
        assert data["root_cause"] == "Database connection pool saturated"

    def test_update_incident_invalid_state_transition(self, client, sample_incident_data):
        create_res = client.post("/api/v1/incidents", json=sample_incident_data)
        incident_id = create_res.json()["incident_id"]

        # Invalid transition: OPEN -> RESOLVED (must go through INVESTIGATING/MITIGATED)
        response = client.patch(
            f"/api/v1/incidents/{incident_id}",
            json={"status": "RESOLVED"},
        )
        assert response.status_code == 409
        assert response.json()["error"]["code"] == "INVALID_STATE_TRANSITION"

    def test_update_incident_not_found(self, client):
        response = client.patch(
            "/api/v1/incidents/INC-DOESNOTEXIST",
            json={"status": "INVESTIGATING"},
        )
        assert response.status_code == 404
