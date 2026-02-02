"""Arduino service - connects to Arduino Nano via serial, buffers telemetry."""

import json
import math
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

    # TSV field names (order per PROTOCOL.md)
    TSV_FIELDS = ['voltage', 'ax', 'ay', 'az', 'gx', 'gy', 'gz', 'roll', 'pitch', 'yaw', 'rpm', 'gear']

    # Regex patterns for legacy text protocol (backwards compatibility)
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
        port: str = "/dev/serial0",
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
        self._on_data_callback = None
        self._on_ack_callback = None

        # Serial port handle for sending commands
        self._serial: Any = None
        self._serial_lock = threading.Lock()

        # Periodic status logging
        self._last_status_log = 0.0
        self._frame_count = 0

    def set_on_data(self, callback):
        """Set callback for new telemetry data. Called with data dict."""
        self._on_data_callback = callback

    def set_on_ack(self, callback):
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
            print("[Arduino] pyserial not installed, cannot connect")
            return  # Will retry via _reader_loop after 5s

        try:
            ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=1.0,
            )
        except serial.SerialException as e:
            print(f"[Arduino] Cannot open {self.port}: {e}")
            return  # Will retry via _reader_loop after 5s

        try:
            # Store serial handle for send_command()
            with self._serial_lock:
                self._serial = ser
            self._connected = True
            self._last_status_log = time.time()
            self._frame_count = 0
            print(f"[Arduino] Connected to {self.port} @ {self.baudrate} baud")

            while self._running:
                try:
                    # Read null-terminated line (TSV protocol)
                    line = self._read_null_terminated(ser)
                    if not line:
                        continue

                    # Check for ACK responses first (legacy newline-terminated)
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
                                if val is not None and not (isinstance(val, float) and math.isnan(val)):
                                    self._latest[key] = val
                            self._latest["time"] = data["time"]
                            self._buffer.append(self._latest.copy())

                        # Invoke callback with new data
                        if self._on_data_callback:
                            self._on_data_callback(self._latest.copy())

                        # Periodic status log (every 5s)
                        self._frame_count += 1
                        now = time.time()
                        if now - self._last_status_log >= 5.0:
                            elapsed = now - self._last_status_log
                            fps = self._frame_count / elapsed
                            v = self._latest.get('voltage', 0)
                            rpm = self._latest.get('rpm', 0)
                            gear = self._latest.get('gear', 0)
                            roll = self._latest.get('roll', 0)
                            print(f"[Arduino] {fps:.1f} fps | V={v:.1f} RPM={int(rpm)} G={int(gear)} roll={roll:.1f}°")
                            self._last_status_log = now
                            self._frame_count = 0

                except serial.SerialException as e:
                    print(f"[Arduino] Serial error: {e}")
                    break

        finally:
            self._connected = False
            with self._serial_lock:
                self._serial = None
            ser.close()

    def _read_null_terminated(self, ser) -> str:
        """Read bytes until null terminator or newline (fallback for legacy)."""
        buf = bytearray()
        while self._running:
            byte = ser.read(1)
            if not byte:
                # Timeout
                if buf:
                    # Return partial buffer if we have data
                    return buf.decode("utf-8", errors="ignore").strip()
                return ""
            if byte == b'\x00' or byte == b'\n' or byte == b'\r':
                # End of frame
                if buf:
                    return buf.decode("utf-8", errors="ignore").strip()
                # Skip empty lines / consecutive terminators
                continue
            buf.append(byte[0])
            # Safety limit
            if len(buf) > 256:
                return buf.decode("utf-8", errors="ignore").strip()

    def _parse_line(self, line: str) -> dict[str, Any] | None:
        """Parse a line from Arduino - TSV first, then JSON, fallback to regex.

        TSV format: 12.45\t0.02\t-0.01\t... (10 fields, per PROTOCOL.md)
        JSON format: {"v":12.45,"rpm":4500,"eng":85,"gear":3}
        Legacy text: V_bat: 12.45V
        """
        # Try TSV first (new protocol)
        if '\t' in line:
            return self._parse_tsv(line)

        # Try JSON (may still be used for special messages)
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

    def _parse_tsv(self, line: str) -> dict[str, Any] | None:
        """Parse TSV telemetry frame per PROTOCOL.md.

        Fields: voltage, ax, ay, az, gx, gy, gz, roll, pitch, yaw
        Empty fields (stale IMU) become NaN.
        """
        fields = line.split('\t')
        if len(fields) != len(self.TSV_FIELDS):
            # Wrong field count - might be debug output or malformed
            return None

        result = {}
        for i, name in enumerate(self.TSV_FIELDS):
            val_str = fields[i].strip()
            if val_str == '':
                # Empty field = stale/missing data
                result[name] = float('nan')
            else:
                try:
                    result[name] = float(val_str)
                except ValueError:
                    result[name] = float('nan')

        # IMU axis correction for mounting orientation
        # Pitch/yaw inverted for motorcycle frame alignment (roll left as-is)
        if 'pitch' in result and not math.isnan(result['pitch']):
            result['pitch'] = -result['pitch']
        if 'yaw' in result and not math.isnan(result['yaw']):
            result['yaw'] = -result['yaw']

        return result

