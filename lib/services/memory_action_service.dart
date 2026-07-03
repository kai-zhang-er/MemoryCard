import '../models/memory_record.dart';
import '../models/photo_asset.dart';
import 'memory_repository.dart';

class MemoryActionService {
  MemoryActionService(this.repository);

  static const String promptQuestion = '这张照片你还记得吗？';

  final MemoryRepository repository;

  Future<MemoryRecord> saveAction(
    PhotoAsset asset,
    MemoryRecordAction action, {
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final existing = await repository.getByAssetId(asset.assetId);
    final base = existing ??
        MemoryRecord(
          memoryId: _newMemoryId(asset, timestamp),
          assetId: asset.assetId,
          assetFingerprint: _assetFingerprint(asset),
          photoTime: asset.createdAt,
          createdAt: timestamp,
          updatedAt: timestamp,
          promptQuestion: promptQuestion,
        );

    final updated = base.copyWith(
      important: base.important || action == MemoryRecordAction.important,
      deleteCandidate:
          base.deleteCandidate || action == MemoryRecordAction.deleteCandidate,
      skipped: base.skipped || action == MemoryRecordAction.skipped,
      reviewStatus:
          action == MemoryRecordAction.skipped ? 'skipped' : base.reviewStatus,
      updatedAt: timestamp,
    );
    await repository.upsert(updated);
    return updated;
  }

  String _newMemoryId(PhotoAsset asset, DateTime now) {
    final safeAssetId = asset.assetId.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    return 'memory_${now.microsecondsSinceEpoch}_$safeAssetId';
  }

  String _assetFingerprint(PhotoAsset asset) {
    return [
      asset.assetId,
      asset.createdAt?.toIso8601String() ?? 'unknown_time',
      asset.width?.toString() ?? 'unknown_width',
      asset.height?.toString() ?? 'unknown_height',
    ].join('|');
  }
}

enum MemoryRecordAction {
  important('标记重要'),
  deleteCandidate('标记待删除'),
  skipped('已跳过');

  const MemoryRecordAction(this.confirmationText);

  final String confirmationText;
}
