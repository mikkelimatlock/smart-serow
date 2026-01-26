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

    # ACK pattern: "ACK:CMD:STATUS" or "ACK:CMD:STATUS:extra"
    ACK_PATTERN = re.compile(r"ACK:(\w+):(\w+)(?::(.*))?")

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

        # Callbacks for push-based updates
        self._on_data_callback: callable | None = None
        self._on_ack_callback: callable | None = None

        # Serial port handle for sending commands
        self._serial: Any = None
        self._serial_lock = threading.Lock()

    def set_on_data(self, callback: callable | None):
        """Set callback for new telemetry data. Called with data dict."""
        self._on_data_callback = callback

    def set_on_ack(self, callback: callable | None):
        """Set callback for ACK responses. Called with (cmd, status, extra)."""
        self._on_ack_callback = callback

    def send_command(self, cmd: str, params: dict | None = None) -> bool:
        """Send a command to Arduino via serial.

        Format: "CMD:NAME:PARAM1:PARAM2..." followed by newline

        Args:
            cmd: Command name (e.g., "HORN", "LIGHT")
            params: Optional parameters dict

        Returns:
            True if sent successfully, False if serial unavailable
        """
        with self._serial_lock:
            if self._serial is None or not self._connected:
                print(f"[Arduino] Cannot send command, not connected")
                return False

            try:
                # Build command string
                parts = ["CMD", cmd.upper()]
                if params:
                    for key, val in params.items():
                        parts.append(f"{key}={val}")
                line = ":".join(parts) + "\n"

                self._serial.write(line.encode("utf-8"))
                self._serial.flush()
                print(f"[Arduino] Sent: {line.strip()}")
                return True
            except Exception as e:
                print(f"[Arduino] Failed to send command: {e}")
                return False

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
            # Store serial handle for send_command()
            with self._serial_lock:
                self._serial = ser
            self._connected = True
            print(f"[Arduino] Connected to {self.port} @ {self.baudrate} baud")

            while self._running:
                try:
                    line = ser.readline().decode("utf-8", errors="ignore").strip()
                    if not line:
                        continue

                    # Check for ACK responses first
                    ack_match = self.ACK_PATTERN.match(line)
                    if ack_match:
                        cmd, status, extra = ack_match.groups()
                        if self._on_ack_callback:
                            self._on_ack_callback(cmd, status, extra)
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

                        # Invoke callback with new data
                        if self._on_data_callback:
                            self._on_data_callback(self._latest.copy())

                except serial.SerialException as e:
                    print(f"[Arduino] Serial error: {e}")
                    break

        finally:
            self._connected = False
            with self._serial_lock:
                self._serial = None
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

            # Invoke callback with new data
            if self._on_data_callback:
                self._on_data_callback(data)

            time.sleep(0.5)  # 2Hz stub updates
