"""GPS service - connects to gpsd, buffers data, handles reconnection."""

import random
import threading
import time
from collections import deque
from typing import Any

# ============================================================================
# DEBUG MODE - Set True for development without GPS hardware
# When True: skips gpsd entirely, generates realistic mock data
# When False: connects to real gpsd (requires GPS device)
# ============================================================================
_GPS_DEBUG = True

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

        # Periodic status logging
        self._last_status_log = 0.0
        self._fix_count = 0

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
        print("[GPS] Service started")

    def stop(self):
        """Stop background reader."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=2.0)

    def _reader_loop(self):
        """Main reader loop with reconnection logic."""
        print("[GPS] Reader thread running")
        while self._running:
            try:
                self._connect_and_read()
            except Exception as e:
                self._connected = False
                print(f"[GPS] Connection error: {e}, retrying in 5s...")
                time.sleep(5)

    def _connect_and_read(self):
        """Connect to gpsd and read data."""
        # Debug mode: skip gpsd entirely, use stub data
        if _GPS_DEBUG:
            print("[GPS] Debug mode enabled, using stub data")
            self._stub_mode()
            return

        if GPSDClient is None:
            print("[GPS] gpsdclient not installed, running in stub mode")
            self._stub_mode()
            return

        # Quick check if gpsd is reachable before attempting connection
        import socket
        try:
            sock = socket.create_connection((self.host, self.port), timeout=2.0)
            sock.close()
        except (socket.timeout, socket.error, OSError) as e:
            print(f"[GPS] gpsd not reachable at {self.host}:{self.port}: {e}")
            raise ConnectionError(f"gpsd not reachable: {e}")

        try:
            client = GPSDClient(host=self.host, port=self.port)
        except Exception as e:
            print(f"[GPS] Cannot connect to gpsd at {self.host}:{self.port}: {e}")
            raise ConnectionError(f"gpsd connection failed: {e}")

        with client:
            self._connected = True
            print(f"[GPS] Connected to gpsd at {self.host}:{self.port}")

            self._last_status_log = time.time()
            self._fix_count = 0
            first_fix_timeout = time.time() + 5.0  # 5s to get first fix

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
                    "satellites": result.get("satellites"),  # from SKY messages
                }

                # Check if this is a real fix (has position) or just empty TPV
                if fix.get("lat") is None and fix.get("mode") in (None, 0, 1):
                    # No real data yet, check timeout
                    if time.time() > first_fix_timeout:
                        print("[GPS] No GPS fix after 5s, will retry connection")
                        raise ConnectionError("No GPS fix within timeout")
                    continue  # Skip empty fixes

                # Got real data, disable timeout
                first_fix_timeout = float('inf')

                with self._lock:
                    self._latest = fix
                    if fix.get("lat") is not None:
                        self._buffer.append(fix)

                # Invoke callback with new fix
                if self._on_data_callback:
                    self._on_data_callback(fix)

                # Periodic status log (every 5s)
                self._fix_count += 1
                now = time.time()
                if now - self._last_status_log >= 5.0:
                    elapsed = now - self._last_status_log
                    fps = self._fix_count / elapsed
                    speed = fix.get('speed', 0) or 0
                    track = fix.get('track', 0) or 0
                    mode = fix.get('mode', 0) or 0
                    sats = fix.get('satellites', '?')
                    print(f"[GPS] {fps:.1f} fix/s | {speed:.1f}m/s hdg={track:.0f}° mode={mode} sats={sats}")
                    self._last_status_log = now
                    self._fix_count = 0

    def _stub_mode(self):
        """Generate realistic mock GPS data for development/testing.

        Simulates:
        - Normal 3D fix with satellites
        - Occasional signal loss (~3% chance per second, lasts ~5s)
        - Wandering position near Tokyo
        """
        self._last_status_log = time.time()
        self._fix_count = 0

        # Signal loss state
        signal_lost = False
        signal_lost_until = 0.0

        # Base position (Tokyo area)
        base_lat = 35.6762
        base_lon = 139.6503
        base_alt = 40.0

        # Smoothly varying heading/speed
        heading = random.uniform(0, 360)
        speed = random.uniform(5, 15)

        while self._running:
            self._connected = True
            now = time.time()

            # Check for signal loss simulation
            if signal_lost:
                if now >= signal_lost_until:
                    signal_lost = False
                    print("[GPS] Signal recovered (stub)")
            else:
                # ~30% chance per second to lose signal
                if random.random() < 0.3:
                    signal_lost = True
                    signal_lost_until = now + 2 # fixed 2s loss
                    print("[GPS] Signal loss simulation (stub)")

            if signal_lost:
                # No fix - mode 1, no satellites, no track
                # Note: use None, not float('nan') - NaN doesn't serialize to valid JSON
                fix = {
                    "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "lat": None,
                    "lon": None,
                    "alt": None,
                    "speed": None,
                    "track": None,
                    "mode": 1,
                    "satellites": 0,
                }
            else:
                # Smoothly vary heading and speed
                heading = (heading + random.uniform(1, 3)) % 360
                speed = max(0, min(30, speed + random.uniform(-2, 2)))

                fix = {
                    "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "lat": base_lat + random.uniform(-0.001, 0.001),
                    "lon": base_lon + random.uniform(-0.001, 0.001),
                    "alt": base_alt + random.uniform(-5, 5),
                    "speed": speed,
                    "track": heading,
                    "mode": 3,
                    "satellites": random.randint(6, 12),
                }

            with self._lock:
                self._latest = fix
                if fix.get("lat") is not None:
                    self._buffer.append(fix)

            # Invoke callback with new fix
            if self._on_data_callback:
                self._on_data_callback(fix)

            # Periodic status log (every 5s)
            self._fix_count += 1
            if now - self._last_status_log >= 5.0:
                elapsed = now - self._last_status_log
                fps = self._fix_count / elapsed
                speed_val = fix.get('speed') or 0
                track_val = fix.get('track')
                track_str = f"{track_val:.0f}" if track_val is not None else "---"
                mode = fix.get('mode', 0)
                sats = fix.get('satellites', 0)
                print(f"[GPS] {fps:.1f} fix/s | {speed_val:.1f}m/s hdg={track_str} mode={mode} sats={sats} (stub)")
                self._last_status_log = now
                self._fix_count = 0

            time.sleep(1)
