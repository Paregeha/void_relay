import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:void_relay/enemies/crawler/crawler.dart';

void main() {
  test('Crawler manual atlas mapping keeps expected frame counts', () {
    expect(Crawler.crawlerWalkRects.length, 7);
    expect(Crawler.crawlerIdleRects.length, 7);
    expect(Crawler.crawlerAttackRects.length, 7);
    expect(Crawler.crawlerDeathRects.length, 6);
  });

  test('Crawler render path uses single drawImageRect call', () {
    final source = File('lib/enemies/crawler/crawler.dart').readAsStringSync();
    final drawCalls = RegExp(
      r'canvas\.drawImageRect\(',
    ).allMatches(source).length;
    expect(drawCalls, 1);
  });

  test('Sentry turret never falls back to crawler sheet', () {
    final source = File(
      'lib/enemies/sentry_turret/sentry_turret.dart',
    ).readAsStringSync();
    expect(
      source.contains('assets/sprites/enemies/crawler_sheet.png'),
      isFalse,
    );
  });
}
