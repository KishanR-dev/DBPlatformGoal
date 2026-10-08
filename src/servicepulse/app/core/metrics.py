"""Application metrics collection.

Provides simple in-process counters and gauges. Exposes a Prometheus-compatible
text endpoint. No external dependencies required — designed so a future
Prometheus client library can replace this without changing the rest of the app.
"""

from __future__ import annotations

import threading
import time
from collections import defaultdict
from collections.abc import Generator
from contextlib import contextmanager


class MetricsCollector:
    """Thread-safe in-process metrics store."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._counters: dict[str, float] = defaultdict(float)
        self._gauges: dict[str, float] = defaultdict(float)
        self._histograms: dict[str, list[float]] = defaultdict(list)

    # -- Counters --

    def increment(self, name: str, value: float = 1, labels: dict | None = None) -> None:
        key = self._key(name, labels)
        with self._lock:
            self._counters[key] += value

    def counter_value(self, name: str, labels: dict | None = None) -> float:
        key = self._key(name, labels)
        with self._lock:
            return self._counters[key]

    # -- Gauges --

    def set_gauge(self, name: str, value: float, labels: dict | None = None) -> None:
        key = self._key(name, labels)
        with self._lock:
            self._gauges[key] = value

    def increment_gauge(self, name: str, value: float = 1, labels: dict | None = None) -> None:
        key = self._key(name, labels)
        with self._lock:
            self._gauges[key] += value

    def gauge_value(self, name: str, labels: dict | None = None) -> float:
        key = self._key(name, labels)
        with self._lock:
            return self._gauges[key]

    # -- Histograms (simple list-based for duration tracking) --

    def observe(self, name: str, value: float, labels: dict | None = None) -> None:
        key = self._key(name, labels)
        with self._lock:
            self._histograms[key].append(value)

    @contextmanager
    def timer(self, name: str, labels: dict | None = None) -> Generator[None, None, None]:
        start = time.perf_counter()
        yield
        elapsed = (time.perf_counter() - start) * 1000  # milliseconds
        self.observe(name, elapsed, labels)

    # -- Export (Prometheus text format) --

    def to_prometheus(self) -> str:
        lines: list[str] = []
        with self._lock:
            for key, val in sorted(self._counters.items()):
                name, label_str = self._parse_key(key)
                lines.append(f"# TYPE {name} counter")
                lines.append(f"{name}{label_str} {val}")
            for key, val in sorted(self._gauges.items()):
                name, label_str = self._parse_key(key)
                lines.append(f"# TYPE {name} gauge")
                lines.append(f"{name}{label_str} {val}")
            for key, values in sorted(self._histograms.items()):
                name, label_str = self._parse_key(key)
                count = len(values)
                total = sum(values)
                avg = total / count if count else 0
                lines.append(f"# TYPE {name} summary")
                lines.append(f"{name}_count{label_str} {count}")
                lines.append(f"{name}_sum{label_str} {total:.2f}")
                lines.append(f"{name}_avg{label_str} {avg:.2f}")
        return "\n".join(lines) + "\n"

    # -- Reset --

    def reset(self) -> None:
        """Clear all in-memory metrics. Used for test isolation and state reset."""
        with self._lock:
            self._counters.clear()
            self._gauges.clear()
            self._histograms.clear()

    # -- Snapshot for JSON endpoint --

    def snapshot(self) -> dict:
        with self._lock:
            return {
                "counters": dict(self._counters),
                "gauges": dict(self._gauges),
                "histograms": {
                    k: {"count": len(v), "sum": sum(v), "avg": sum(v) / len(v) if v else 0}
                    for k, v in self._histograms.items()
                },
            }

    # -- Internal helpers --

    @staticmethod
    def _key(name: str, labels: dict | None) -> str:
        if not labels:
            return name
        label_parts = ",".join(f'{k}="{v}"' for k, v in sorted(labels.items()))
        return f"{name}{{{label_parts}}}"

    @staticmethod
    def _parse_key(key: str) -> tuple[str, str]:
        if "{" in key:
            name, rest = key.split("{", 1)
            return name, "{" + rest
        return key, ""


# Module-level singleton
metrics = MetricsCollector()
