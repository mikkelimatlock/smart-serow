#include "voltage.h"

// Pin definitions
static const int PIN_VBAT = A0;

// Voltage divider constants
// Divider: 100k upper (to Vin), 47k lower (to GND)
// Vout = Vin * (47k / (100k + 47k)) = Vin * 0.3197
// At 12V: ADC sees 3.84V | At 14.4V: ADC sees 4.60V
static const float DIVIDER_RATIO = 47.0 / (100.0 + 47.0);  // ~0.3197
static const float ADC_REF = 5.0;
static const int ADC_MAX = 1023;
static const float OFFSET = 0.2; // calib

void voltage_init() {
  // analogRead doesn't need explicit pinMode, but here for future config
  // e.g., could switch to internal 1.1V reference for different range
}

int voltage_read_raw() {
  return analogRead(PIN_VBAT);
}

float voltage_read() {
  int raw = voltage_read_raw();
  float vDivider = (raw / (float)ADC_MAX) * ADC_REF;
  return vDivider / DIVIDER_RATIO + OFFSET; 
}
