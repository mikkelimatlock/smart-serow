#ifndef COMMS_H
#define COMMS_H

#include <Arduino.h>

// Initialize Pi serial communication (call in setup)
void comms_init();

// Process incoming commands from Pi - call in loop
// Returns true if a complete command was received
bool comms_update();

// Send telemetry line to Pi
void comms_send(const char* key, float value, int decimals = 2);
void comms_send(const char* key, int value);
void comms_send(const char* key, const char* value);

// Get last received command (empty if none)
// Command buffer is cleared after reading
const char* comms_get_command();

// Check if connected (received any data recently)
bool comms_is_connected(unsigned long timeout_ms = 5000);

#endif
