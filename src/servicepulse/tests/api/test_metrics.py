"""API tests for metrics endpoint."""

import pytest


@pytest.mark.api
class TestMetrics:
    def test_metrics_endpoint_returns_text(self, client):
        # Trigger an endpoint to record request metrics
        client.get("/health")
        response = client.get("/api/v1/metrics")
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]
        content = response.text
        assert "http_requests_total" in content

    def test_metrics_json_endpoint(self, client):
        response = client.get("/api/v1/metrics/json")
        assert response.status_code == 200
        data = response.json()
        assert "counters" in data
        assert "gauges" in data
