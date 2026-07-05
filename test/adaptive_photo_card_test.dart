import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/widgets/adaptive_photo_card.dart';

void main() {
  testWidgets('AdaptivePhotoCard sizes frame from image aspect and constraints',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: AdaptivePhotoCard(
              imageBytes: _onePixelPng,
              imageWidth: 100,
              imageHeight: 100,
              maxDesktopWidth: 720,
              maxHeightFactor: 0.56,
            ),
          ),
        ),
      ),
    );

    final photoFrameSize =
        tester.getSize(find.byKey(const ValueKey('adaptive_photo_frame')));

    expect(photoFrameSize.width, closeTo(336, 1));
    expect(photoFrameSize.height, closeTo(336, 1));
  });

  testWidgets('AdaptivePhotoCard keeps wide photos within desktop width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: AdaptivePhotoCard(
              imageBytes: _onePixelPng,
              imageWidth: 1600,
              imageHeight: 900,
            ),
          ),
        ),
      ),
    );

    final photoFrameSize =
        tester.getSize(find.byKey(const ValueKey('adaptive_photo_frame')));

    expect(photoFrameSize.width, closeTo(720, 1));
    expect(photoFrameSize.height, closeTo(405, 1));
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3Q2wAAAABJRU5ErkJggg==',
);
