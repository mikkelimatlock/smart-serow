#include "imu.h"
#include <AltSoftSerial.h>

// AltSoftSerial uses fixed pins on ATmega328P:
// RX = Pin 8, TX = Pin 9
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

// Calibration offsets and state
static ImuData offsets = {0};
static bool calibrated = false;

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
  // Configure WT61 at 115200 - stays there (no baud switch)
  // See IMU.md for command reference
  imuSerial.begin(115200);

  imu_send_cmd(0x52);  // Reset yaw (for the sake of it)
  delay(50);
  imu_send_cmd(0x65);  // Flat mounting mode
  delay(50);
  imu_send_cmd(0x64);  // 9600 bauds / 20Hz report
  delay(150);          // Let WT61 process config

  // Revert to 9600 bauds
  imuSerial.begin(9600);

  // In case WT61 already is at 9600
  imu_send_cmd(0x52);  // Reset yaw (for the sake of it)
  delay(50);
  imu_send_cmd(0x65);  // Flat mounting mode
  delay(50);
  imu_send_cmd(0x64);  // 9600 bauds / 20Hz report
  delay(150);          // Let WT61 process config


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
  // Apply calibration offsets if calibrated
  // Using a static to avoid creating new struct each call
  static ImuData calibratedData;

  if (calibrated) {
    calibratedData.ax = currentData.ax - offsets.ax;
    calibratedData.ay = currentData.ay - offsets.ay;
    calibratedData.az = currentData.az - offsets.az;
    calibratedData.gx = currentData.gx - offsets.gx;
    calibratedData.gy = currentData.gy - offsets.gy;
    calibratedData.gz = currentData.gz - offsets.gz;
    calibratedData.roll = currentData.roll - offsets.roll;
    calibratedData.pitch = currentData.pitch - offsets.pitch;
    calibratedData.yaw = currentData.yaw - offsets.yaw;
    calibratedData.lastUpdate = currentData.lastUpdate;
    return calibratedData;
  }

  return currentData;
}

bool imu_is_fresh(unsigned long timeout_ms) {
  return (millis() - currentData.lastUpdate) < timeout_ms;
}

void imu_calibrate() {
  const int SAMPLES = 5;  // ~250ms at 20Hz IMU rate

  // Accumulators for averaging
  float sum_ax = 0, sum_ay = 0, sum_az = 0;
  float sum_gx = 0, sum_gy = 0, sum_gz = 0;
  float sum_roll = 0, sum_pitch = 0, sum_yaw = 0;

  int count = 0;
  unsigned long lastUpdate = currentData.lastUpdate;

  // Block until we've collected enough samples
  while (count < SAMPLES) {
    imu_update();

    if (currentData.lastUpdate != lastUpdate) {
      // New angle packet arrived (lastUpdate only changes on angle packets)
      sum_ax += currentData.ax;
      sum_ay += currentData.ay;
      sum_az += currentData.az;
      sum_gx += currentData.gx;
      sum_gy += currentData.gy;
      sum_gz += currentData.gz;
      sum_roll += currentData.roll;
      sum_pitch += currentData.pitch;
      sum_yaw += currentData.yaw;

      lastUpdate = currentData.lastUpdate;
      count++;
    }
  }

  // Store averaged offsets
  offsets.ax = sum_ax / SAMPLES;
  offsets.ay = sum_ay / SAMPLES;
  offsets.az = sum_az / SAMPLES;
  offsets.gx = sum_gx / SAMPLES;
  offsets.gy = sum_gy / SAMPLES;
  offsets.gz = sum_gz / SAMPLES;
  offsets.roll = sum_roll / SAMPLES;
  offsets.pitch = sum_pitch / SAMPLES;
  offsets.yaw = sum_yaw / SAMPLES;

  calibrated = true;
}

bool imu_is_calibrated() {
  return calibrated;
}

void imu_send_cmd(uint8_t cmd) {
  const uint8_t packet[] = {0xFF, 0xAA, cmd};
  imuSerial.write(packet, 3);
  imuSerial.flush();
}
