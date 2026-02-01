# Arduino

Sensor interface running on Arduino Nano, communicating with Pi via UART.

## Sketches

| Folder | Purpose |
|--------|---------|
| `main/` | Primary telemetry sketch |

## Current Capabilities

- Battery voltage monitoring (voltage divider on A0)
- WT61 IMU/gyro via AltSoftSerial (9-axis: accel, gyro, euler angles)
- Duplex UART to Pi at 115200 baud, 10Hz telemetry output
- Simple text-based protocol for easy debugging

## Dependencies

Install via Arduino Library Manager:
- **AltSoftSerial** by Paul Stoffregen - for WT61 IMU serial

## Pin Assignments

| Pin | Function |
|-----|----------|
| A0 | Battery voltage (via divider) |
| D0 (RX) | Pi UART RX ← Arduino TX |
| D1 (TX) | Pi UART TX → Arduino RX |
| D8 | WT61 IMU RX (AltSoftSerial) |
| D9 | WT61 IMU TX (unused, AltSoftSerial fixed pin) |
| D13 | Status LED (heartbeat) |

## Hardware

- **MCU**: Arduino Nano (ATmega328P)
- **Pi Connection**: UART at 115200 baud (TX→RX, RX→TX, common GND)
- **IMU**: WT61 module at 9600 baud, 20Hz output
- **Voltage sensing**: Resistor divider (100k/47k) scaled for 0-20V input

## Protocol

Simple text lines, one per sensor reading:
```
V_bat: 12.45
Ax: 0.02
Ay: -0.01
Az: 1.00
Gx: 0.50
Gy: -0.25
Gz: 0.10
Roll: 2.35
Pitch: -1.20
Yaw: 45.80
```

If IMU data is stale (no valid packets for 200ms):
```
IMU: STALE
```

Commands from Pi are echoed back:
```
ACK: PING
```

## Planned

- RPM sensing (pulse counting from ignition coil)
- Engine temperature (thermocouple/NTC)
- Gear position indicator
- Turn signal / high beam status
