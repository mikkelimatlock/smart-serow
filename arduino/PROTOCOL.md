# Arduino-Pi Communication Protocol

Telemetry protocol for Arduino → Pi communication over UART at 115200 baud.

## Design Rationale

- **ASCII-based**: Human-debuggable, digits are self-bounding (no accidental header spoofing)
- **TSV format**: Tab delimiter, predictable field count, trivial to parse, survives floating decimals
- **Null-terminated**: `\0` (0x00) is unambiguous end-of-line, avoids CRLF headaches
- **10Hz rate**: ~50 bytes/line × 10Hz = 500 B/s, well under 115200 baud capacity (~4% utilization)

## Telemetry Frame (Arduino → Pi)

```
field0\tfield1\tfield2\t...\tfieldN\0
```

### Fields

| Index | Name   | Unit    | Description                    |
|-------|--------|---------|--------------------------------|
| 0     | V_bat  | V       | Battery voltage                |
| 1     | Ax     | g       | Acceleration X                 |
| 2     | Ay     | g       | Acceleration Y                 |
| 3     | Az     | g       | Acceleration Z                 |
| 4     | Gx     | deg/s   | Angular velocity X             |
| 5     | Gy     | deg/s   | Angular velocity Y             |
| 6     | Gz     | deg/s   | Angular velocity Z             |
| 7     | Roll   | deg     | Euler angle roll               |
| 8     | Pitch  | deg     | Euler angle pitch              |
| 9     | Yaw    | deg     | Euler angle yaw                |
| 10    | RPM    | RPM     | Engine RPM                     |
| 11    | Gear   | -       | Gear position (0=N, 1-6)       |

### Example

```
12.45\t0.02\t-0.01\t1.00\t0.50\t-0.25\t0.10\t2.35\t-1.20\t45.80\t3500\t3\0
```

## Stale Data Handling

When IMU data is stale, empty fields are sent to preserve field count:
```
12.45\t\t\t\t\t\t\t\t\t\0
```
Backend parses empty fields as null/NaN.

## Commands (Pi → Arduino)

TBD: Command structure for configuration, calibration triggers, etc.

## Versioning

Protocol changes should bump a version field or use a different frame header.
Currently unversioned (v0 / development).
