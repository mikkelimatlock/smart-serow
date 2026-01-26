"""GPS service - connects to gpsd, buffers data, handles reconnection."""

import threading
import time
from collections import deque
from typing import Any

# gpsdclient is a modern, simple gpsd client
# Install gpsd on Pi: sudo apt install gpsd gpsd-clients
# Configure: sudo nano /etc/default/gpsd (set DEVICES="/dev/ttyUSB0" or similar)
try:
    from gpsdclient import GPSDClient
except ImportError:
    GPSDClient = None  # Allow import without gpsd for testing structure


class GPSService:
    """Threaded GPS reader with buffering and auto-reconnect."""

    def __init__(self, host: str = "127.0.0.1", port: int = 2947, buffer_size: int = 100):
        self.host = host
        self.port = port
        self.buffer_size = buffer_size

        self._buffer: deque[dict[str, Any]] = deque(maxlen=buffer_size)
        self._latest: dict[str, Any] = {}
        self._connected = False
        self._running = False
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()

        # Callback for push-based updates
        self._on_data_callback = None

    def set_on_data(self, callback):
        """Set callback for new GPS fix. Called with fix dict."""
        self._on_data_callback = callback

    @property
    def connected(self) -> bool:
        return self._connected

    def get_latest(self) -> dict[str, Any]:
        """Get most recent GPS fix."""
        with self._lock:
            return self._latest.copy() if self._latest else {"error": "no data"}

    def get_buffer(self) -> list[dict[str, Any]]:
        """Get buffered GPS history."""
        with self._lock:
            return list(self._buffer)

    def start(self):
        """Start background GPS reader thread."""
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._reader_loop, daemon=True)
        self._thread.start()

    def stop(self):
        """Stop background reader."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=2.0)

    def _reader_loop(self):
        """Main reader loop with reconnection logic."""
        while self._running:
            try:
                self._connect_and_read()
            except Exception as e:
                self._connected = False
                print(f"[GPS] Connection error: {e}, retrying in 5s...")
                time.sleep(5)

    def _connect_and_read(self):
        """Connect to gpsd and read data."""
        if GPSDClient is None:
            # Stub mode - no gpsd client installed
            print("[GPS] gpsdclient not installed, running in stub mode")
            self._stub_mode()
            return

        try:
            client = GPSDClient(host=self.host, port=self.port)
        except Exception as e:
            print(f"[GPS] Cannot connect to gpsd at {self.host}:{self.port}: {e}, falling back to stub mode")
            self._stub_mode()
            return

        with client:
            self._connected = True
            print(f"[GPS] Connected to gpsd at {self.host}:{self.port}")

            for result in client.dict_stream(filter=["TPV"]):
                if not self._running:
                    break

                # TPV = Time-Position-Velocity report
                fix = {
                    "time": result.get("time"),
                    "lat": result.get("lat"),
                    "lon": result.get("lon"),
                    "alt": result.get("alt"),
                    "speed": result.get("speed"),  # m/s
                    "track": result.get("track"),  # heading in degrees
                    "mode": result.get("mode"),    # 0=no fix, 2=2D, 3=3D
                }

                with self._lock:
                    self._latest = fix
                    if fix.get("lat") is not None:
                        self._buffer.append(fix)

                # Invoke callback with new fix
                if self._on_data_callback:
                    self._on_data_callback(fix)

    def _stub_mode(self):
        """Fake data for testing without gpsd."""
        import random

        while self._running:
            self._connected = True
            fix = {
                "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "lat": 35.6762 + random.uniform(-0.001, 0.001),
                "lon": 139.6503 + random.uniform(-0.001, 0.001),
                "alt": 40.0 + random.uniform(-5, 5),
                "speed": random.uniform(0, 30),
                "track": random.uniform(0, 360),
                "mode": 3,
            }
            with self._lock:
                self._latest = fix
                self._buffer.append(fix)

            # Invoke callback with new fix
            if self._on_data_callback:
                self._on_data_callback(fix)

            time.sleep(1)
