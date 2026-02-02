# WT61 IMU Quick Reference

6-axis IMU (accelerometer + gyroscope) with onboard angle calculation via Kalman filter.

## Serial Configuration

| Setting | Factory Default | Our Config |
|---------|-----------------|------------|
| Baud rate | 115200 | 115200 |
| Output rate | 100Hz | 100Hz |

**Config commands** (sent on init):
```
0xFF 0xAA 0x66  # Vertical mounting mode
0xFF 0xAA 0x63  # 115200 baud / 100Hz
```
Settings are saved to flash - persist across power cycles.

**Fallback to 9600/20Hz:** If 115200 causes packet loss on AltSoftSerial, change `0x63` to `0x64` in `imu.cpp` and add `imuSerial.begin(9600)` after the delay.

## Wiring (ATmega328P / AltSoftSerial)

| WT61 Pin | Arduino Pin | Notes |
|----------|-------------|-------|
| TX | 8 (RX) | AltSoftSerial fixed pin |
| RX | 9 (TX) | Only needed for config commands |
| VCC | 5V | |
| GND | GND | |

## Packet Structure

11 bytes per packet, continuous stream (3 packet types interleaved):

```
Byte 0:    0x55 (header)
Byte 1:    Packet type
Bytes 2-3: Value 0 (int16_t, little-endian)
Bytes 4-5: Value 1
Bytes 6-7: Value 2
Bytes 8-9: Temperature (usually ignored)
Byte 10:   Checksum (sum of bytes 0-9, lower 8 bits)
```

### Packet Types

| Type | Byte 1 | V0 | V1 | V2 |
|------|--------|----|----|-----|
| Acceleration | 0x51 | ax | ay | az |
| Gyroscope | 0x52 | gx | gy | gz |
| Angle | 0x53 | roll | pitch | yaw |

## Scale Factors

| Measurement | Formula | Range |
|-------------|---------|-------|
| Acceleration | `raw / 32768.0 * 16.0` | +/-16g |
| Gyroscope | `raw / 32768.0 * 2000.0` | +/-2000 deg/s |
| Angle | `raw / 32768.0 * 180.0` | +/-180 deg |
| Temperature | `raw / 340.0 + 36.25` | Celsius |

## Known Quirks

- **Boot time**: Module needs ~200-500ms after power-on before sending valid data
- **Config at wrong baud**: Commands sent at wrong baud rate are ignored (garbled bytes) - this is actually useful for idempotent config-on-boot
- **AltSoftSerial at 115200**: Technically out of spec for 16MHz AVR, but TX-only bursts of a few bytes work fine. Don't try sustained RX at that rate.

## Commands

All commands are 3 bytes: `0xFF 0xAA <data>`

| Data Byte | Function | Notes |
|-----------|----------|-------|
| 0x52 | Zero Z-axis angle | Resets yaw to 0 |
| 0x67 | Accelerometer calibration | Keep module level, zeros X/Y |
| 0x60 | Toggle sleep mode | Toggles between standby and active |
| 0x61 | Serial mode | Enable UART, disable I2C |
| 0x62 | I2C mode | Enable I2C, disable UART |
| 0x63 | 115200 baud / 100Hz | Factory default |
| 0x64 | 9600 baud / 20Hz | Our config |
| 0x65 | Horizontal mounting | Module placed flat |
| 0x66 | Vertical mounting | Module placed upright |
