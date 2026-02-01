#ifndef IMU_H
#define IMU_H

#include <Arduino.h>

// WT61 IMU data structure
struct ImuData {
  // Acceleration (g)
  float ax, ay, az;
  // Angular velocity (deg/s)
  float gx, gy, gz;
  // Euler angles (degrees)
  float roll, pitch, yaw;
  // Timestamp of last valid packet (millis)
  unsigned long lastUpdate;
};

// Initialize IMU serial (call in setup)
void imu_init();

// Process incoming bytes - call frequently in loop
// Returns true if new complete packet was parsed
bool imu_update();

// Get latest IMU data
const ImuData& imu_get_data();

// Check if IMU data is fresh (updated within timeout_ms)
bool imu_is_fresh(unsigned long timeout_ms = 200);

// Calibrate IMU - blocks for ~250ms while sampling
// Sets current orientation as zero reference
// Note: Zeroes all axes including accel (loses gravity reference)
//       Revisit once mounting orientation is finalized
void imu_calibrate();

// Check if calibration has been performed
bool imu_is_calibrated();

// Send command to IMU (see IMU.md for command list)
// Common commands: 0x52 = zero yaw, 0x67 = calibrate accel
void imu_send_cmd(uint8_t cmd);

// Convenience: zero the yaw angle
inline void imu_zero_yaw() { imu_send_cmd(0x52); }

// Convenience: calibrate accelerometer (keep module level!)
inline void imu_calibrate_accel() { imu_send_cmd(0x67); }

#endif
