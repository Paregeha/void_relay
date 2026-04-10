# Швидкий старт: Тестування Blackout

## ⚡ Швидкий тест (2 хвилини)

### Крок 1: Запустити гру
```bash
flutter run
```

### Крок 2: Тестування вручну (Клавіша B)
1. Гра загрузилась
2. Натисніть **B** на клавіатурі
3. **Очікуваний результат:**
   - Екран темнішає
   - З'явиться текст "BLACKOUT" з "Systems offline"
   - Червоний прогрес-бар показує залишок часу
   - Після 3.5 сек - затемнення зникає

### Крок 3: Авто-тест (Природне гейнплею)
1. Запустити гру
2. Грати ~15-20 сек
3. **Очікуваний результат:**
   - Випадково з'явиться blackout
   - Перевірити UI та прогрес
   - Переконатись що гра продовжується після события

---

## 🧪 Unit тести

```bash
# Запустити всі тести
flutter test

# Тільки smoke тести
flutter test test/sector_transition_smoke_test.dart

# З output
flutter test --verbose
```

**Очікувані результати:**
- ✅ 20+ тестів проходять
- ⚠️ 1 тест падає (enemy_double_movement_test - НЕ пов'язано з blackout)

---

## 📝 Що перевірити

### UI Blackout
- [ ] Текст "BLACKOUT" видно чітко
- [ ] "Systems offline" субтитр видно
- [ ] Прогрес-бар червоного кольору
- [ ] Чорний overlay темний (85% непрозорості)

### Тривалість
- [ ] Затемнення тривае ~3.5 сек
- [ ] Прогрес-бар рівномірно прогресує до 100%
- [ ] UI зникає після завершення

### Частота
- [ ] Blackout активується ~кожні 15 сек
- [ ] Не активується занадто часто (мінімум 8 сек між ними)
- [ ] Гра продовжується нормально

---

## 🎛️ Регулювання параметрів

Відредагуйте `lib/config/game_config.dart`:

```dart
// Затемнення тривало 2 сек замість 3.5
static const double blackoutDuration = 2.0;

// Нижча непрозорість (больш видно ворогів)
static const double blackoutOpacity = 0.5;

// Рідше события - кожні 30 сек
static const double timeBetweenHazardEvents = 30.0;

// Вимкнути всі события
static const bool hazardEventsEnabled = false;
```

---

## 🐛 Усунення проблем

### Проблема: Blackout не з'являється
**Рішення:**
```dart
// Переконайтесь що:
1. hazardEventsEnabled = true в GameConfig
2. Натисніть B для ручної активації
3. Чекайте ~15 сек для авто-активації
```

### Проблема: UI не видно
**Рішення:**
```dart
// Перевірте:
1. GameHud отримує game reference
2. hazardSystem присутня у flame_game
3. Нема конфліктів з іншими overlays (pause, game_over)
```

### Проблема: Прогрес-бар не змінюється
**Рішення:**
```dart
// Перевірте:
1. currentEventProgress getter у HazardSystem
2. update() викликається в HazardSystem (не паузовано)
```

---

## 📊 Логування (Debug)

Додайте у `hazard_system.dart`:

```dart
void _triggerRandomEvent() {
  print('🎲 Attempting to trigger random event...');
  // ... код ...
  if (randomValue < 0.7) {
    print('✅ BLACKOUT triggered!');
  }
}
```

Або перевірте стан у runtime:
```dart
// Де-небудь у коді
print('Blackout active: ${game.isBlackoutActive}');
print('Event progress: ${game.hazardSystem?.currentEventProgress}');
```

---

## 🎯 Наступні кроки після тестування

1. ✅ Перевірити UI/UX
2. ✅ Перевірити тривалість та частоту
3. ⏭️ Додати ToxicGasEvent
4. ⏭️ Додати DoorFailureEvent
5. ⏭️ Додати звукові ефекти
6. ⏭️ Тюнінг балансу складності

