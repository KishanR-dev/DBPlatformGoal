"""API tests for health endpoint."""

import pytest


@pytest.mark.api
class TestHealthCheck:
    def test_health_success(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "application" in data["components"]
        assert "database" in data["components"]

    def test_health_endpoint_exists(self, client):
        """Verify health endpoint is accessible and returns expected structure."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "version" in data
        assert "components" in data
        assert "application" in data["components"]
        assert "database" in data["components"]
        # Database should be healthy in test environment
        assert data["components"]["database"] == "healthy"
