import 'package:flutter/services.dart';

class SoundAssets {
  static const String shot = 'shot';
  static const String hit = 'hit';
  static const String cooling = 'cooling';
  static const String alert = 'alert';
  static const String transition = 'transition';

  static const Map<String, int> minIntervalMs = {
    shot: 70,
    hit: 90,
    cooling: 350,
    alert: 500,
    transition: 450,
  };

  static SystemSoundType toSystemSound(String key) {
    switch (key) {
      case shot:
      case hit:
      case transition:
        return SystemSoundType.click;
      case cooling:
      case alert:
        return SystemSoundType.alert;
      default:
        return SystemSoundType.click;
    }
  }
}
