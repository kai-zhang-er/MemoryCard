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
    String? promptQuestion,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final base = await _baseRecord(asset, timestamp, promptQuestion);

    final updated = base.copyWith(
      important: base.important || action == MemoryRecordAction.important,
      deleteCandidate:
          base.deleteCandidate || action == MemoryRecordAction.deleteCandidate,
      skipped: base.skipped || action == MemoryRecordAction.skipped,
      promptQuestion: promptQuestion ?? base.promptQuestion,
      reviewStatus:
          action == MemoryRecordAction.skipped ? 'skipped' : base.reviewStatus,
      updatedAt: timestamp,
    );
    await repository.upsert(updated);
    return updated;
  }

  Future<MemoryRecord> attachAudio(
    PhotoAsset asset,
    String audioPath, {
    String? promptQuestion,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final base = await _baseRecord(asset, timestamp, promptQuestion);

    final updated = base.copyWith(
      audioPath: audioPath,
      promptQuestion: promptQuestion ?? base.promptQuestion,
      reviewStatus: 'raw',
      updatedAt: timestamp,
    );
    await repository.upsert(updated);
    return updated;
  }

  Future<MemoryRecord> saveTags(
    PhotoAsset asset,
    List<String> tags, {
    String? promptQuestion,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final base = await _baseRecord(asset, timestamp, promptQuestion);
    final mergedTags = <String>{
      ...base.userTags,
      ...tags.where((tag) => tag.trim().isNotEmpty).map((tag) => tag.trim()),
    }.toList(growable: false);

    final updated = base.copyWith(
      userTags: mergedTags,
      promptQuestion: promptQuestion ?? base.promptQuestion,
      updatedAt: timestamp,
    );
    await repository.upsert(updated);
    return updated;
  }

  Future<MemoryRecord> _baseRecord(
    PhotoAsset asset,
    DateTime timestamp,
    String? promptQuestion,
  ) async {
    final existing = await repository.getByAssetId(asset.assetId);
    return existing ??
        MemoryRecord(
          memoryId: _newMemoryId(asset, timestamp),
          assetId: asset.assetId,
          assetFingerprint: _assetFingerprint(asset),
          photoTime: asset.createdAt,
          createdAt: timestamp,
          updatedAt: timestamp,
          promptQuestion: promptQuestion ?? MemoryActionService.promptQuestion,
        );
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
