#include "rpm.h"
#include <Arduino.h>

// Mock RPM: ramps up/down between idle and redline
static int _rpm = 800;

void rpm_init() {
  _rpm = 800;
}

void rpm_update() {
  // ~100ms per call at 10Hz = takes ~7s to sweep range
  _rpm += 10;
  if (_rpm >= 8000) { _rpm = 800;}
}

int rpm_get() {
  return _rpm;
}
