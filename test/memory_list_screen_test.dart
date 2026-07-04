import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/models/memory_record.dart';
import 'package:memory_cards/screens/memory_list_screen.dart';
import 'package:memory_cards/services/audio_playback_service.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/widgets/audio_player_tile.dart';

void main() {
  testWidgets('MemoryListScreen shows playback only for audio records',
      (tester) async {
    final repository = _FakeMemoryRepository([
      _record('memory_with_audio').copyWith(
        audioPath: 'audio/2026/memory.m4a',
      ),
      _record('memory_without_audio'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryListScreen(
          repository: repository,
          filter: MemoryListFilter.all,
          audioPlaybackControllerFactory: _FakeAudioPlaybackController.new,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AudioPlayerTile), findsOneWidget);
    expect(find.text('播放录音'), findsOneWidget);
  });
}

MemoryRecord _record(String id) {
  final now = DateTime.utc(2026, 7, 3, 9);
  return MemoryRecord(
    memoryId: id,
    assetId: 'asset_$id',
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeMemoryRepository extends MemoryRepository {
  _FakeMemoryRepository(this.records);

  final List<MemoryRecord> records;

  @override
  Future<List<MemoryRecord>> getAll() async => records;

  @override
  Future<List<MemoryRecord>> getImportant() async =>
      records.where((record) => record.important).toList(growable: false);

  @override
  Future<List<MemoryRecord>> getDeleteCandidates() async =>
      records.where((record) => record.deleteCandidate).toList(growable: false);
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
