import 'package:flutter/services.dart';

import '../flame_game.dart';
import 'player_component.dart';

class PlayerController {
  final PlayerComponent player;
  bool _wasJumpPressed = false;
  bool _wasNextWeaponPressed = false;
  bool _wasPrevWeaponPressed = false;
  bool _wasSlot1Pressed = false;
  bool _wasSlot2Pressed = false;

  static const LogicalKeyboardKey _nextWeaponKey = LogicalKeyboardKey.keyC;
  static const LogicalKeyboardKey _prevWeaponKey = LogicalKeyboardKey.keyX;
  static const LogicalKeyboardKey _slot1Key = LogicalKeyboardKey.digit1;
  static const LogicalKeyboardKey _slot2Key = LogicalKeyboardKey.digit2;

  PlayerController(this.player);

  void update(double dt) {
    final game = player.findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      // Блокуємо gameplay-ввід, але гасимо горизонтальний рух.
      player.stopHorizontal();
      player.weaponManager.setTriggerHeld(false);
      player.setSprintHeld(false);
      _wasJumpPressed = false;
      _wasNextWeaponPressed = false;
      _wasPrevWeaponPressed = false;
      _wasSlot1Pressed = false;
      _wasSlot2Pressed = false;
      return;
    }

    // Обробка клавіш (для desktop)
    if (HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.keyA,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.arrowLeft,
        )) {
      player.moveLeft(dt);
    } else if (HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.keyD,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.arrowRight,
        )) {
      player.moveRight(dt);
    } else {
      player.stopHorizontal();
    }

    final jumpPressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      LogicalKeyboardKey.space,
    );
    if (jumpPressed && !_wasJumpPressed) {
      player.jump();
    }
    _wasJumpPressed = jumpPressed;

    final dashPressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      LogicalKeyboardKey.shiftLeft,
    );
    player.setSprintHeld(dashPressed);

    final nextWeaponPressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      _nextWeaponKey,
    );
    if (nextWeaponPressed && !_wasNextWeaponPressed) {
      player.weaponManager.switchToNextWeapon();
    }
    _wasNextWeaponPressed = nextWeaponPressed;

    final prevWeaponPressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      _prevWeaponKey,
    );
    if (prevWeaponPressed && !_wasPrevWeaponPressed) {
      player.weaponManager.switchToPreviousWeapon();
    }
    _wasPrevWeaponPressed = prevWeaponPressed;

    final slot1Pressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      _slot1Key,
    );
    if (slot1Pressed && !_wasSlot1Pressed) {
      player.weaponManager.switchToWeaponSlot(0);
    }
    _wasSlot1Pressed = slot1Pressed;

    final slot2Pressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      _slot2Key,
    );
    if (slot2Pressed && !_wasSlot2Pressed) {
      player.weaponManager.switchToWeaponSlot(1);
    }
    _wasSlot2Pressed = slot2Pressed;

    player.weaponManager.setTriggerHeld(
      HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.keyF),
    );
  }
}
