#ifndef VOLTAGE_H
#define VOLTAGE_H

#include <Arduino.h>

// Initialize voltage monitoring (call in setup)
void voltage_init();

// Read battery voltage, returns volts (e.g., 12.5)
float voltage_read();

// Read raw ADC value (0-1023)
int voltage_read_raw();

#endif
