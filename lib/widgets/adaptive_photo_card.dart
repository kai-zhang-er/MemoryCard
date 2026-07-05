import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class AdaptivePhotoCard extends StatelessWidget {
  const AdaptivePhotoCard({
    super.key,
    required this.imageBytes,
    this.imageWidth,
    this.imageHeight,
    this.maxDesktopWidth = 720,
    this.maxHeightFactor = 0.56,
    this.maxHeight,
  });

  final Uint8List imageBytes;
  final int? imageWidth;
  final int? imageHeight;
  final double maxDesktopWidth;
  final double maxHeightFactor;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowSize = MediaQuery.sizeOf(context);
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : windowSize.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : windowSize.height;

        final displayMaxWidth = math.min(availableWidth, maxDesktopWidth);
        final computedMaxHeight =
            maxHeight ?? availableHeight * maxHeightFactor;
        final displayMaxHeight = math.max(1.0, computedMaxHeight);
        final aspectRatio = _aspectRatio;

        var displayWidth = displayMaxWidth;
        var displayHeight = displayWidth / aspectRatio;
        if (displayHeight > displayMaxHeight) {
          displayHeight = displayMaxHeight;
          displayWidth = displayHeight * aspectRatio;
        }

        return Center(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: ColoredBox(
                key: const ValueKey('adaptive_photo_frame'),
                color: Colors.black,
                child: Center(
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double get _aspectRatio {
    final width = imageWidth;
    final height = imageHeight;
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 4 / 3;
  }
}
