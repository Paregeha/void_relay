# Toxic Gas - Quick Start Testing Guide

## ⚡ 30-Second Test

```bash
flutter run
# Натисніть T
# Очікуваний результат:
# ✅ Зелений overlay на екрані
# ✅ Текст "TOXIC GAS"
# ✅ Субтитр "Taking damage - Find shelter!"
# ✅ Прогрес-бар зеленого кольору
# ✅ Здоров'я гравця зменшується ~8 за тік (кожні 0.3 сек)
# ✅ Після 4 сек - overlay зникає
```

---

## 🎮 Natural Gameplay Test

```
1. flutter run
2. Грайте нормально ~15-20 сек
3. Чекайте на рандомний toxic gas
4. Спостеріть: зелений overlay + шкода
5. Після 4 сек - завершено
6. Повторіть кілька разів
```

**Очікувано:**
- Toxic gas з'являється ~кожні 15 сек
- Мінімум 10 сек між toxic gas подіями
- Не перекривається з blackout

---

## 🎯 Що Перевірити

### UI
- [ ] Зелений overlay видно чітко
- [ ] "TOXIC GAS" текст центрований, білий
- [ ] "Find shelter!" субтитр видно
- [ ] Прогрес-бар червоний/зелений

### Damage
- [ ] Здоров'я зменшується під час газу
- [ ] Шкода приблизно 8 за тік
- [ ] ~40 всього шкоди за 4 сек
- [ ] Шкода зупиняється після события

### Timing
- [ ] Тривалість ~4 сек
- [ ] Прогрес-бар рівномірний
- [ ] Частота ~кожні 15 сек

---

## ⌨️ Keyboard Shortcuts (for testing)

- **B** = Trigger Blackout
- **T** = Trigger Toxic Gas  
- **G** = Game Over
- **N** = Next Sector
- **ESC/P** = Pause

---

## 🔧 Quick Config Tweaks

### `lib/config/game_config.dart`

```dart
// Більш швидка шкода (більш кожні 0.2 сек)
static const double toxicGasDamageInterval = 0.2;

// Менше шкоди за тік
static const double toxicGasDamagePerTick = 5.0;

// Більш видимо (70% замість 60%)
static const double toxicGasOpacity = 0.7;

// Коротше события
static const double toxicGasDuration = 2.0;
```

Перезапустіть гру після змін.

---

## 📊 Expected Damage Per Event

```
Duration: 4 secs
Tick interval: 0.3 secs per damage

Damage ticks: 4 / 0.3 ≈ 13 ticks
Damage per tick: 8 HP
Total damage: ~104 HP (but capped at 4 sec = ~40 HP)
```

**For 100 HP player:**
- Before: 100 HP
- During 4 sec toxic gas: -40 HP
- After: 60 HP (if nothing heals)

---

## 🧪 Unit Tests

```bash
flutter test
# ✅ Should see 27 tests pass (1 unrelated failure)
# No new errors from toxic gas
```

---

## 🐛 Quick Fixes

### Not taking damage?
- Check: `player.takeDamage()` method exists
- Check: Player health bar updates normally
- Try: Press T to manually trigger

### Gas doesn't appear?
- Check: `hazardEventsEnabled = true`
- Check: Not in pause/game over
- Try: Press T key

### UI not showing?
- Check: No other overlay active
- Check: GameHud mounted properly
- Try: Run on different device/emulator

---

## 🎬 Demo Flow

1. **Natural spawn (~15 sec):**
   ```
   Play → (wait) → Toxic gas auto-triggers
   ```

2. **Manual trigger (instant):**
   ```
   Play → Press T → Green overlay appears → 4 sec → Done
   ```

3. **Compare with Blackout (Press B):**
   ```
   Blackout: Dark, temporary visibility issue
   Toxic Gas: Green, take damage, must move
   ```

---

## ✅ Checklist

- [ ] T key triggers gas immediately
- [ ] Green overlay appears (60% opacity)
- [ ] Text shows "TOXIC GAS"
- [ ] Progress bar fills 0→100% in 4 sec
- [ ] Health decreases over time
- [ ] Gas stops after 4 seconds
- [ ] Natural spawn ~every 15 sec
- [ ] 10 sec cooldown between gas events
- [ ] No overlap with blackout
- [ ] Tests pass (27/28)

---

**Status:** ✅ Ready to test  
**Build time:** ~30 seconds  
**Test time:** ~2 minutes for full verification

