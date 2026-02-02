#include "rpm.h"
#include <Arduino.h>

// Mock RPM: ramps up/down between idle and redline
static int _rpm = 800;
static unsigned long _lastUpdate = 0;
static const unsigned long RPM_UPDATE_INTERVAL_MS = 100;  // 10Hz ramp rate

void rpm_init() {
  _rpm = 800;
  _lastUpdate = 0;
}

void rpm_update() {
  unsigned long now = millis();
  if (now - _lastUpdate < RPM_UPDATE_INTERVAL_MS) {
    return;  // Not time yet
  }
  _lastUpdate = now;

  // +10 RPM every 100ms = ~7s to sweep 800-8000
  _rpm += 10;
  if (_rpm >= 8000) { _rpm = 800; }
}

int rpm_get() {
  return _rpm;
}
