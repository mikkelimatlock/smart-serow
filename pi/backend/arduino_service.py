"""Arduino service - connects to Arduino Nano via serial, buffers telemetry."""

import json
import re
import threading
import time
from collections import deque
from typing import Any

# pyserial for UART communication
try:
    import serial
except ImportError:
    serial = None  # Allow import without pyserial for testing structure


class ArduinoService:
    """Threaded Arduino serial reader with buffering and auto-reconnect."""

    # Regex patterns for legacy text protocol
    PATTERNS = {
        "voltage": re.compile(r"V_bat:\s*(\d+\.?\d*)V?", re.IGNORECASE),
        "rpm": re.compile(r"RPM:\s*(\d+)", re.IGNORECASE),
        "eng_temp": re.compile(r"ENG:\s*(\d+)C?", re.IGNORECASE),
        "gear": re.compile(r"GEAR:\s*(\d+)", re.IGNORECASE),
    }

    def __init__(
        self,
        port: str = "/dev/ttyUSB0",
        baudrate: int = 115200,
        buffer_size: int = 100,
    ):
        self.port = port
        self.baudrate = baudrate
        self.buffer_size = buffer_size

        self._buffer: deque[dict[str, Any]] = deque(maxlen=buffer_size)
        self._latest: dict[str, Any] = {}
        self._connected = False
        self._running = False
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()

    @property
    def connected(self) -> bool:
        return self._connected

    def get_latest(self) -> dict[str, Any]:
        """Get most recent telemetry values."""
        with self._lock:
            return self._latest.copy() if self._latest else {"error": "no data"}

    def get_buffer(self) -> list[dict[str, Any]]:
        """Get buffered telemetry history."""
        with self._lock:
            return list(self._buffer)

    def start(self):
        """Start background serial reader thread."""
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
                print(f"[Arduino] Connection error: {e}, retrying in 5s...")
                time.sleep(5)

    def _connect_and_read(self):
        """Connect to Arduino serial and read data."""
        if serial is None:
            # Stub mode - no pyserial installed
            print("[Arduino] pyserial not installed, running in stub mode")
            self._stub_mode()
            return

        try:
            ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=1.0,
            )
        except serial.SerialException as e:
            print(f"[Arduino] Cannot open {self.port}: {e}, falling back to stub mode")
            self._stub_mode()
            return

        try:
            self._connected = True
            print(f"[Arduino] Connected to {self.port} @ {self.baudrate} baud")

            while self._running:
                try:
                    line = ser.readline().decode("utf-8", errors="ignore").strip()
                    if not line:
                        continue

                    data = self._parse_line(line)
                    if data:
                        data["time"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                        with self._lock:
                            # Merge new values into latest (preserve old values for partial updates)
                            for key, val in data.items():
                                if val is not None:
                                    self._latest[key] = val
                            self._latest["time"] = data["time"]
                            self._buffer.append(self._latest.copy())

                except serial.SerialException as e:
                    print(f"[Arduino] Serial error: {e}")
                    break

        finally:
            self._connected = False
            ser.close()

    def _parse_line(self, line: str) -> dict[str, Any] | None:
        """Parse a line from Arduino - JSON first, fallback to regex.

        JSON format: {"v":12.45,"rpm":4500,"eng":85,"gear":3}
        Legacy text: V_bat: 12.45V
        """
        # Try JSON first (production format)
        try:
            obj = json.loads(line)
            return {
                "voltage": obj.get("v"),
                "rpm": obj.get("rpm"),
                "eng_temp": obj.get("eng"),
                "gear": obj.get("gear"),
            }
        except json.JSONDecodeError:
            pass

        # Fallback to regex for legacy text protocol
        result = {}
        for key, pattern in self.PATTERNS.items():
            match = pattern.search(line)
            if match:
                val = match.group(1)
                result[key] = float(val) if "." in val else int(val)

        return result if result else None

    def _stub_mode(self):
        """Fake data for testing without Arduino connected."""
        import random

        while self._running:
            self._connected = True
            data = {
                "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "voltage": round(12.0 + random.uniform(-0.5, 0.8), 2),
                "rpm": random.randint(800, 6000) if random.random() > 0.3 else None,
                "eng_temp": random.randint(60, 95),
                "gear": random.randint(1, 6) if random.random() > 0.2 else 0,  # 0 = neutral
            }
            with self._lock:
                self._latest = data
                self._buffer.append(data)
            time.sleep(0.5)  # 2Hz stub updates
