import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/record_memory_screen.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/recording_service.dart';

const _startRecordingText = '\u5f00\u59cb\u5f55\u97f3';
const _stopRecordingText = '\u505c\u6b62\u5f55\u97f3';
const _saveText = '\u4fdd\u5b58';
const _discardText = '\u4e0d\u4fdd\u5b58';
const _retryPermissionText = '\u91cd\u65b0\u8bf7\u6c42';
const _permissionTitle = '\u9700\u8981\u9ea6\u514b\u98ce\u6743\u9650';
const _noteLabel = '\u6587\u5b57\u5907\u6ce8';

void main() {
  testWidgets('shows denied state when microphone permission is missing',
      (tester) async {
    final service = _FakeRecordingService(hasPermissionValue: false);

    await _pumpScreen(tester, service, _FakeMemoryRepository());
    await tester.tap(find.text(_startRecordingText));
    await tester.pump();

    expect(find.text(_permissionTitle), findsOneWidget);
    expect(find.text(_retryPermissionText), findsOneWidget);
  });

  testWidgets('shows the current photo thumbnail while recording',
      (tester) async {
    final service = _FakeRecordingService(hasPermissionValue: true);

    await _pumpScreen(
      tester,
      service,
      _FakeMemoryRepository(),
      thumbnailBytes: _onePixelPng,
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('saving recording stores the shown prompt', (tester) async {
    final repository = _FakeMemoryRepository();
    final service = _FakeRecordingService(
      hasPermissionValue: true,
      stopPath: 'audio/2026/memory_photo_001.m4a',
    );

    await _pumpScreen(tester, service, repository);
    await tester.tap(find.text(_startRecordingText));
    await tester.pump();
    await tester.tap(find.text(_stopRecordingText));
    await tester.pump();
    await tester.tap(find.text(_saveText));
    await tester.pump();

    final saved = await repository.getByAssetId('photo_001');
    expect(saved, isNotNull);
    expect(saved!.promptQuestion, '\u8fd9\u662f\u5728\u54ea\u91cc\uff1f');
  });

  testWidgets('saving recording stores manual note separately from transcript',
      (tester) async {
    final repository = _FakeMemoryRepository();
    final service = _FakeRecordingService(
      hasPermissionValue: true,
      stopPath: 'audio/2026/memory_photo_001.m4a',
    );

    await _pumpScreen(tester, service, repository);
    await tester.enterText(
      find.widgetWithText(TextField, _noteLabel),
      '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002',
    );
    await tester.tap(find.text(_startRecordingText));
    await tester.pump();
    await tester.tap(find.text(_stopRecordingText));
    await tester.pump();
    await tester.tap(find.text(_saveText));
    await tester.pump();

    final saved = await repository.getByAssetId('photo_001');
    expect(saved, isNotNull);
    expect(saved!.memoryText,
        '\u8fd9\u662f\u672c\u79d1\u6bd5\u4e1a\u65c5\u884c\uff0c\u5728\u53a6\u95e8\u3002');
    expect(saved.transcript, '');
  });

  testWidgets('discarding recording does not write record', (tester) async {
    final service = _FakeRecordingService(
      hasPermissionValue: true,
      stopPath: 'audio/2026/memory_photo_001.m4a',
    );

    await _pumpScreen(tester, service, _FakeMemoryRepository());
    await tester.tap(find.text(_startRecordingText));
    await tester.pump();
    await tester.tap(find.text(_stopRecordingText));
    await tester.pump();
    await tester.tap(find.text(_discardText));
    await tester.pump();
    expect(service.cancelCalled, isTrue);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  RecordingService recordingService,
  MemoryRepository repository, {
  Uint8List? thumbnailBytes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RecordMemoryScreen(
        asset: _asset('photo_001'),
        memoryRepository: repository,
        recordingService: recordingService,
        thumbnailBytes: thumbnailBytes,
        promptQuestion: '\u8fd9\u662f\u5728\u54ea\u91cc\uff1f',
      ),
    ),
  );
  await tester.pump();
}

PhotoAsset _asset(String id) {
  return PhotoAsset(
    assetId: id,
    createdAt: DateTime.utc(2025, 7, 3),
    width: 1200,
    height: 1600,
    title: 'Fake photo $id',
  );
}

class _FakeMemoryRepository extends MemoryRepository {
  final List<MemoryRecord> records = [];

  @override
  Future<void> upsert(MemoryRecord record) async {
    records.removeWhere((existing) => existing.memoryId == record.memoryId);
    records.add(record);
  }

  @override
  Future<MemoryRecord?> getByAssetId(String assetId) async {
    final matches = records.where((record) => record.assetId == assetId);
    return matches.isEmpty ? null : matches.last;
  }
}

class _FakeRecordingService implements RecordingService {
  _FakeRecordingService({
    required this.hasPermissionValue,
    this.stopPath = 'audio/2026/fake.m4a',
  });

  final bool hasPermissionValue;
  final String stopPath;
  bool cancelCalled = false;
  bool disposed = false;

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<bool> hasPermission() async {
    return hasPermissionValue;
  }

  @override
  Future<RecordingStartResult> start(String assetId, {DateTime? now}) async {
    return RecordingStartResult(
      absolutePath: 'C:/tmp/$assetId.m4a',
      relativePath: 'audio/2026/$assetId.m4a',
    );
  }

  @override
  Future<String?> stop() async {
    return stopPath;
  }
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3Q2wAAAABJRU5ErkJggg==',
);
