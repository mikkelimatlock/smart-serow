"""Smart Serow Backend - GPS and Arduino services with HTTP API."""

from flask import Flask, jsonify
from gps_service import GPSService
from arduino_service import ArduinoService

app = Flask(__name__)
gps = GPSService()
arduino = ArduinoService()


@app.route("/health")
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "ok",
        "gps_connected": gps.connected,
        "arduino_connected": arduino.connected,
    })


@app.route("/gps")
def gps_data():
    """Current GPS data."""
    return jsonify(gps.get_latest())


@app.route("/gps/history")
def gps_history():
    """Buffered GPS history."""
    return jsonify(gps.get_buffer())


@app.route("/arduino")
def arduino_data():
    """Current Arduino telemetry (voltage, rpm, etc)."""
    return jsonify(arduino.get_latest())


@app.route("/arduino/history")
def arduino_history():
    """Buffered Arduino telemetry history."""
    return jsonify(arduino.get_buffer())


def main():
    """Entry point."""
    gps.start()
    arduino.start()
    try:
        # Host 0.0.0.0 for access from Flutter app
        app.run(host="0.0.0.0", port=5000, debug=False)
    finally:
        arduino.stop()
        gps.stop()


if __name__ == "__main__":
    main()
