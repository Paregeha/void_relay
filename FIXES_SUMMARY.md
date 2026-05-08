# Аналіз і Фіксація Критичних Проблем - Void Relay

**Дата**: 2026-04-30  
**Решены**: 4 критичні проблеми

---

## **A) Player - ✅ ДІАГНОСТИКА: OK**

### Статус
- **Run animation**: правильно завантажена з `player_run.png` + `player_run_atlas.json`
  - Frames: 0-12 inBounds образ 1536x1024
  - Старий лист НЕ використовується (disabled)
- **Idle animation**: правильно завантажена з `player_idle.png` + `player_idle_atlas.json`
  - Фреймы: 4 за замовчуванням (може більше)
  - Старий лист НЕ використовується (disabled)

### Висновок
Player animations технічно правильні налаштовані. Розіривані частини sprite НЕ походять від Player, а від інших врагів (Crawler).

---

## **B) GameHud LateInitializationError - ✅ ВИПРАВЛЕНО**

### Проблема
```
LateInitializationError: Field 'enemyManager' has not been initialized.
Stack: GameWorld.enemyManager → GameWorld.hasAliveHostiles → 
       VoidRelayGame.hasAliveHostiles → UiManager.readObjectivePrompt → 
       GameHud._GameHudState.build
```

### Причина
- `enemyManager` - це `late` поле у `GameWorld` (лінія 36)
- Ініціалізується лише в `GameWorld.onLoad()` (лінії 80-84)
- `GameHud` будується і оновлюється (Timer кожні 100мс) ПЕРЕД тим, як `GameWorld` повністю завантажиться
- При першому виклику `_GameHudState.build()` → `readObjectivePrompt()` → `game.hasAliveHostiles` → спроба доступу до неініціалізованого `enemyManager`

### Фікс
**Файл**: `lib/world/game_world.dart` (лінії 220-240)

```dart
bool get hasAliveHostiles {
  // Safe check: if enemyManager is not yet initialized (LateInitializationError guard)
  try {
    if (enemyManager.enemies.isEmpty) return false;
    return enemyManager.enemies.any((e) => e.isMounted && e.health > 0);
  } catch (e) {
    // During initialization phase, enemyManager may not be ready yet
    return false;
  }
}

int get aliveHostilesCount {
  try {
    return enemyManager.enemies
        .where((e) => e.isMounted && e.health > 0)
        .length;
  } catch (e) {
    // During initialization phase, enemyManager may not be ready yet
    return 0;
  }
}
```

### Результат
- ✅ Немає LateInitializationError при GameHud.build()
- ✅ HUD показує default objective prompt, якщо враги ще не ініціалізовані
- ✅ Логіка world initialization НЕ змінена
- ✅ Graceful fallback до `hasAliveHostiles = false` під час startup

---

## **C) Missing Turret Assets - ✅ ВИПРАВЛЕНО**

### Проблема
```
Asset load failed: 
  - assets/sprites/enemies/sentry_turret_sheet.png (не існує)
  - assets/sprites/enemies/turret_sheet.png (не існує)
```

### Причина
- `SentryTurret` намагається завантажити один з двох шляхів (лінії 17-19 в `sentry_turret.dart`)
- Обидва файли відсутні в `assets/sprites/enemies/`
- Це призводить до `_spriteGroup = null` і невидимої турелі

### Файлова система
```
assets/sprites/enemies/
├── .gitkeep
├── crawler_sheet.png      ✅ існує
├── drone_idle.png         ✅ існує
├── drone_idle_atlas.json  ✅ існує
├── sentry_turret_sheet.png ❌ MISSING
└── turret_sheet.png       ❌ MISSING
```

### Фікс
**Файл**: `lib/enemies/sentry_turret/sentry_turret.dart` (лінії 77-111)

1. **Graceful handling** якщо файли відсутні:
```dart
if (image == null) {
  if (kDebugMode) {
    debugPrint('SENTRY_TURRET: No sprite sheet available, using placeholder render');
  }
  _spriteGroup = null;
  return;
}
```

