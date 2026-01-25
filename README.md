# Smart Serow

Pi Zero 2W + Arduino Nano motorcycle info terminal.

## Architecture

```
┌─────────────────┐      ┌─────────────────┐
│  Arduino Nano   │──────│  Pi Zero 2W     │
│  (sensors)      │ UART │  (Flutter UI)   │──── Display
└─────────────────┘      └─────────────────┘
```

- **Pi Zero 2W**: Runs Flutter UI via DRM/KMS (direct framebuffer, no X11)
- **Arduino Nano**: Sensor interface (future)

## Project Structure

```
smart-serow/
├── arduino/                # Arduino sketches (sensor interface)
├── extra/                  # Assets deployed alongside app
│   ├── fonts/              # Custom fonts
│   ├── images/             # Static images
│   └── themes/             # Theme JSON files (→ generate_theme.py)
├── pi/
│   └── ui/                 # Flutter app
│       ├── lib/
│       │   ├── main.dart           # Entry point
│       │   ├── app_root.dart       # Screen state management
│       │   ├── screens/            # Full-screen views
│       │   ├── widgets/            # Reusable components
│       │   ├── services/           # Singletons (config, sensors, theme)
│       │   └── theme/              # Colors and theme provider
│       └── config.json             # Runtime config (navigator, paths)
├── scripts/                # Build, deploy, and setup helpers
└── pi_sysroot/             # Pi libraries for cross-linking (gitignored)
```

## Theme System

The UI uses JSON-based themes for different navigator models.

- **Theme files**: `extra/themes/{navigator}.json` (e.g., `extra/themes/zumo.json`)
- **Generation**: `scripts/generate_theme.py` converts JSON → `pi/ui/lib/theme/app_colors.dart`
- **Auto-generation**: `build.py` runs theme generation before each Flutter build
- **Fallback chain**: Tries `{navigator}.json` → `default.json` → hardcoded defaults

To add a new theme, create `extra/themes/yourmodel.json` and set `"navigator": "yourmodel"` in `pi/ui/config.json`.

---

## Build Environment Setup (WSL2)

### Requirements

- **WSL2 with Debian Trixie** (glibc 2.38)
- **flutter-elinux**: <https://github.com/aspect-apps/flutter-elinux>
- **ARM64 cross-compiler**:
  ```bash
  sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu
  ```

### Pi Sysroot (for cross-linking)

The ARM64 linker needs Pi's shared libraries to resolve symbols at link time.
These don't execute locally - the linker just reads their symbol tables.

**On the Pi**, grab the libs:
```bash
tar czf pi_libs.tar.gz \
    /lib/aarch64-linux-gnu \
    /usr/lib/aarch64-linux-gnu
```

**In WSL2**, extract to project root:
```bash
mkdir -p pi_sysroot
tar xzf pi_libs.tar.gz -C pi_sysroot --strip-components=1
```

Key libraries needed:
- libxkbcommon, libEGL, libdrm, libgbm, libinput
- libudev, libsystemd, libfontconfig

---

## Target Environment (Pi Zero 2W)

### Requirements

- **Debian Trixie** (glibc 2.38 - must match build host!)
- Display connected via HDMI/DSI

### First-Time Setup

```bash
# Copy scripts to Pi
scp scripts/pi_setup.sh scripts/smartserow-ui.service user@pi.local:~/

# Run setup on Pi
ssh user@pi.local
chmod +x pi_setup.sh
./pi_setup.sh
```

This installs:
- Runtime dependencies (libgl, libgles, libdrm, libgbm, libinput, fonts)
- Systemd service for auto-start
- User permissions for DRM/KMS access

---

## Build & Deploy

### One-liner (recommended)

```bash
python3 scripts/build-deploy.py          # Build, deploy, restart
python3 scripts/build-deploy.py --clean  # Clean build first
python3 scripts/build-deploy.py --no-restart  # Don't restart service
```

### Individual scripts

```bash
# Build only
python3 scripts/build.py
python3 scripts/build.py --clean

# Deploy only
python3 scripts/deploy.py
python3 scripts/deploy.py --restart
```

Build output: `pi/ui/build/elinux/arm64/release/bundle/`

### Deploy config

Copy and edit `scripts/deploy_target.sample.json` → `scripts/deploy_target.json`:
```json
{
  "user": "pi",
  "host": "raspberrypi.local",
  "remote_path": "/opt/smartserow",
  "service_name": "smartserow-ui"
}
```

### Verify

```bash
ssh user@pi.local 'systemctl status smartserow-ui'
ssh user@pi.local 'journalctl -u smartserow-ui -f'  # Live logs
```

---

## Display Backends

Flutter-elinux supports multiple backends. We use **GBM** (DRM/KMS direct).

| Backend | Use Case | Notes |
|---------|----------|-------|
| `gbm` | Production | Direct framebuffer, fast boot, no X11 |
| `x11` | Debug | Needs X server, mouse/keyboard friendly |
| `wayland` | - | Requires compositor, more dependencies |

The backend is compiled in (we build with `--target-backend-type=gbm`).
The `-b` flag is for bundle path, not backend selection.

For X11 debugging, you'd need to rebuild with `--target-backend-type=x11`.

---

## Known Issues / Gotchas

### glibc version mismatch
Build host and Pi must have matching glibc. We use Debian Trixie on both.
Symptom: `GLIBC_2.xx not found` at runtime.

### CMake caches compiler
If you change cross-compiler settings, run `./scripts/build.sh --clean`.

### flutter-elinux generates all platforms
The `flutter-elinux create` command scaffolds android/ios/web/etc.
These are gitignored - we only need `elinux/` and `linux/`.

### Libs not found at runtime
If `libflutter_engine.so` not found, check `LD_LIBRARY_PATH` in the service file.
Should point to `/opt/smartserow/bundle/lib`.

---

## Development Tips

### Local testing (Linux desktop)
```bash
cd pi/ui
flutter-elinux run -d linux
```

### Check what a binary needs
```bash
# On Pi
ldd /opt/smartserow/bundle/smartserow_ui
```

### Pi service management
```bash
sudo systemctl start smartserow-ui
sudo systemctl stop smartserow-ui
sudo systemctl restart smartserow-ui
journalctl -u smartserow-ui -f
```