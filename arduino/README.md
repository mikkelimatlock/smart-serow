# Arduino

Sensor interface running on Arduino Nano, communicating with Pi via UART.

## Sketches

| Folder | Purpose |
|--------|---------|
| `main/` | Primary telemetry sketch |

## Current Capabilities

- Battery voltage monitoring (voltage divider on A0)
- Serial output at 9600 baud, 1Hz update rate

## Planned

- RPM sensing (pulse counting from ignition coil)
- Engine temperature (thermocouple/NTC)
- Gear position indicator
- Turn signal / high beam status

## Hardware

- **MCU**: Arduino Nano (ATmega328P)
- **Connection**: UART to Pi GPIO (TX→RX, RX→TX, common GND)
- **Voltage sensing**: Resistor divider scaled for 0-20V input range

## Protocol

Simple text-based for now:
```
V_bat: 12.45V
```

Future: structured binary or JSON for multiple sensors.
