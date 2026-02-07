# Flutter App Structure

## Entry Flow

```
main.dart → AppThemeProvider → MaterialApp → AppRoot → Screen
```

## Folders

| Folder | Purpose |
|--------|---------|
| `screens/` | Full-screen views (splash, dashboard, overheat) |
| `widgets/` | Reusable components (stat_box, navigator) |
| `services/` | Singletons with business logic |
| `theme/` | Color definitions and runtime theme switching |

## Services

All services use singleton pattern with `ServiceName.instance`.

| Service | Role |
|---------|------|
| `ConfigService` | Loads `config.json`, exposes settings |
| `WebSocketService` | socket.io client, streams for arduino/gps/connection/debug, auto-reconnect |
| `PiIO` | Pi hardware interface (CPU temp) |
| `OverheatMonitor` | Polls temp, fires callback when threshold exceeded |
| `ThemeService` | Dark/bright mode state, notifies listeners |
| `TestFlipFlopService` | Debug: toggles theme + navigator emotion every 2s |

## Key Widgets

| Widget | Purpose |
|--------|---------|
| `NavigatorWidget` | Animated character with emotion states (images precached at startup) |
| `AccelGraph` | Real-time accelerometer visualization with gravity compensation |
| `GpsCompass` | GPS heading compass with rotating navigation icon and degree readout |
| `WhiskeyMark` | Gimbal-style horizon indicator using IMU roll/pitch |
| `SystemBar` | Top status bar (time, connection, Pi temp) |
| `StatBox` | Reusable metric display box |
| `DebugConsole` | Scrolling log overlay for diagnostics |

## Notes

- **Gravity compensation**: Accelerometer display subtracts 1g from Z-axis to show deviation from vertical
- **Navigator precaching**: All navigator images are loaded during splash screen to prevent frame drops
- **Theme switching**: Backend sends `theme_switch` via WebSocket status events (triggered by GPIO)

## Theme System

- `AppColors` — static color constants (dark/bright variants), auto-generated from JSON
- `AppTheme` — InheritedWidget providing runtime colors via `AppTheme.of(context)`
- `ThemeService` — singleton holding current mode, call `setDarkMode(bool)` or `toggle()`

Usage in widgets:
```dart
final theme = AppTheme.of(context);
backgroundColor: theme.background,
color: theme.foreground,
```

## Screen Lifecycle

`AppRoot` manages which screen is visible:
1. **SplashScreen** — during init sequence
2. **DashboardScreen** — normal operation
3. **OverheatScreen** — when `OverheatMonitor` triggers (leads to shutdown)
