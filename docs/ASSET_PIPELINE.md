# Asset Pipeline (Post-MVP)

This guide defines the first stable asset integration pass for Void Relay.

## 1) Folder Structure

Use this runtime structure:

- `assets/sprites/player/`
- `assets/sprites/enemies/`
- `assets/sprites/world/`
- `assets/audio/sfx/`
- `assets/shaders/`

## 2) Required Sprite Sheets (Phase 1)

### Player
- Path: `assets/sprites/player/player_sheet.png`
- Frame size: `32x64`
- Rows:
  - Row 0: `idle` (4 frames)
  - Row 1: `run` (4 frames)
  - Row 2: `jump` (2 frames)
  - Row 3: `dash` (2 frames)

### Crawler
- Path: `assets/sprites/enemies/crawler_sheet.png`
- Frame size: `32x32`
- Rows:
  - Row 0: `idle` (2 frames)
  - Row 1: `move` (4 frames)
  - Row 2: `attack` (3 frames)

### Hover Drone
- Path: `assets/sprites/enemies/hover_drone_sheet.png`
- Frame size: `24x24`
- Rows:
  - Row 0: `idle` (2 frames)
  - Row 1: `patrol` (4 frames)
  - Row 2: `chase` (3 frames)

### Sentry Turret
- Path: `assets/sprites/enemies/sentry_turret_sheet.png`
- Frame size: `32x32`
- Rows:
  - Row 0: `idle` (2 frames)
  - Row 1: `alert` (3 frames)

## 3) Integration Rules

1. Do not change movement/collision/gameplay logic during sprite hookup.
2. Keep fallback rendering enabled while assets are incomplete.
3. Integrate one entity at a time and verify in runtime.
4. Commit in small steps: Player -> Crawler -> HoverDrone -> SentryTurret.

## 4) Quick Validation Checklist

- Game starts without crash if one sheet is missing.
- Entity shows animation states in gameplay.
- No collision or camera behavior changed by visual updates.
- Existing regression tests still pass.

## 5) Suggested Commands

```powershell
flutter pub get
flutter test test/player_double_jump_test.dart
flutter test test/enemy_double_movement_test.dart
flutter test test/player_platform_collision_regression_test.dart
```

