#ifndef VOLTAGE_H
#define VOLTAGE_H

#include <Arduino.h>

// Initialize voltage monitoring (call in setup)
void voltage_init();

// Set smoothing window size (1-32 samples, default 20)
// Resets the buffer with current reading
void voltage_set_smoothing(int windowSize);

// Read battery voltage (smoothed), returns volts (e.g., 12.5)
float voltage_read();

// Read smoothed ADC value (averaged over window)
int voltage_read_smoothed();

// Read raw ADC value (0-1023), no smoothing
int voltage_read_raw();

#endif
