"""Processing service with controlled failure simulation.

Simulates request processing. The failure simulation mechanism is gated
behind BOTH APP_ENV=development AND FAILURE_SIMULATION_ENABLED=true.
"""

import random
import time

from app.core.config import get_settings
from app.core.errors import FailureSimulationError, ProcessingError
from app.core.logging import get_logger
from app.core.metrics import metrics

logger = get_logger("processing_service")


class ProcessingService:
    """Handles the work of processing a service request.

    In a real system this would invoke downstream services, apply business rules, etc.
    Here it provides a measurable processing step with optional failure simulation.
    """

    def __init__(self):
        self.settings = get_settings()

    def process(self, request_id: str) -> dict:
        """Process a request. Returns a result dict with timing info.

        Raises ProcessingError or FailureSimulationError on failure.
        """
        logger.info(
            "Processing started",
            extra={"event": "PROCESSING_STARTED", "request_id": request_id},
        )

        start = time.perf_counter()

        try:
            # Check for simulated failures (development only)
            if self.settings.is_failure_simulation_active:
                self._check_simulated_failure(request_id)

            # Simulate actual processing work
            self._do_processing(request_id)

            elapsed_ms = (time.perf_counter() - start) * 1000
            metrics.observe("request_processing_duration", elapsed_ms)

            logger.info(
                "Processing completed",
                extra={
                    "event": "PROCESSING_COMPLETED",
                    "request_id": request_id,
                    "duration_ms": round(elapsed_ms, 2),
                },
            )
            return {"request_id": request_id, "duration_ms": round(elapsed_ms, 2)}

        except (ProcessingError, FailureSimulationError):
            raise
        except Exception as e:
            elapsed_ms = (time.perf_counter() - start) * 1000
            logger.error(
                "Processing failed unexpectedly",
                extra={
                    "event": "PROCESSING_FAILED",
                    "request_id": request_id,
                    "duration_ms": round(elapsed_ms, 2),
                    "error": str(e),
                },
            )
            raise ProcessingError(f"Processing failed for {request_id}: {e}") from e

    def _do_processing(self, request_id: str) -> None:
        """Simulate processing work. Intentionally simple baseline for Project 3 comparison."""
        # Small sleep to make duration measurable
        time.sleep(0.01)

    def _check_simulated_failure(self, request_id: str) -> None:
        """DEVELOPMENT ONLY — controlled failure injection.

        This method is never reachable unless both:
        - APP_ENV=development
        - FAILURE_SIMULATION_ENABLED=true
        """
        # 30% chance of simulated processing failure (simulation only)
        if random.random() < 0.3:  # nosec B311
            logger.warning(
                "SIMULATED FAILURE — DEVELOPMENT ENVIRONMENT",
                extra={
                    "event": "SIMULATED_FAILURE",
                    "request_id": request_id,
                    "simulation_type": "processing_failure",
                },
            )
            raise FailureSimulationError(
                f"Simulated processing failure for {request_id} "
                f"[SIMULATED — DEVELOPMENT ENVIRONMENT]"
            )
