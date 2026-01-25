// Smart Serow - Main
// Motorcycle telemetry hub

#include "voltage.h"

void setup() {
  Serial.begin(9600);
  pinMode(LED_BUILTIN, OUTPUT);

  voltage_init();
}

void loop() {
  // Report battery voltage
  Serial.print("V_bat: ");
  Serial.print(voltage_read(), 2);
  Serial.println("V");

  // Heartbeat blink
  digitalWrite(LED_BUILTIN, HIGH);
  delay(50);
  digitalWrite(LED_BUILTIN, LOW);

  delay(1000);  // 1Hz update rate
}