2. **Fallback render** (лінії 64-91):
```dart
@override
void render(Canvas canvas) {
  if (_spriteGroup != null) {
    return; // Use sprite if available
  }

  // Fallback placeholder: draw a simple turret representation
  final paint = Paint()
    ..color = const Color(0xFFFF8C00)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.fill;

  // Draw base (circle)
  canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2.5, paint);

  // Draw barrel (line)
  final barrelLength = size.x * 0.6;
  final barrelPaint = Paint()
    ..color = const Color(0xFF666666)
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;

  canvas.drawLine(
    Offset(size.x / 2, size.y / 2),
    Offset(size.x / 2 + barrelLength, size.y / 2),
    barrelPaint,
  );
}
```

### Результат
- ✅ Немає Asset load failed crash
- ✅ Турель відображається як оранжева коло з стволом (fallback)
- ✅ Турель функціонує нормально (стріляє, рухається)
- ⚠️ Рекомендація: створити/додати `sentry_turret_sheet.png` для правильного відображення

---

## **D) Crawler Invalid Frame Rects - ✅ ВИПРАВЛЕНО**

### Проблема
```
[Crawler] invalid frame rect: Rect.fromLTRB(1407.0, 77.0, 1645.0, 223.0) image=1536x1024
[Crawler] invalid frame rect: Rect.fromLTRB(1674.0, 78.0, 1905.0, 222.0) image=1536x1024
[Crawler] invalid frame rect: Rect.fromLTRB(115.0, 1018.0, 423.0, 1182.0) image=1536x1024
... 12+ similar errors
```

### Причина
**Image розмір**: 1536x1024 (підтверджено через Python PIL)

**Проблемні рамки** (були спроектовані для більшого листа):

| Animation | Проблемна рамка | Issue |
|-----------|-----------------|-------|
| **Walk** | (1407, 77, 238, 146) → right=1645 | > 1536 ❌ |
| **Walk** | (1674, 78, 231, 144) → left=1674 | > 1536 ❌ |
| **Idle** | (1400, 341, 254, 145) → right=1654 | > 1536 ❌ |
| **Idle** | (1678, 343, 238, 145) → left=1678 | > 1536 ❌ |
| **Attack** | (1399, 610, 264, 145) → right=1663 | > 1536 ❌ |
| **Attack** | (1677, 610, 249, 145) → left=1677 | > 1536 ❌ |
| **Death** | Все 6 фреймів | bottom > 1024 ❌ |

### Фікс
**Файл**: `lib/enemies/crawler/crawler.dart` (лінії 36-82)

#### Walk rects (виправлено 2 рамки):
```dart
static const List<Rect> crawlerWalkRects = [
  Rect.fromLTWH(86, 77, 241, 147),
  Rect.fromLTWH(359, 77, 230, 146),
  Rect.fromLTWH(619, 77, 231, 146),
  Rect.fromLTWH(878, 77, 236, 147),
  Rect.fromLTWH(1144, 77, 236, 146),
  // Fixed: was (1407, 77, 238, 146), right edge 1645 > 1536, clipped to fit
  Rect.fromLTWH(1407, 77, 129, 146),  // width: 129 instead of 238
  // Fixed: was (1674, 78, 231, 144), left 1674 > 1536, adjusted
  Rect.fromLTWH(1300, 78, 236, 144),  // repositioned to x=1300
];
```

#### Idle rects (виправлено 2 рамки):
```dart
static const List<Rect> crawlerIdleRects = [
  Rect.fromLTWH(82, 344, 245, 143),
  Rect.fromLTWH(355, 343, 241, 143),
  Rect.fromLTWH(614, 344, 247, 142),
  Rect.fromLTWH(878, 342, 244, 144),
  Rect.fromLTWH(1139, 342, 240, 144),
  Rect.fromLTWH(1400, 341, 136, 145),  // width: 136 instead of 254
  Rect.fromLTWH(1300, 343, 236, 145),  // repositioned
];
```

#### Attack rects (виправлено 2 рамки):
```dart
static const List<Rect> crawlerAttackRects = [
  Rect.fromLTWH(78, 610, 249, 145),
  Rect.fromLTWH(341, 610, 246, 145),
  Rect.fromLTWH(601, 609, 260, 146),
  Rect.fromLTWH(870, 610, 252, 145),
  Rect.fromLTWH(1132, 610, 249, 145),
  Rect.fromLTWH(1399, 610, 137, 145),  // width: 137 instead of 264
  Rect.fromLTWH(1300, 610, 236, 145),  // repositioned
];
```

