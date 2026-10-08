"""API tests for service request endpoints."""

import pytest

from app.domain.enums import RequestStatus


@pytest.mark.api
class TestCreateRequest:
    def test_create_request_success(self, client, sample_request_data):
        response = client.post("/api/v1/requests", json=sample_request_data)
        assert response.status_code == 201
        data = response.json()
        assert data["request_id"].startswith("REQ-")
        assert data["status"] == RequestStatus.RECEIVED.value
        assert data["customer_id"] == sample_request_data["customer_id"]

    def test_create_request_missing_fields(self, client, sample_request_data):
        # Missing customer_id
        response = client.post(
            "/api/v1/requests",
            json={
                "request_type": "SERVICE",
                "description": "Test",
            },
        )
        assert response.status_code == 422

    def test_create_request_invalid_customer_id(self, client, sample_request_data):
        response = client.post(
            "/api/v1/requests",
            json={
                **sample_request_data,
                "customer_id": "INVALID",
            },
        )
        assert response.status_code == 422

    def test_create_request_invalid_type(self, client, sample_request_data):
        response = client.post(
            "/api/v1/requests",
            json={
                **sample_request_data,
                "request_type": "INVALID",
            },
        )
        assert response.status_code == 422


@pytest.mark.api
class TestGetRequest:
    def test_get_request_success(self, client, sample_request_data):
        # Create first
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        request_id = create_resp.json()["request_id"]

        # Get it
        response = client.get(f"/api/v1/requests/{request_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["request_id"] == request_id

    def test_get_request_not_found(self, client):
        response = client.get("/api/v1/requests/REQ-000000")
        assert response.status_code == 404


@pytest.mark.api
class TestListRequests:
    def test_list_requests_empty(self, client):
        response = client.get("/api/v1/requests")
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 0
        assert data["items"] == []

    def test_list_requests_with_items(self, client, sample_request_data):
        # Create a few requests
        for i in range(3):
            client.post("/api/v1/requests", json={**sample_request_data})

        response = client.get("/api/v1/requests")
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 3
        assert len(data["items"]) == 3


@pytest.mark.api
class TestUpdateStatus:
    def test_update_status_success(self, client, sample_request_data):
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        request_id = create_resp.json()["request_id"]

        response = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "PROCESSING"},
        )
        assert response.status_code == 200
        assert response.json()["status"] == "PROCESSING"

    def test_update_status_invalid_transition(self, client, sample_request_data):
        create_resp = client.post("/api/v1/requests", json=sample_request_data)
        request_id = create_resp.json()["request_id"]

        # Try invalid transition: RECEIVED -> COMPLETED
        response = client.patch(
            f"/api/v1/requests/{request_id}/status",
            json={"status": "COMPLETED"},
        )
        assert response.status_code == 409

    def test_update_status_not_found(self, client):
        response = client.patch(
            "/api/v1/requests/REQ-000000/status",
            json={"status": "PROCESSING"},
        )
        assert response.status_code == 404
