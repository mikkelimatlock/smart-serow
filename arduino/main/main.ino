// Smart Serow - Main
// Motorcycle telemetry hub

#include "voltage.h"
#include "imu.h"
#include "comms.h"

// Timing
static const unsigned long TELEMETRY_INTERVAL_MS = 100;  // 10Hz telemetry
static unsigned long lastTelemetryTime = 0;

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);

  voltage_init();
  imu_init();      // AltSoftSerial on pins 8(RX)/9(TX)
  comms_init();    // Hardware Serial to Pi at 115200

  // Let IMU warm up a bit before calibrating
  // (WT61 needs a moment to stabilize after power-on)
  delay(500);

  // Zero calibration - current position becomes reference
  // Blocks for ~250ms while sampling
  imu_calibrate();
}

void loop() {
  // Always poll IMU - it's streaming at 20Hz
  imu_update();

  // Process any commands from Pi
  if (comms_update()) {
    const char* cmd = comms_get_command();
    // Future: handle commands like "PING", "SET_RATE", etc.
    // For now, echo back as acknowledgment
    if (cmd[0] != '\0') {
      comms_send("ACK", cmd);
    }
  }

  // Send telemetry at fixed interval
  unsigned long now = millis();
  if (now - lastTelemetryTime >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryTime = now;
    sendTelemetry();
  }

  // Heartbeat - quick blink if IMU fresh, slow blink if stale
  static unsigned long lastBlink = 0;
  unsigned long blinkInterval = imu_is_fresh() ? 500 : 2000;
  if (now - lastBlink >= blinkInterval) {
    lastBlink = now;
    digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
  }
}

void sendTelemetry() {
  // Battery voltage
  comms_send("V_bat", voltage_read());

  // IMU data (only if we have fresh data)
  if (imu_is_fresh()) {
    const ImuData& imu = imu_get_data();

    // Acceleration (g)
    comms_send("Ax", imu.ax);
    comms_send("Ay", imu.ay);
    comms_send("Az", imu.az);

    // Angular velocity (deg/s)
    comms_send("Gx", imu.gx);
    comms_send("Gy", imu.gy);
    comms_send("Gz", imu.gz);

    // Euler angles (degrees)
    comms_send("Roll", imu.roll);
    comms_send("Pitch", imu.pitch);
    comms_send("Yaw", imu.yaw);
  } else {
    comms_send("IMU", "STALE");
  }
}
