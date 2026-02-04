# Backend

Python GPS and Arduino telemetry service for Smart Serow. Connects to `gpsd` and Arduino serial, buffers data, exposes HTTP API.

## Setup

```bash
# Install uv if you haven't
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install system dependencies (GPIO)
sudo apt install python3-rpi.gpio

# Create venv with access to system packages, then sync
cd pi/backend
uv venv --system-site-packages
uv sync
```

## Run

```bash
uv run python main.py
```

Or for development:
```bash
uv run flask --app main run --host 0.0.0.0 --port 5000 --reload
```

## API

### HTTP Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check, shows gpsd and Arduino connection status |
| `GET /gps` | Latest GPS fix (lat, lon, alt, speed, track) |
| `GET /gps/history` | Last 100 buffered GPS positions |
| `GET /arduino` | Latest Arduino telemetry (voltage, rpm, eng_temp, gear) |
| `GET /arduino/history` | Last 100 buffered Arduino readings |

### WebSocket Events (socket.io)

Real-time data is pushed over WebSocket. The UI connects once and receives streams.

**Server → Client:**

| Event | Description |
|-------|-------------|
| `arduino` | Real-time telemetry (voltage, rpm, roll, pitch, accel, etc.) |
| `gps` | GPS position updates |
| `status` | Connection status + `theme_switch` signal from GPIO |
| `alert` | System alerts |
| `ack` | Command acknowledgments |

**Client → Server:**

| Event | Description |
|-------|-------------|
| `button` | UI button presses (horn, light, indicators, hazard) |
| `emergency` | Emergency signal |

### Throttling

WebSocket data is rate-limited to prevent flooding:

- **Arduino data**: 20Hz max
- **GPS data**: 1Hz max

## Test from SSH

```bash
curl http://localhost:5000/health
curl http://localhost:5000/gps
curl http://localhost:5000/gps/history | jq
curl http://localhost:5000/arduino
curl http://localhost:5000/arduino/history | jq
```

## gpsd Setup (Pi)

```bash
# Install
sudo apt install gpsd gpsd-clients

# Configure (edit DEVICES to match your GPS serial port)
sudo nano /etc/default/gpsd

# Example /etc/default/gpsd:
# DEVICES="/dev/ttyUSB0"
# GPSD_OPTIONS="-n"
# START_DAEMON="true"

# Restart
sudo systemctl restart gpsd

# Test gpsd directly
gpsmon
cgps -s
```

## Arduino Setup (Pi)

The Arduino Nano connects via USB serial (typically `/dev/ttyUSB0` or `/dev/ttyACM0`).

```bash
# Check available ports
ls /dev/tty*

# May need dialout group for serial access
sudo usermod -aG dialout $USER
# Then log out and back in
```

### Arduino Protocol

**Production format (JSON at 115200 baud):**
```json
{"v":12.45,"rpm":4500,"eng":85,"gear":3}
```

**Legacy text format (also supported):**
```
V_bat: 12.45V
RPM: 4500
ENG: 85C
```

The parser tries JSON first, falls back to regex for legacy format.

### Configuring the Port

Edit `main.py` to change the default port:
```python
arduino = ArduinoService(port="/dev/ttyACM0", baudrate=115200)
```

## Stub Mode

- **GPS**: If `gpsdclient` isn't installed or gpsd isn't running, generates fake GPS data
- **Arduino**: If `pyserial` isn't installed or serial port unavailable, generates fake telemetry
- **GPIO**: If `RPi.GPIO` isn't available, runs in mock mode (always returns default state)

All services run in stub mode for UI testing without hardware.

## GPIO Setup

The `gpio_service.py` handles physical switch inputs (e.g., theme toggle on GPIO20).

### Known Quirks

**Use apt-installed RPi.GPIO, not pip:**
```bash
sudo apt install python3-rpi.gpio
```

The pip version (`RPi.GPIO`) requires compilation with `python3-dev` headers. The apt package is pre-compiled and Just Works. The venv must be created with `--system-site-packages` to see it.

**gpiozero doesn't work (TODO):**

`gpiozero` is the "modern" GPIO library but has issues in this setup:
- Requires a pin factory backend (`lgpio`, `rpigpio`, `pigpio`, or `native`)
- `lgpio`/`rpi-lgpio` via pip needs `swig` to compile
- `native` backend breaks under gevent monkey-patching (`select.epoll` missing)
- May revisit if we need gpiozero-specific features

**Software pull-up/down conflicts with external resistors:**

If using an external pull-down resistor (especially high values like 1MΩ), disable the software pull:
```python
GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_OFF)
```

The Pi's internal pull-down (~50kΩ) will overpower high-value external resistors, causing unexpected voltage divider behavior.

**Debouncing:**

Physical switches/connectors need debouncing. Current implementation requires 15 consecutive identical readings (~750ms at 20Hz) before accepting a state change. Tune `required_consecutive` in `gpio_service.py` as needed.

## Deploy

TODO: Add to `scripts/deploy.py` as second target + systemd service.
