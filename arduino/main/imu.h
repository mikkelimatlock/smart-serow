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

#endif
