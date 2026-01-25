# Extra Assets

Runtime assets deployed alongside the Flutter app. Not bundled into the binary — loaded from disk at runtime via paths in `config.json`.

## Structure

```
extra/
├── fonts/          # Custom fonts (TTF/OTF)
├── images/         # Static images
│   └── navigator/  # Navigator character sprites
│       └── {name}/ # Folder per navigator (e.g., "zumo", "rei")
│           ├── default.png
│           ├── happy.png
│           ├── surprise.png
│           └── ...
└── themes/         # Color theme definitions
```

## Themes

JSON files defining dark/bright color schemes. Converted to Dart by `scripts/generate_theme.py`.

### Format

```json
{
  "dark": {
    "background": "#101010",
    "foreground": "#EAEAEA",
    "highlight": "#FA1504",
    "subdued": "#E47841"
  },
  "bright": {
    "background": "#E47841",
    "foreground": "#202020",
    "highlight": "#F0F0F0",
    "subdued": "#BC4600"
  }
}
```

### Adding a Theme

1. Create `extra/themes/yournavigator.json`
2. Set `"navigator": "yournavigator"` in `pi/ui/config.json`
3. Build — `generate_theme.py` picks it up automatically

### Fallback Chain

`{navigator}.json` → `default.json` → hardcoded defaults
