"""Smart Serow Backend - GPS and Arduino services with HTTP API and WebSocket."""

from gevent import monkey
monkey.patch_all()  # Must be at the very top before other imports

from flask import Flask, jsonify
from flask_socketio import SocketIO, emit

from gps_service import GPSService
from arduino_service import ArduinoService
from throttle import Throttle

app = Flask(__name__)
app.config["SECRET_KEY"] = "smartserow-secret"  # Not security critical, just for session

# SocketIO with gevent async mode (eventlet is deprecated)
socketio = SocketIO(app, async_mode="gevent", cors_allowed_origins="*")

# Services
gps = GPSService()
arduino = ArduinoService()

# Throttles for emission rate limiting (20Hz for arduino, 1Hz for GPS)
arduino_throttle = Throttle(min_interval=0.05)  # 20Hz max
gps_throttle = Throttle(min_interval=1.0)      # 1Hz max

# Track connected clients
connected_clients = set()


# -----------------------------------------------------------------------------
# WebSocket Event Handlers
# -----------------------------------------------------------------------------

@socketio.on("connect")
def handle_connect():
    """Client connected."""
    client_id = id(socketio)  # Simple identifier
    connected_clients.add(client_id)
    print(f"[WS] Client connected ({len(connected_clients)} total)")

    # Send current status immediately
    emit("status", {
        "gps_connected": gps.connected,
        "arduino_connected": arduino.connected,
    })

    # Send latest data if available
    arduino_data = arduino.get_latest()
    if "error" not in arduino_data:
        emit("arduino", arduino_data)

    gps_data = gps.get_latest()
    if "error" not in gps_data:
        emit("gps", gps_data)


@socketio.on("disconnect")
def handle_disconnect():
    """Client disconnected."""
    client_id = id(socketio)
    connected_clients.discard(client_id)
    print(f"[WS] Client disconnected ({len(connected_clients)} remaining)")


@socketio.on("button")
def handle_button(data):
    """Handle button press from UI.

    Expected data: {"id": "horn", "action": "press", ...params}
    """
    btn_id = data.get("id", "unknown")
    action = data.get("action", "press")
    params = {k: v for k, v in data.items() if k not in ("id", "action")}

    print(f"[WS] Button: {btn_id} {action} {params}")

    # Map button ID to Arduino command
    cmd_map = {
        "horn": "HORN",
        "light": "LIGHT",
        "indicator_left": "IND_L",
        "indicator_right": "IND_R",
        "hazard": "HAZARD",
    }

    cmd = cmd_map.get(btn_id)
    if cmd:
        # Add action to params (e.g., ON/OFF based on press/release)
        params["state"] = "ON" if action == "press" else "OFF"
        success = arduino.send_command(cmd, params)

        # Send immediate ack for the attempt
        emit("ack", {
            "id": btn_id,
            "status": "sent" if success else "failed",
            "error": None if success else "arduino not connected",
        })
    else:
        emit("ack", {
            "id": btn_id,
            "status": "error",
            "error": f"unknown button: {btn_id}",
        })


@socketio.on("emergency")
def handle_emergency(data):
    """Handle emergency signal from UI."""
    etype = data.get("type", "stop")
    print(f"[WS] EMERGENCY: {etype}")

    # Send emergency command to Arduino
    arduino.send_command("EMERGENCY", {"type": etype})

    # Broadcast alert to all clients
    socketio.emit("alert", {
        "type": "emergency",
        "message": f"Emergency {etype} triggered",
    })


# -----------------------------------------------------------------------------
# Service Callbacks (push data to WebSocket)
# -----------------------------------------------------------------------------

def on_arduino_data(data):
    """Called by ArduinoService when new telemetry arrives."""
    def emit_fn(d):
        socketio.emit("arduino", d)

    arduino_throttle.maybe_emit(data, emit_fn)


def on_gps_data(data):
    """Called by GPSService when new fix arrives."""
    def emit_fn(d):
        socketio.emit("gps", d)

    gps_throttle.maybe_emit(data, emit_fn)


def on_arduino_ack(cmd, status, extra):
    """Called by ArduinoService when ACK received from Arduino."""
    socketio.emit("ack", {
        "id": cmd.lower(),
        "status": status.lower(),
        "extra": extra,
    })


# -----------------------------------------------------------------------------
# Background task to flush pending throttled data
# -----------------------------------------------------------------------------

def throttle_flusher():
    """Periodically flush pending throttled data."""
    import gevent
    while True:
        gevent.sleep(0.05)  # 20Hz flush rate

        if arduino_throttle.has_pending:
            arduino_throttle.flush(lambda d: socketio.emit("arduino", d))

        if gps_throttle.has_pending:
            gps_throttle.flush(lambda d: socketio.emit("gps", d))


# -----------------------------------------------------------------------------
# REST API (backward compatibility)
# -----------------------------------------------------------------------------

@app.route("/health")
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "ok",
        "gps_connected": gps.connected,
        "arduino_connected": arduino.connected,
        "ws_clients": len(connected_clients),
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


# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------

def main():
    """Entry point."""
    # Wire up callbacks
    arduino.set_on_data(on_arduino_data)
    arduino.set_on_ack(on_arduino_ack)
    gps.set_on_data(on_gps_data)

    # Start services
    gps.start()
    arduino.start()

    # Start throttle flusher in background
    socketio.start_background_task(throttle_flusher)

    try:
        # Use socketio.run() instead of app.run() for WebSocket support
        print("[Backend] Starting on http://0.0.0.0:5000")
        socketio.run(app, host="0.0.0.0", port=5000, debug=False)
    finally:
        arduino.stop()
        gps.stop()


if __name__ == "__main__":
    main()
