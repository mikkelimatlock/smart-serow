"""GPIO service for Pi Zero - edge-triggered monitoring.

Polls GPIO pins and exposes state changes for inclusion in other payloads.
Keeps UART separate (handled by arduino_service).
"""

import gevent

try:
    import RPi.GPIO as GPIO
    _GPIO_AVAILABLE = True
except ImportError:
    _GPIO_AVAILABLE = False
    print("[GPIO] RPi.GPIO not available - running in mock mode")


# Pin assignments
PIN_THEME_SWITCH = 20  # Physical switch for light/dark theme


class GPIOService:
    """Monitors GPIO pins and tracks state changes."""

    def __init__(self):
        self._running = False
        self._greenlet = None

        # Theme switch state
        self._theme_switch_state = False  # False = light, True = dark
        self._theme_switch_pending = None  # None = no change, bool = new value

        if _GPIO_AVAILABLE:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            # Input with software pull-down (belt + suspenders with hardware pulldown)
            GPIO.setup(PIN_THEME_SWITCH, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)

    def start(self):
        """Start background polling."""
        if self._running:
            return
        self._running = True

        # Read initial state
        if _GPIO_AVAILABLE:
            self._theme_switch_state = GPIO.input(PIN_THEME_SWITCH) == GPIO.HIGH
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
        if _GPIO_AVAILABLE:
            GPIO.cleanup([PIN_THEME_SWITCH])

    def _poll_loop(self):
        """Poll GPIO at ~20Hz, detect edges."""
        while self._running:
            gevent.sleep(0.05)  # 20Hz

            if _GPIO_AVAILABLE:
                current = GPIO.input(PIN_THEME_SWITCH) == GPIO.HIGH
            else:
                current = self._theme_switch_state  # Mock: no change

            if current != self._theme_switch_state:
                self._theme_switch_state = current
                self._theme_switch_pending = current
                print(f"[GPIO] Theme switch changed to {current}")

    def get_theme_switch_change(self):
        """Get pending theme switch change, if any.

        Returns:
            bool or None: New state if changed since last call, None otherwise.
        """
        if self._theme_switch_pending is not None:
            value = self._theme_switch_pending
            self._theme_switch_pending = None
            return value
        return None

    @property
    def theme_switch(self):
        """Current theme switch state (True = dark, False = light)."""
        return self._theme_switch_state
