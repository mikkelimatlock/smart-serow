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

// Sliding window smoother (max 32 samples to keep RAM usage sane)
static const int MAX_WINDOW = 32;
static int _samples[MAX_WINDOW];
static int _windowSize = 20;  // Active window size
static int _sampleIndex = 0;
static long _sampleSum = 0;

void voltage_init() {
  voltage_set_smoothing(20);  // Default 20 samples
}

void voltage_set_smoothing(int windowSize) {
  // Clamp to valid range
  if (windowSize < 1) windowSize = 1;
  if (windowSize > MAX_WINDOW) windowSize = MAX_WINDOW;
  _windowSize = windowSize;

  // Pre-fill window with current reading
  int initial = analogRead(PIN_VBAT);
  for (int i = 0; i < _windowSize; i++) {
    _samples[i] = initial;
  }
  _sampleSum = (long)initial * _windowSize;
  _sampleIndex = 0;
}

int voltage_read_raw() {
  return analogRead(PIN_VBAT);
}

int voltage_read_smoothed() {
  int raw = analogRead(PIN_VBAT);

  _sampleSum -= _samples[_sampleIndex];   // Remove oldest
  _samples[_sampleIndex] = raw;            // Store new
  _sampleSum += raw;                       // Add new
  _sampleIndex = (_sampleIndex + 1) % _windowSize;

  return _sampleSum / _windowSize;
}

float voltage_read() {
  int raw = voltage_read_smoothed();
  float vDivider = (raw / (float)ADC_MAX) * ADC_REF;
  return vDivider / DIVIDER_RATIO + OFFSET;
}
