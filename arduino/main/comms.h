#ifndef COMMS_H
#define COMMS_H

#include <Arduino.h>
#include "imu.h"

// Initialize Pi serial communication (call in setup)
void comms_init();

// Process incoming commands from Pi - call in loop
// Returns true if a complete command was received
bool comms_update();

// Send complete telemetry frame (TSV format, null-terminated)
// Format: V_bat\tAx\tAy\tAz\tGx\tGy\tGz\tRoll\tPitch\tYaw\tRPM\tGear\0
// If imu_valid is false, IMU fields are empty (but tabs preserved)
void comms_send_telemetry(float voltage, const ImuData& imu, bool imu_valid, int rpm, int gear);

// Send key:value line (for debug/ACK, newline-terminated)
void comms_send(const char* key, float value, int decimals = 2);
void comms_send(const char* key, int value);
void comms_send(const char* key, const char* value);

// Get last received command (empty if none)
// Command buffer is cleared after reading
const char* comms_get_command();

// Check if connected (received any data recently)
bool comms_is_connected(unsigned long timeout_ms = 5000);

#endif
