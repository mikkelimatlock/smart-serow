# Scripts

Build, deploy, and setup helpers for the Smart Serow project.

## Build & Deploy

| Script | Purpose |
|--------|---------|
| `build.py` | Cross-compile Flutter app for ARM64. Runs `generate_theme.py` first. |
| `deploy.py` | rsync bundle to Pi, optionally restart service |
| `build-deploy.py` | Convenience wrapper: build → deploy → restart |

```bash
# Typical workflow
python3 build.py              # Build only
python3 deploy.py --restart   # Deploy and restart service
python3 build-deploy.py       # All-in-one

# Clean rebuild (clears CMake cache)
python3 build.py --clean
```

## Theme Generation

| Script | Purpose |
|--------|---------|
| `generate_theme.py` | Converts `extra/themes/*.json` → `pi/ui/lib/theme/app_colors.dart` |

Called automatically by `build.py`. Looks for theme matching `navigator` in `config.json`, falls back to `default.json`.

## Pi Setup

| Script | Purpose |
|--------|---------|
| `pi_setup.sh` | First-time Pi configuration (deps, permissions, systemd service) |
| `smartserow-ui.service.sample` | Systemd unit file template |

```bash
# On the Pi
chmod +x pi_setup.sh
./pi_setup.sh
```

## Configuration

| File | Purpose |
|------|---------|
| `deploy_target.sample.json` | Template for deploy settings |
| `deploy_target.json` | Your actual deploy config (gitignored) |

```json
{
  "user": "pi",
  "host": "raspberrypi.local",
  "remote_path": "/opt/smartserow",
  "service_name": "smartserow-ui"
}
```

## Shell vs Python

Both `.sh` and `.py` versions exist for some scripts. The Python versions are more robust (better error handling, colored output). Use those.
