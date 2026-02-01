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
