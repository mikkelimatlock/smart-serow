"""GPIO service for Pi Zero - edge-triggered monitoring.

Polls GPIO pins and exposes state changes for inclusion in other payloads.
Keeps UART separate (handled by arduino_service).

Tries RPi.GPIO first (apt install python3-rpi.gpio), falls back to gpiozero.
"""

import gevent

# Try RPi.GPIO first (commonly installed via apt on Pi)
_BACKEND = None
try:
    import RPi.GPIO as GPIO
    _BACKEND = "rpigpio"
    print("[GPIO] Using RPi.GPIO backend")
except ImportError:
    try:
        from gpiozero import Button
        _BACKEND = "gpiozero"
        print("[GPIO] Using gpiozero backend")
    except ImportError:
        print("[GPIO] No GPIO library available - running in mock mode")


# Pin assignments
PIN_THEME_SWITCH = 20  # Physical switch for light/dark theme


class GPIOService:
    """Monitors GPIO pins and tracks state changes."""

    def __init__(self):
        self._running = False
        self._greenlet = None
        self._theme_button = None  # gpiozero only
        self._gpio_working = False

        # Theme switch state
        self._theme_switch_state = False  # False = light, True = dark
        self._pending_state = None  # Candidate new state
        self._pending_count = 0     # Consecutive readings of pending state

        if _BACKEND == "rpigpio":
            try:
                GPIO.setmode(GPIO.BCM)
                GPIO.setwarnings(False)
                # No software pull - using external hardware pull-down
                GPIO.setup(PIN_THEME_SWITCH, GPIO.IN, pull_up_down=GPIO.PUD_OFF)
                self._gpio_working = True
            except Exception as e:
                print(f"[GPIO] RPi.GPIO init failed: {e}")
        elif _BACKEND == "gpiozero":
            try:
                self._theme_button = Button(PIN_THEME_SWITCH, pull_up=False)
                self._gpio_working = True
            except Exception as e:
                print(f"[GPIO] gpiozero init failed: {e}")

    def _read_pin(self):
        """Read current pin state. Returns True if HIGH (dark mode)."""
        if _BACKEND == "rpigpio":
            return GPIO.input(PIN_THEME_SWITCH) == GPIO.HIGH
        elif _BACKEND == "gpiozero" and self._theme_button:
            return self._theme_button.is_pressed
        return self._theme_switch_state  # Mock: return current

    def start(self):
        """Start background polling."""
        if self._running:
            return
        self._running = True

        # Read initial state
        if self._gpio_working:
            self._theme_switch_state = self._read_pin()
        else:
            self._theme_switch_state = True  # Mock: default dark

        self._greenlet = gevent.spawn(self._poll_loop)
        print(f"[GPIO] Started, theme_switch initial={self._theme_switch_state}")

    def stop(self):
        """Stop background polling."""
        self._running = False
        if self._greenlet:
            self._greenlet.kill()
            self._greenlet = None
        if _BACKEND == "rpigpio":
            try:
                GPIO.cleanup([PIN_THEME_SWITCH])
            except Exception:
                pass
        elif self._theme_button:
            self._theme_button.close()
            self._theme_button = None

    def _poll_loop(self):
        """Poll GPIO at ~20Hz, update state with consecutive-read debounce."""
        poll_count = 0
        # Require N consecutive same readings to accept state change
        # At 20Hz: 10 readings = 500ms, 20 readings = 1s
        required_consecutive = 11  # ~550ms of stable signal

        while self._running:
            gevent.sleep(0.05)  # 20Hz
            poll_count += 1

            if self._gpio_working:
                current = self._read_pin()

                if current != self._theme_switch_state:
                    # Different from accepted state - count towards change
                    if current == self._pending_state:
                        self._pending_count += 1
                    else:
                        # New candidate state
                        self._pending_state = current
                        self._pending_count = 1

                    # Accept change after enough consecutive readings
                    if self._pending_count >= required_consecutive:
                        self._theme_switch_state = current
                        self._pending_state = None
                        self._pending_count = 0
                        print(f"[GPIO] Theme switch: {current} (dark={current})")
                else:
                    # Matches current state - reset any pending change
                    self._pending_state = None
                    self._pending_count = 0

            # Heartbeat log every ~5 seconds (100 polls at 20Hz)
            if poll_count >= 100:
                poll_count = 0
                raw = 1 if self._theme_switch_state else 0
                print(f"[GPIO] Pin {PIN_THEME_SWITCH}: {raw} (dark={self._theme_switch_state})")

    @property
    def theme_switch(self):
        """Current theme switch state (True = dark, False = light)."""
        return self._theme_switch_state
