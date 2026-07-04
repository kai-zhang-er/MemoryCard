import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/services/weighted_random_service.dart';

void main() {
  const service = WeightedRandomService();
  final now = DateTime.utc(2026, 7, 3);

  test('older photos receive higher weights than recent photos', () {
    final old = _asset('old', now.subtract(const Duration(days: 500)));
    final recent = _asset('recent', now.subtract(const Duration(days: 10)));

    expect(service.weightFor(old, now: now),
        greaterThan(service.weightFor(recent, now: now)));
  });

  test('six-month-old photos receive boosted weight', () {
    final older = _asset('older', now.subtract(const Duration(days: 220)));
    final normal = _asset('normal', now.subtract(const Duration(days: 100)));

    expect(service.weightFor(older, now: now),
        greaterThan(service.weightFor(normal, now: now)));
  });

  test('unprocessed assets are preferred over processed assets', () {
    final processed =
        _asset('processed', now.subtract(const Duration(days: 500)));
    final unprocessed =
        _asset('unprocessed', now.subtract(const Duration(days: 10)));

    for (var i = 0; i < 20; i += 1) {
      final picked = service.pickPhoto(
        [processed, unprocessed],
        processedAssetIds: {'processed'},
        now: now,
        random: Random(i),
      );
      expect(picked!.assetId, 'unprocessed');
    }
  });

  test('all processed fallback still returns an asset', () {
    final picked = service.pickPhoto(
      [_asset('one', now), _asset('two', null)],
      processedAssetIds: {'one', 'two'},
      now: now,
      random: Random(1),
    );

    expect(picked, isNotNull);
    expect({'one', 'two'}, contains(picked!.assetId));
  });
}

PhotoAsset _asset(String id, DateTime? createdAt) {
  return PhotoAsset(assetId: id, createdAt: createdAt);
}
