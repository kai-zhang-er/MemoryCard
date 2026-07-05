import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/memory_record.dart';
import '../services/audio_playback_service.dart';
import '../services/memory_repository.dart';
import '../services/photo_library_service.dart';
import '../services/recording_file_service.dart';
import '../utils/date_utils.dart';
import '../widgets/audio_player_tile.dart';

class MemoryDetailScreen extends StatefulWidget {
  const MemoryDetailScreen({
    super.key,
    required this.initialRecord,
    required this.repository,
    required this.photoLibraryService,
    this.audioPlaybackControllerFactory = createAudioPlaybackController,
    this.recordingFileService = const RecordingFileService(),
  });

  final MemoryRecord initialRecord;
  final MemoryRepository repository;
  final PhotoLibraryService photoLibraryService;
  final AudioPlaybackController Function() audioPlaybackControllerFactory;
  final RecordingFileService recordingFileService;

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  static const List<String> _quickTags = [
    '\u65c5\u884c',
    '\u5bb6\u4eba',
    '\u670b\u53cb',
    '\u805a\u4f1a',
    '\u5b66\u6821',
    '\u5de5\u4f5c',
    '\u65e5\u5e38',
    '\u7f8e\u98df',
    '\u98ce\u666f',
    '\u4e0d\u786e\u5b9a',
  ];

  late MemoryRecord _record;
  bool _isSaving = false;
  bool _isDeletingAudio = false;

  @override
  void initState() {
    super.initState();
    _record = widget.initialRecord;
    _reloadRecord();
  }

  @override
  Widget build(BuildContext context) {
    final audioPath = _record.audioPath;
    return Scaffold(
      appBar: AppBar(title: const Text('\u8bb0\u5fc6\u8be6\u60c5')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ThumbnailPreview(
              assetId: _record.assetId,
              photoLibraryService: widget.photoLibraryService,
            ),
            const SizedBox(height: 16),
            Text(
                '\u62cd\u6444\u65f6\u95f4\uff1a${formatNullableDate(_record.photoTime)}'),
            const SizedBox(height: 4),
            Text(
              'Asset ID: ${_record.assetId}\nMemory ID: ${_record.memoryId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text('\u6807\u7b7e',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _quickTags)
                  FilterChip(
                    label: Text(tag),
                    selected: _record.userTags.contains(tag),
                    onSelected: _isSaving
                        ? null
                        : (selected) => _toggleTag(tag, selected),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('\u72b6\u6001',
                style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('\u91cd\u8981'),
              value: _record.important,
              onChanged: _isSaving
                  ? null
                  : (value) => _updateRecord(
                        _record.copyWith(important: value),
                      ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('\u5f85\u5220\u9664'),
              subtitle: const Text(
                  '\u53ea\u6807\u8bb0\uff0c\u4e0d\u5220\u9664\u539f\u59cb\u7167\u7247'),
              value: _record.deleteCandidate,
              onChanged: _isSaving
                  ? null
                  : (value) => _updateRecord(
                        _record.copyWith(deleteCandidate: value),
                      ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('\u5df2\u8df3\u8fc7'),
              value: _record.skipped,
              onChanged: _isSaving
                  ? null
                  : (value) => _updateRecord(
                        _record.copyWith(
                          skipped: value,
                          reviewStatus: value ? 'skipped' : 'raw',
                        ),
                      ),
            ),
            const SizedBox(height: 20),
            Text('\u5f55\u97f3',
                style: Theme.of(context).textTheme.titleMedium),
            if (audioPath != null && audioPath.trim().isNotEmpty) ...[
              AudioPlayerTile(
                audioPath: audioPath,
                controllerFactory: widget.audioPlaybackControllerFactory,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isDeletingAudio ? null : _deleteAudio,
                icon: const Icon(Icons.volume_off_outlined),
                label: Text(_isDeletingAudio
                    ? '\u5220\u9664\u4e2d...'
                    : '\u5220\u9664\u5f55\u97f3'),
              ),
            ] else
              const Text('\u8fd8\u6ca1\u6709\u5f55\u97f3\u3002'),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _confirmDeleteMemory,
              icon: const Icon(Icons.delete_outline),
              label: const Text(
                  '\u5220\u9664\u8fd9\u6761\u8bb0\u5fc6\u8bb0\u5f55'),
            ),
            const SizedBox(height: 8),
            const Text(
              '\u8fd9\u91cc\u53ea\u4f1a\u7f16\u8f91\u6216\u5220\u9664 App \u5185\u7684\u8bb0\u5fc6\u8bb0\u5f55\uff0c\u4e0d\u4f1a\u4fee\u6539\u6216\u5220\u9664\u539f\u59cb\u7167\u7247\u3002',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reloadRecord() async {
    final latest = await widget.repository.getByMemoryId(_record.memoryId);
    if (!mounted || latest == null) {
      return;
    }
    setState(() => _record = latest);
  }

  Future<void> _toggleTag(String tag, bool selected) async {
    final tags = {..._record.userTags};
    if (selected) {
      tags.add(tag);
    } else {
      tags.remove(tag);
    }
    await _updateRecord(
      _record.copyWith(userTags: tags.toList(growable: false)),
    );
  }

  Future<void> _updateRecord(MemoryRecord updated) async {
    setState(() => _isSaving = true);
    final record = updated.copyWith(updatedAt: DateTime.now());
    try {
      await widget.repository.upsert(record);
      if (!mounted) {
        return;
      }
      setState(() {
        _record = record;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\u4fdd\u5b58\u5931\u8d25\uff1a$error')),
      );
    }
  }

  Future<void> _deleteAudio() async {
    setState(() => _isDeletingAudio = true);
    try {
      await widget.recordingFileService.deleteIfExists(_record.audioPath);
      final updated = _record.copyWith(
        clearAudioPath: true,
        updatedAt: DateTime.now(),
      );
      await widget.repository.upsert(updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _record = updated;
        _isDeletingAudio = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isDeletingAudio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('\u5220\u9664\u5f55\u97f3\u5931\u8d25\uff1a$error')),
      );
    }
  }

  Future<void> _confirmDeleteMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u5220\u9664\u8bb0\u5fc6\u8bb0\u5f55\uff1f'),
        content: const Text(
          '\u8fd9\u53ea\u4f1a\u5220\u9664 App \u91cc\u7684\u8bb0\u5fc6\u8bb0\u5f55\uff0c\u4e0d\u4f1a\u5220\u9664\u6216\u4fee\u6539\u539f\u59cb\u7167\u7247\u3002',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('\u5220\u9664\u8bb0\u5f55'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }
    await widget.repository.deleteByMemoryId(_record.memoryId);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }
}

class _ThumbnailPreview extends StatelessWidget {
  const _ThumbnailPreview({
    required this.assetId,
    required this.photoLibraryService,
  });

  final String assetId;
  final PhotoLibraryService photoLibraryService;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.black,
          child: FutureBuilder<Uint8List?>(
            future: photoLibraryService.getThumbnail(assetId, size: 900),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || bytes == null || bytes.isEmpty) {
                return const Center(child: Icon(Icons.broken_image_outlined));
              }
              return Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              );
            },
          ),
        ),
      ),
    );
  }
}
