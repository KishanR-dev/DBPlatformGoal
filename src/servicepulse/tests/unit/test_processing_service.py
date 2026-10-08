"""Unit tests for the processing service and failure simulation mechanics."""

from unittest.mock import MagicMock, patch

import pytest

from app.core.errors import FailureSimulationError, ProcessingError
from app.services.processing_service import ProcessingService


@pytest.mark.unit
class TestProcessingService:
    """Unit tests for ProcessingService."""

    def test_process_success_normal_flow(self):
        service = ProcessingService()
        result = service.process("REQ-TEST-001")

        assert result["request_id"] == "REQ-TEST-001"
        assert "duration_ms" in result
        assert result["duration_ms"] >= 0

    def test_failure_simulation_not_active_by_default(self):
        service = ProcessingService()
        assert not service.settings.is_failure_simulation_active

        # Even with mocked random returning 0.1 (below 0.3 threshold), no failure should trigger
        with patch("random.random", return_value=0.1):
            result = service.process("REQ-TEST-002")
            assert result["request_id"] == "REQ-TEST-002"

    def test_failure_simulation_active_triggers_failure(self):
        service = ProcessingService()

        # Mock settings to have failure simulation active
        mock_settings = MagicMock()
        mock_settings.is_failure_simulation_active = True
        service.settings = mock_settings

        # When random is below 0.3, it should raise FailureSimulationError
        with patch("random.random", return_value=0.1):
            with pytest.raises(FailureSimulationError) as exc_info:
                service.process("REQ-TEST-003")
            assert "Simulated processing failure" in str(exc_info.value)
            assert "REQ-TEST-003" in str(exc_info.value)

    def test_failure_simulation_active_passes_when_random_above_threshold(self):
        service = ProcessingService()

        mock_settings = MagicMock()
        mock_settings.is_failure_simulation_active = True
        service.settings = mock_settings

        # When random is >= 0.3, it should succeed
        with patch("random.random", return_value=0.5):
            result = service.process("REQ-TEST-004")
            assert result["request_id"] == "REQ-TEST-004"

    def test_unexpected_exception_wrapped_in_processing_error(self):
        service = ProcessingService()

        with patch.object(service, "_do_processing", side_effect=RuntimeError("Hardware fault")):
            with pytest.raises(ProcessingError) as exc_info:
                service.process("REQ-TEST-005")
            assert "Processing failed for REQ-TEST-005: Hardware fault" in str(exc_info.value)
