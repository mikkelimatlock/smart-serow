# Backend

Python GPS and Arduino telemetry service for Smart Serow. Connects to `gpsd` and Arduino serial, buffers data, exposes HTTP API.

## Setup

```bash
# Install uv if you haven't
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
cd pi/backend
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

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check, shows gpsd and Arduino connection status |
| `GET /gps` | Latest GPS fix (lat, lon, alt, speed, track) |
| `GET /gps/history` | Last 100 buffered GPS positions |
| `GET /arduino` | Latest Arduino telemetry (voltage, rpm, eng_temp, gear) |
| `GET /arduino/history` | Last 100 buffered Arduino readings |

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

Both services run in stub mode for UI testing without hardware.

## Deploy

TODO: Add to `scripts/deploy.py` as second target + systemd service.
