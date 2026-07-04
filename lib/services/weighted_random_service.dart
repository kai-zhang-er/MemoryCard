import 'dart:math';

import '../models/photo_asset.dart';

class WeightedRandomService {
  const WeightedRandomService();

  PhotoAsset? pickPhoto(
    List<PhotoAsset> assets, {
    Set<String> processedAssetIds = const {},
    DateTime? now,
    Random? random,
  }) {
    if (assets.isEmpty) {
      return null;
    }

    final available = assets
        .where((asset) => !processedAssetIds.contains(asset.assetId))
        .toList(growable: false);
    final candidates = available.isNotEmpty ? available : assets;
    final repeatOnly = available.isEmpty;
    final weights = candidates
        .map((asset) => weightFor(
              asset,
              processedAssetIds: processedAssetIds,
              now: now,
              allowProcessedFallback: repeatOnly,
            ))
        .toList(growable: false);

    final totalWeight = weights.fold<double>(0, (sum, weight) => sum + weight);
    if (totalWeight <= 0) {
      return candidates.first;
    }

    final roll = (random ?? Random()).nextDouble() * totalWeight;
    var cursor = 0.0;
    for (var i = 0; i < candidates.length; i += 1) {
      cursor += weights[i];
      if (roll <= cursor) {
        return candidates[i];
      }
    }
    return candidates.last;
  }

  double weightFor(
    PhotoAsset asset, {
    Set<String> processedAssetIds = const {},
    DateTime? now,
    bool allowProcessedFallback = false,
  }) {
    final referenceDate = now ?? DateTime.now();
    var weight = _ageWeight(asset.createdAt, referenceDate);
    if (processedAssetIds.contains(asset.assetId)) {
      weight *= allowProcessedFallback ? 0.25 : 0.05;
    }
    return weight;
  }

  double _ageWeight(DateTime? photoDate, DateTime now) {
    if (photoDate == null) {
      return 1.0;
    }

    final age = now.difference(photoDate);
    if (age.inDays < 0) {
      return 1.0;
    }
    if (age.inDays <= 30) {
      return 0.25;
    }
    if (age.inDays >= 365) {
      return 4.0;
    }
    if (age.inDays >= 183) {
      return 2.25;
    }
    return 1.0;
  }
}
