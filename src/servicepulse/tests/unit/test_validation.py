"""Unit tests for input validation schemas."""

import pytest

from app.domain.enums import IncidentSeverity, IncidentStatus
from app.schemas.incident import CreateIncidentSchema, UpdateIncidentSchema
from app.schemas.request import CreateRequestSchema


@pytest.mark.unit
class TestCreateRequestValidation:
    def test_valid_request(self):
        data = CreateRequestSchema(
            customer_id="CUST-001",
            request_type="SERVICE",
            description="Test request",
        )
        assert data.customer_id == "CUST-001"

    def test_invalid_customer_id_pattern(self):
        with pytest.raises(ValueError):
            CreateRequestSchema(
                customer_id="INVALID",
                request_type="SERVICE",
                description="Test",
            )

    def test_invalid_customer_id_too_short(self):
        with pytest.raises(ValueError):
            CreateRequestSchema(
                customer_id="CUST-1",
                request_type="SERVICE",
                description="Test",
            )

    def test_empty_description(self):
        with pytest.raises(ValueError):
            CreateRequestSchema(
                customer_id="CUST-001",
                request_type="SERVICE",
                description="",
            )

    def test_description_too_long(self):
        with pytest.raises(ValueError):
            CreateRequestSchema(
                customer_id="CUST-001",
                request_type="SERVICE",
                description="x" * 1001,
            )

    def test_valid_request_type(self):
        for rt in ["SERVICE", "INQUIRY", "COMPLAINT"]:
            data = CreateRequestSchema(
                customer_id="CUST-001",
                request_type=rt,
                description="Test",
            )
            assert data.request_type.value == rt

    def test_invalid_request_type(self):
        with pytest.raises(ValueError):
            CreateRequestSchema(
                customer_id="CUST-001",
                request_type="INVALID",
                description="Test",
            )


@pytest.mark.unit
class TestCreateIncidentValidation:
    def test_valid_incident(self):
        data = CreateIncidentSchema(
            title="Database Latency Spike",
            description="High latency on SQL queries",
            severity=IncidentSeverity.HIGH,
            affected_service="database",
        )
        assert data.title == "Database Latency Spike"
        assert data.severity == IncidentSeverity.HIGH

    def test_empty_title(self):
        with pytest.raises(ValueError):
            CreateIncidentSchema(
                title="",
                description="High latency on SQL queries",
                severity=IncidentSeverity.HIGH,
            )

    def test_title_too_long(self):
        with pytest.raises(ValueError):
            CreateIncidentSchema(
                title="x" * 201,
                description="High latency on SQL queries",
                severity=IncidentSeverity.HIGH,
            )

    def test_empty_description(self):
        with pytest.raises(ValueError):
            CreateIncidentSchema(
                title="Incident",
                description="",
                severity=IncidentSeverity.HIGH,
            )

    def test_invalid_severity(self):
        with pytest.raises(ValueError):
            CreateIncidentSchema(
                title="Incident",
                description="Description",
                severity="CRITICAL_EXTREME",  # Invalid enum
            )


@pytest.mark.unit
class TestUpdateIncidentValidation:
    def test_valid_status_update(self):
        data = UpdateIncidentSchema(
            status=IncidentStatus.INVESTIGATING,
            root_cause="Connection pool exhaustion",
            remediation="Increased max pool size to 50",
            prevention="Add connection pool saturation alert",
        )
        assert data.status == IncidentStatus.INVESTIGATING
        assert data.root_cause == "Connection pool exhaustion"

    def test_invalid_status(self):
        with pytest.raises(ValueError):
            UpdateIncidentSchema(status="NOT_A_STATUS")
