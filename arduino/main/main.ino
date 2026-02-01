// Smart Serow - Main
// Motorcycle telemetry hub

#include "voltage.h"
#include "imu.h"
#include "rpm.h"
#include "gear.h"
#include "comms.h"

// Timing
static const unsigned long TELEMETRY_INTERVAL_MS = 100;  // 10Hz telemetry
static unsigned long lastTelemetryTime = 0;

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);

  comms_init();    // Hardware Serial first so we can debug
  Serial.println(F("[INIT] comms ok"));

  voltage_init();
  Serial.println(F("[INIT] voltage ok"));

  imu_init();      // AltSoftSerial on pins 8(RX)/9(TX)
  Serial.println(F("[INIT] imu ok"));

  rpm_init();
  gear_init();
  Serial.println(F("[INIT] rpm/gear ok"));

  // Let IMU warm up a bit before calibrating
  // (WT61 needs a moment to stabilize after power-on)
  delay(500);

  Serial.println(F("[INIT] calibrating..."));
  // Zero calibration - current position becomes reference
  // Blocks for ~250ms while sampling
  imu_calibrate();
  Serial.println(F("[INIT] calibration done, entering loop"));
}

void loop() {
  // Always poll IMU - it's streaming at 20Hz
  imu_update();

  // Update mock RPM (ramping)
  rpm_update();

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
  // Send all telemetry in a single TSV frame
  float voltage = voltage_read();
  const ImuData& imu = imu_get_data();
  bool imu_valid = imu_is_fresh();
  int rpm = rpm_get();
  int gear = gear_get(rpm);

  comms_send_telemetry(voltage, imu, imu_valid, rpm, gear);
}
