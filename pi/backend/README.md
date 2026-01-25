# Backend

Python GPS service for Smart Serow. Connects to `gpsd`, buffers positions, exposes HTTP API.

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
| `GET /health` | Health check, shows gpsd connection status |
| `GET /gps` | Latest GPS fix (lat, lon, alt, speed, track) |
| `GET /gps/history` | Last 100 buffered positions |

## Test from SSH

```bash
curl http://localhost:5000/health
curl http://localhost:5000/gps
curl http://localhost:5000/gps/history | jq
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

## Stub Mode

If `gpsdclient` isn't installed or gpsd isn't running, the service generates fake GPS data for UI testing.

## Deploy

TODO: Add to `scripts/deploy.py` as second target + systemd service.
