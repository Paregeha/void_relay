import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../flame_game.dart';
import '../player/player_component.dart';

typedef InteractionAction = void Function(PlayerComponent player);
typedef InteractionEnabled = bool Function();

class InteractionBinding {
  final PositionComponent component;
  final double interactionRange;
  final InteractionAction onInteract;
  final InteractionEnabled? isEnabled;

  InteractionBinding({
    required this.component,
    required this.interactionRange,
    required this.onInteract,
    this.isEnabled,
  });

  bool get enabled => isEnabled?.call() ?? true;
}

/// Проста система взаємодій: натискання E активує найближчий об'єкт у радіусі.
class InteractionSystem extends Component {
  final PlayerComponent player;
  final List<InteractionBinding> _bindings = [];

  bool _wasInteractPressed = false;

  InteractionSystem({required this.player});

  void register(InteractionBinding binding) {
    _bindings.add(binding);
  }

  void unregisterForComponent(PositionComponent component) {
    _bindings.removeWhere((b) => identical(b.component, component));
  }

  @override
  void update(double dt) {
    super.update(dt);

    final game = findGame();
    if (game is VoidRelayGame && game.isGameplayInputBlocked) {
      _wasInteractPressed = false;
      return;
    }

    final isPressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      LogicalKeyboardKey.keyE,
    );

    if (isPressed && !_wasInteractPressed) {
      _tryInteractNearest();
    }

    _wasInteractPressed = isPressed;
  }

  void _tryInteractNearest() {
    InteractionBinding? nearest;
    double nearestDistance = double.infinity;

    for (final binding in _bindings) {
      if (!binding.enabled) continue;
      if (!binding.component.isMounted) continue;

      final distance = binding.component.position.distanceTo(player.position);
      if (distance <= binding.interactionRange && distance < nearestDistance) {
        nearestDistance = distance;
        nearest = binding;
      }
    }

    if (nearest != null) {
      nearest.onInteract(player);
    }
  }
}
