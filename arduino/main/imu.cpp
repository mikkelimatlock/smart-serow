#include "imu.h"
#include <AltSoftSerial.h>

// AltSoftSerial uses fixed pins on ATmega328P:
// RX = Pin 8, TX = Pin 9 (TX not used for WT61)
static AltSoftSerial imuSerial;

// WT61 packet structure:
// Byte 0: 0x55 (header)
// Byte 1: Packet type (0x51=accel, 0x52=gyro, 0x53=angle)
// Bytes 2-9: Data (4x int16_t, little-endian)
// Byte 10: Checksum (sum of bytes 0-9, lower 8 bits)
static const uint8_t PACKET_HEADER = 0x55;
static const uint8_t PACKET_ACCEL  = 0x51;
static const uint8_t PACKET_GYRO   = 0x52;
static const uint8_t PACKET_ANGLE  = 0x53;
static const int PACKET_SIZE = 11;

// Receive buffer
static uint8_t rxBuf[PACKET_SIZE];
static int rxIndex = 0;

// Latest data
static ImuData currentData = {0};

// Scale factors from WT61 datasheet
// Accel: raw / 32768 * 16g
// Gyro:  raw / 32768 * 2000 deg/s
// Angle: raw / 32768 * 180 deg
static const float ACCEL_SCALE = 16.0 / 32768.0;
static const float GYRO_SCALE  = 2000.0 / 32768.0;
static const float ANGLE_SCALE = 180.0 / 32768.0;

static int16_t parseI16(uint8_t lo, uint8_t hi) {
  return (int16_t)((hi << 8) | lo);
}

static bool validateChecksum() {
  uint8_t sum = 0;
  for (int i = 0; i < PACKET_SIZE - 1; i++) {
    sum += rxBuf[i];
  }
  return sum == rxBuf[PACKET_SIZE - 1];
}

static void processPacket() {
  if (!validateChecksum()) {
    return;  // Bad packet, ignore
  }

  uint8_t type = rxBuf[1];
  int16_t v0 = parseI16(rxBuf[2], rxBuf[3]);
  int16_t v1 = parseI16(rxBuf[4], rxBuf[5]);
  int16_t v2 = parseI16(rxBuf[6], rxBuf[7]);
  // v3 at bytes 8-9 is temperature, ignored for now

  switch (type) {
    case PACKET_ACCEL:
      currentData.ax = v0 * ACCEL_SCALE;
      currentData.ay = v1 * ACCEL_SCALE;
      currentData.az = v2 * ACCEL_SCALE;
      break;
    case PACKET_GYRO:
      currentData.gx = v0 * GYRO_SCALE;
      currentData.gy = v1 * GYRO_SCALE;
      currentData.gz = v2 * GYRO_SCALE;
      break;
    case PACKET_ANGLE:
      currentData.roll  = v0 * ANGLE_SCALE;
      currentData.pitch = v1 * ANGLE_SCALE;
      currentData.yaw   = v2 * ANGLE_SCALE;
      currentData.lastUpdate = millis();
      break;
  }
}

void imu_init() {
  imuSerial.begin(9600);
  rxIndex = 0;
  currentData = {0};
}

bool imu_update() {
  bool gotPacket = false;

  while (imuSerial.available()) {
    uint8_t c = imuSerial.read();

    // State machine: look for header, then collect packet
    if (rxIndex == 0) {
      if (c == PACKET_HEADER) {
        rxBuf[rxIndex++] = c;
      }
      // else: discard, wait for sync
    } else {
      rxBuf[rxIndex++] = c;

      if (rxIndex >= PACKET_SIZE) {
        processPacket();
        rxIndex = 0;
        gotPacket = true;
      }
    }
  }

  return gotPacket;
}

const ImuData& imu_get_data() {
  return currentData;
}

bool imu_is_fresh(unsigned long timeout_ms) {
  return (millis() - currentData.lastUpdate) < timeout_ms;
}
