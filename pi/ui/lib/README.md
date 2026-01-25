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
| `PiIO` | Pi hardware interface (CPU temp, future GPIO) |
| `OverheatMonitor` | Polls temp, fires callback when threshold exceeded |
| `ThemeService` | Dark/bright mode state, notifies listeners |
| `TestFlipFlopService` | Debug: toggles theme + navigator emotion every 2s |

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
