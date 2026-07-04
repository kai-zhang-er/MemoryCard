import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/photo_library_service.dart';

class MemoryThumbnail extends StatelessWidget {
  const MemoryThumbnail({
    super.key,
    required this.assetId,
    required this.photoLibraryService,
    this.size = 64,
    this.thumbnailSize = 160,
  });

  final String assetId;
  final PhotoLibraryService photoLibraryService;
  final double size;
  final int thumbnailSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: photoLibraryService.getThumbnail(
            assetId,
            size: thumbnailSize,
          ),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const _ThumbnailPlaceholder(
                icon: Icons.image_outlined,
              );
            }
            if (snapshot.hasError || bytes == null || bytes.isEmpty) {
              return const _ThumbnailPlaceholder(
                icon: Icons.broken_image_outlined,
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        icon,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
