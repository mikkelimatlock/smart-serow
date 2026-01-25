"""Smart Serow Backend - GPS service with HTTP API."""

from flask import Flask, jsonify
from gps_service import GPSService

app = Flask(__name__)
gps = GPSService()


@app.route("/health")
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "gps_connected": gps.connected})


@app.route("/gps")
def gps_data():
    """Current GPS data."""
    return jsonify(gps.get_latest())


@app.route("/gps/history")
def gps_history():
    """Buffered GPS history."""
    return jsonify(gps.get_buffer())


def main():
    """Entry point."""
    gps.start()
    try:
        # Host 0.0.0.0 for access from Flutter app
        app.run(host="0.0.0.0", port=5000, debug=False)
    finally:
        gps.stop()


if __name__ == "__main__":
    main()
