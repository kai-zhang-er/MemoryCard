import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/services/audio_playback_service.dart';
import 'package:memory_cards/widgets/audio_player_tile.dart';

void main() {
  testWidgets('AudioPlayerTile toggles play and pause', (tester) async {
    final controller = _FakeAudioPlaybackController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioPlayerTile(
            audioPath: 'audio/2026/memory.m4a',
            controllerFactory: () => controller,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(controller.playCalls, 1);
    expect(controller.lastPlayedPath, 'audio/2026/memory.m4a');
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(controller.pauseCalls, 1);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('AudioPlayerTile shows friendly playback failures',
      (tester) async {
    final controller = _FakeAudioPlaybackController(failOnPlay: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioPlayerTile(
            audioPath: 'audio/2026/missing.m4a',
            controllerFactory: () => controller,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(find.text(audioPlaybackErrorMessage), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}

class _FakeAudioPlaybackController implements AudioPlaybackController {
  _FakeAudioPlaybackController({this.failOnPlay = false});

  final bool failOnPlay;
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  var _isPlaying = false;
  var playCalls = 0;
  var pauseCalls = 0;
  String? lastPlayedPath;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => const Duration(seconds: 12);

  @override
  Future<void> play(String audioPath) async {
    playCalls += 1;
    lastPlayedPath = audioPath;
    if (failOnPlay) {
      throw const AudioPlaybackFailure();
    }
    _isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    _isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
