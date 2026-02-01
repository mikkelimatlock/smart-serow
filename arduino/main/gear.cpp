#include "gear.h"

// Mock gear: derived from RPM bands
// Real sensor would read position switch

void gear_init() {
  // Nothing to init for mock
}

int gear_get(int rpm) {
  // Simulate gear based on RPM
  // N < 1000, 1st < 2500, 2nd < 4000, 3rd < 5500, 4th < 7000, 5th+
  if (rpm < 1000) return 0;  // Neutral
  if (rpm < 2500) return 1;
  if (rpm < 4000) return 2;
  if (rpm < 5500) return 3;
  if (rpm < 7000) return 4;
  return 5;
}