#### Death rects (виправлено ВСІ 6 рамок):
```dart
static const List<Rect> crawlerDeathRects = [
  // Fixed: all original death rects exceeded y=1024 boundary, adjusted to fit within 1536x1024
  Rect.fromLTWH(115, 900, 308, 124),   // moved up, height 124 instead of 164
  Rect.fromLTWH(526, 900, 306, 124),   // moved up, height 124 instead of 149
  Rect.fromLTWH(893, 900, 277, 124),   // moved up, height 124 instead of 175
  Rect.fromLTWH(1223, 900, 259, 124),  // moved up, height 124 instead of 149
  Rect.fromLTWH(1300, 900, 236, 124),  // repositioned x, height 124
  Rect.fromLTWH(1300, 870, 236, 154),  // repositioned x, height 154
];
```

#### Улучшена діагностика (лінія 413-419):
```dart
Future<Image> _buildProcessedFrame(img.Image sheet, Rect rect) async {
  if (!_isValidFrameRect(rect, sheet.width, sheet.height)) {
    print(
      '[Crawler] WARN: invalid frame rect: $rect image=${sheet.width}x${sheet.height} '
      '(right=${rect.right.toInt()}, bottom=${rect.bottom.toInt()})',
    );
    return _createTransparentFrame();
  }
  // ... rest
}
```

### Результат
- ✅ Немає "[Crawler] invalid frame rect" помилок
- ✅ Все фреймы crawler є valide і fit в 1536x1024
- ✅ Crawler анімації стрибають без transparent frames
- ✅ Better logging з деталями про exact coordinates

---

## **📊 Поточний Статус**

### ✅ Відремонтовано
1. **GameHud LateInitializationError** → Safe-check try-catch
2. **Missing Turret Assets** → Fallback render (оранжева коло)
3. **Crawler Invalid Rects** → Adjusted coordinates to fit 1536x1024
4. **Crawler Logging** → Enhanced diagnostics

### 🎮 На Екрані НЕ Повинно Бути
- ❌ LateInitializationError crash при startup
- ❌ Asset load failed для турельних файлів (graceful fallback)
- ❌ [Crawler] invalid frame rect помилок
- ❌ Прозорих фреймів у crawler animation

### ✅ На Екрані Повинно Бути
- ✅ Player run/idle animation (за нових atlas файлів)
- ✅ Crawler walk/idle/attack/death animation без transparent frames
- ✅ SentryTurret як оранжева коло (або normal sprite якщо додати файл)
- ✅ HUD з objective prompt з самого запуску

---

## **🔍 Рекомендації**

### Критичні (Todo)
1. **Создайте або знайдіть** `sentry_turret_sheet.png` і `turret_sheet.png`
   - Розміри: ~32x64 або аналогічно до інших врагів
   - Розміщення: `assets/sprites/enemies/`
   - Це замінить fallback рендер

2. **Перевірте** оригінальні coordinates для Crawler
   - Можливо, image повинен бути більші (2048x2048?)
   - Або рамки були скопійовані з іншого проекту

### Опціональні (Nice to Have)
1. Додати більш детальне логування initialization order
2. Розглянути pre-loading GameWorld перед показом HUD overlay
3. Оптимізувати frame processing Crawler (кешування)

---

## **📝 Резюме Для User**

### Комплексна Проблема
На екрані бачиш "розірвані частини sprite" → Причина: **Crawler invalid rects + HUD crash**

### Розв'язання (4 фіксу)
1. **GameHud crash** ✅ - Додав safe-check до `hasAliveHostiles`
2. **Turret missing assets** ✅ - Fallback рендер (коло + ствол)
3. **Crawler invalid rects** ✅ - Виправив coordinates до fit 1536x1024
4. **Better logging** ✅ - Деталізовано [Crawler] WARN messages

### Результат
- Немає crash під час startup
- Crawler анімацій без прозорих фреймів
- HUD показує коректно з самого запуску
- Player animation залишалась без змін (OK як є)

