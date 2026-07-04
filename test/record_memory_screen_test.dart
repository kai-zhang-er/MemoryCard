import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/record_memory_screen.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/recording_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late MemoryRepository repository;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('memory_cards_record_test_');
    repository = MemoryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${tempDir.path}/memory_cards_test.db',
    );
  });

  tearDown(() async {
    await repository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('shows denied state when microphone permission is missing',
      (tester) async {
    final service = _FakeRecordingService(hasPermissionValue: false);

    await _pumpScreen(tester, service, repository);
    await tester.tap(find.text('开始录音'));
    await tester.pump();

    expect(find.text('需要麦克风权限'), findsOneWidget);
    expect(find.text('重新请求'), findsOneWidget);
  });

  testWidgets('shows the current photo thumbnail while recording',
      (tester) async {
    final service = _FakeRecordingService(hasPermissionValue: true);

    await _pumpScreen(
      tester,
      service,
      repository,
      thumbnailBytes: _onePixelPng,
    );

    expect(find.byType(Image), findsOneWidget);
  });
  testWidgets('discarding recording does not write record', (tester) async {
    final service = _FakeRecordingService(
      hasPermissionValue: true,
      stopPath: 'audio/2026/memory_photo_001.m4a',
    );

    await _pumpScreen(tester, service, repository);
    await tester.tap(find.text('开始录音'));
    await tester.pump();
    await tester.tap(find.text('停止录音'));
    await tester.pump();
    await tester.tap(find.text('不保存'));
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
