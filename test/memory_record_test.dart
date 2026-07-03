import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';

void main() {
  test('MemoryRecord converts to and from a SQLite map', () {
    final now = DateTime.utc(2026, 7, 3, 8, 30);
    final record = MemoryRecord(
      memoryId: 'memory_001',
      assetId: 'fake_asset_001',
      assetFingerprint: 'fingerprint_001',
      photoTime: DateTime.utc(2025, 1, 1),
      createdAt: now,
      updatedAt: now,
      important: true,
      deleteCandidate: false,
      skipped: true,
      userTags: const ['旅行', '朋友'],
      aiLightTags: const ['old_photo'],
      audioPath: 'audio/fake.m4a',
    );

    final restored = MemoryRecord.fromMap(record.toMap());

    expect(restored.memoryId, record.memoryId);
    expect(restored.assetId, record.assetId);
    expect(restored.important, isTrue);
    expect(restored.deleteCandidate, isFalse);
    expect(restored.skipped, isTrue);
    expect(restored.userTags, ['旅行', '朋友']);
    expect(restored.aiLightTags, ['old_photo']);
    expect(restored.audioPath, 'audio/fake.m4a');
  });

  test('MemoryRecord JSON keeps booleans and lists export-friendly', () {
    final now = DateTime.utc(2026, 7, 3);
    final record = MemoryRecord(
      memoryId: 'memory_002',
      assetId: 'fake_asset_002',
      createdAt: now,
      updatedAt: now,
      important: true,
      userTags: const ['家庭'],
    );

    final json = record.toJson();

    expect(json['important'], isTrue);
    expect(json['delete_candidate'], isFalse);
    expect(json['user_tags'], ['家庭']);
    expect(json['review_status'], 'raw');
  });
}
