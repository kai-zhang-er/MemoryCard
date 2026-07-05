import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/models/photo_asset.dart';
import 'package:memory_cards/screens/memory_list_screen.dart';
import 'package:memory_cards/services/audio_playback_service.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';
import 'package:memory_cards/widgets/audio_player_tile.dart';
import 'package:memory_cards/widgets/memory_thumbnail.dart';

const _playAudioText = '\u64ad\u653e\u5f55\u97f3';
const _photoMemoryText = '\u7167\u7247\u8bb0\u5fc6';
const _detailTitle = '\u8bb0\u5fc6\u8be6\u60c5';
const _listTitle = '\u8bb0\u5fc6\u5217\u8868';

void main() {
  testWidgets('MemoryListScreen shows thumbnails and audio playback controls',
      (tester) async {
    final photoLibraryService = _FakePhotoLibraryService();
    final repository = _FakeMemoryRepository([
      _record('memory_with_audio').copyWith(
        audioPath: 'audio/2026/memory.m4a',
      ),
      _record('memory_without_audio'),
    ]);

    await _pumpList(
      tester,
      repository: repository,
      photoLibraryService: photoLibraryService,
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MemoryThumbnail), findsNWidgets(2));
    expect(find.byType(AudioPlayerTile), findsOneWidget);
    expect(find.text(_playAudioText), findsOneWidget);
    expect(
      photoLibraryService.thumbnailRequests,
      containsAll(['asset_memory_with_audio', 'asset_memory_without_audio']),
    );
  });

  testWidgets(
      'tapping a memory opens the detail screen and refreshes on return',
      (tester) async {
    final repository = _FakeMemoryRepository([_record('memory_001')]);

    await _pumpList(tester, repository: repository);
    await tester.pump();

    await tester.tap(find.text(_photoMemoryText));
    await tester.pump();
    await tester.pump();

    expect(find.text(_detailTitle), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump();

    expect(repository.getAllCalls, 2);
    expect(find.text(_listTitle), findsOneWidget);
  });
}

Future<void> _pumpList(
  WidgetTester tester, {
  required _FakeMemoryRepository repository,
  PhotoLibraryService? photoLibraryService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MemoryListScreen(
        repository: repository,
        filter: MemoryListFilter.all,
        photoLibraryService: photoLibraryService ?? _FakePhotoLibraryService(),
        audioPlaybackControllerFactory: _FakeAudioPlaybackController.new,
      ),
    ),
  );
}

MemoryRecord _record(String id) {
  final now = DateTime.utc(2026, 7, 3, 9);
  return MemoryRecord(
    memoryId: id,
    assetId: 'asset_$id',
    photoTime: now.subtract(const Duration(days: 400)),
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeMemoryRepository extends MemoryRepository {
  _FakeMemoryRepository(this.records);

  final List<MemoryRecord> records;
  var getAllCalls = 0;

  @override
  Future<List<MemoryRecord>> getAll() async {
    getAllCalls += 1;
    return records;
  }

  @override
  Future<List<MemoryRecord>> getImportant() async =>
      records.where((record) => record.important).toList(growable: false);

  @override
  Future<List<MemoryRecord>> getDeleteCandidates() async =>
      records.where((record) => record.deleteCandidate).toList(growable: false);

  @override
  Future<MemoryRecord?> getByMemoryId(String memoryId) async {
    for (final record in records) {
      if (record.memoryId == memoryId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> upsert(MemoryRecord record) async {
    final index =
        records.indexWhere((item) => item.memoryId == record.memoryId);
    if (index == -1) {
      records.add(record);
    } else {
      records[index] = record;
    }
  }

  @override
  Future<int> deleteByMemoryId(String memoryId) async {
    records.removeWhere((record) => record.memoryId == memoryId);
    return 1;
  }
}

class _FakePhotoLibraryService implements PhotoLibraryService {
  final List<String> thumbnailRequests = [];

  @override
  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80}) async => const [];

  @override
  Future<DateTime?> getPhotoTime(String assetId) async => null;

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 900}) async {
    thumbnailRequests.add(assetId);
    return _onePixelPng;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<PhotoPermissionResult> requestPermission() async =>
      PhotoPermissionResult.authorized;
}

class _FakeAudioPlaybackController implements AudioPlaybackController {
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  bool get isPlaying => false;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  Future<void> play(String audioPath) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
  }
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3Q2wAAAABJRU5ErkJggg==',
);
