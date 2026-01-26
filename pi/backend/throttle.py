"""Throttle layer for rate-limiting telemetry emissions."""

import time
from typing import Any, Callable


class Throttle:
    """Rate limiter for WebSocket emissions.

    Coalesces rapid updates - only emits at most once per min_interval.
    If multiple updates arrive within the interval, the latest value wins.
    """

    def __init__(self, min_interval: float = 0.5):
        """
        Args:
            min_interval: Minimum seconds between emissions (default 0.5 = 2Hz max)
        """
        self._last_emit: float = 0
        self._min_interval = min_interval
        self._pending: Any = None

    def maybe_emit(self, data: Any, emit_fn: Callable[[Any], None]) -> bool:
        """Emit if interval has passed, otherwise store as pending.

        Args:
            data: Data to emit
            emit_fn: Function to call with data when emitting

        Returns:
            True if emitted, False if stored as pending
        """
        now = time.time()
        if now - self._last_emit >= self._min_interval:
            emit_fn(data)
            self._last_emit = now
            self._pending = None
            return True
        else:
            self._pending = data  # Latest value wins
            return False

    def flush(self, emit_fn: Callable[[Any], None]) -> bool:
        """Emit pending data if any.

        Call this periodically to ensure pending data gets sent.

        Returns:
            True if pending data was emitted, False if nothing pending
        """
        if self._pending is not None:
            emit_fn(self._pending)
            self._last_emit = time.time()
            self._pending = None
            return True
        return False

    @property
    def has_pending(self) -> bool:
        """Check if there's pending data waiting to be emitted."""
        return self._pending is not None
