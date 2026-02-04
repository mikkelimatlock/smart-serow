# Scripts

Build, deploy, and setup helpers for the Smart Serow project.

## UI Build & Deploy

| Script | Purpose |
|--------|---------|
| `build.py` | Cross-compile Flutter app for ARM64. Runs `generate_theme.py` first. |
| `deploy.py` | rsync UI bundle to Pi, optionally restart service |
| `build-deploy.py` | Convenience wrapper: build → deploy → restart |

```bash
python3 build.py              # Build only
python3 deploy.py --restart   # Deploy and restart service
python3 build-deploy.py       # All-in-one
python3 build.py --clean      # Clean rebuild
```

## Backend Deploy

| Script | Purpose |
|--------|---------|
| `deploy_backend.py` | rsync Python backend to Pi, optionally restart service |

```bash
python3 deploy_backend.py             # Deploy only
python3 deploy_backend.py --restart   # Deploy and restart service
```

Backend and UI are **completely independent** — separate paths, separate services, separate deploys.

## Theme Generation

| Script | Purpose |
|--------|---------|
| `generate_theme.py` | Converts `extra/themes/*.json` → `pi/ui/lib/theme/app_colors.dart` |

Called automatically by `build.py`. Looks for theme matching `navigator` in `config.json`, falls back to `default.json`.

## Pi Setup

| Script | Purpose |
|--------|---------|
| `pi_setup.sh` | First-time Pi config for UI (deps, permissions, systemd) |
| `pi_setup_backend.sh` | First-time Pi config for backend (uv, gpsd, systemd) |
| `smartserow-ui.service.sample` | UI systemd unit template |
| `smartserow-backend.service.sample` | Backend systemd unit template |
| `smartserow-ui.service` | Production UI systemd unit (gitignored, Pi-specific) |
| `smartserow-backend.service` | Production backend systemd unit (gitignored, Pi-specific) |

```bash
# On the Pi - UI setup
chmod +x pi_setup.sh
./pi_setup.sh

# On the Pi - Backend setup (independent)
chmod +x pi_setup_backend.sh
./pi_setup_backend.sh
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
  "service_name": "smartserow-ui",
  "assets_path": "~/smartserow-ui/assets",
  "backend_path": "/opt/smartserow-backend",
  "backend_service": "smartserow-backend"
}
```

## Shell vs Python

Both `.sh` and `.py` versions exist for some scripts. The Python versions are more robust (better error handling, colored output). Use those.
