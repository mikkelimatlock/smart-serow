#include "comms.h"

// Pi communication uses hardware Serial (pins 0/1)
// Baud rate - 115200 is reasonable for duplex with Pi
static const long BAUD_RATE = 115200;

// Command buffer
static const int CMD_BUF_SIZE = 64;
static char cmdBuf[CMD_BUF_SIZE];
static int cmdIndex = 0;
static bool cmdReady = false;

// Connection tracking
static unsigned long lastRxTime = 0;

void comms_init() {
  Serial.begin(BAUD_RATE);
  cmdIndex = 0;
  cmdReady = false;
}

bool comms_update() {
  while (Serial.available()) {
    char c = Serial.read();
    lastRxTime = millis();

    if (c == '\n' || c == '\r') {
      if (cmdIndex > 0) {
        cmdBuf[cmdIndex] = '\0';
        cmdReady = true;
        cmdIndex = 0;
        return true;
      }
    } else if (cmdIndex < CMD_BUF_SIZE - 1) {
      cmdBuf[cmdIndex++] = c;
    }
    // else: overflow, silently drop extra chars
  }
  return false;
}

void comms_send_telemetry(float voltage, const ImuData& imu, bool imu_valid, int rpm, int gear) {
  // Field 0: voltage
  Serial.print(voltage, 2);
  Serial.write('\t');

  if (imu_valid) {
    // Fields 1-3: acceleration
    Serial.print(imu.ax, 2);
    Serial.write('\t');
    Serial.print(imu.ay, 2);
    Serial.write('\t');
    Serial.print(imu.az, 2);
    Serial.write('\t');

    // Fields 4-6: angular velocity
    Serial.print(imu.gx, 2);
    Serial.write('\t');
    Serial.print(imu.gy, 2);
    Serial.write('\t');
    Serial.print(imu.gz, 2);
    Serial.write('\t');

    // Fields 7-9: euler angles
    Serial.print(imu.roll, 2);
    Serial.write('\t');
    Serial.print(imu.pitch, 2);
    Serial.write('\t');
    Serial.print(imu.yaw, 2);
  } else {
    // Empty fields for stale IMU (9 tabs for 9 empty fields)
    Serial.print(F("\t\t\t\t\t\t\t\t"));
  }

  // Fields 10-11: RPM and gear
  Serial.write('\t');
  Serial.print(rpm);
  Serial.write('\t');
  Serial.print(gear);

  // Null terminator (no newline)
  Serial.write('\0');
}

void comms_send(const char* key, float value, int decimals) {
  Serial.print(key);
  Serial.print(": ");
  Serial.println(value, decimals);
}

void comms_send(const char* key, int value) {
  Serial.print(key);
  Serial.print(": ");
  Serial.println(value);
}

void comms_send(const char* key, const char* value) {
  Serial.print(key);
  Serial.print(": ");
  Serial.println(value);
}

const char* comms_get_command() {
  if (cmdReady) {
    cmdReady = false;
    return cmdBuf;
  }
  return "";
}

bool comms_is_connected(unsigned long timeout_ms) {
  return (millis() - lastRxTime) < timeout_ms;
}
