import 'package:flutter/material.dart';

import '../models/memory_record.dart';
import '../services/audio_playback_service.dart';
import '../services/memory_repository.dart';
import '../services/photo_library_service.dart';
import '../utils/date_utils.dart';
import '../widgets/audio_player_tile.dart';
import '../widgets/memory_thumbnail.dart';
import '../widgets/record_status_chips.dart';
import 'memory_detail_screen.dart';

class MemoryListScreen extends StatefulWidget {
  const MemoryListScreen({
    super.key,
    required this.repository,
    required this.filter,
    required this.photoLibraryService,
    this.audioPlaybackControllerFactory = createAudioPlaybackController,
  });

  final MemoryRepository repository;
  final MemoryListFilter filter;
  final PhotoLibraryService photoLibraryService;
  final AudioPlaybackController Function() audioPlaybackControllerFactory;

  @override
  State<MemoryListScreen> createState() => _MemoryListScreenState();
}

class _MemoryListScreenState extends State<MemoryListScreen> {
  late Future<List<MemoryRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.filter.title)),
      body: FutureBuilder<List<MemoryRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('\u8bfb\u53d6\u5931\u8d25\uff1a${snapshot.error}'));
          }

          final records = snapshot.data ?? const <MemoryRecord>[];
          if (records.isEmpty) {
            return const Center(
              child: Text(
                  '\u8fd8\u6ca1\u6709\u8bb0\u5fc6\u8bb0\u5f55\u3002\u56de\u5230\u9996\u9875\u5f00\u59cb\u4e00\u5c40\u5427\u3002'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  child: ListTile(
                    onTap: () => _openDetail(record),
                    leading: MemoryThumbnail(
                      assetId: record.assetId,
                      photoLibraryService: widget.photoLibraryService,
                    ),
                    title: const Text('\u7167\u7247\u8bb0\u5fc6'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                            '\u62cd\u6444\u65f6\u95f4: ${formatNullableDate(record.photoTime)}'),
                        Text('Asset ID: ${record.assetId}'),
                        Text('Memory ID: ${record.memoryId}'),
                        Text(
                            '\u66f4\u65b0\u65f6\u95f4: ${record.updatedAt.toLocal()}'),
                        const SizedBox(height: 8),
                        RecordStatusChips(record: record),
                        if (record.audioPath != null &&
                            record.audioPath!.trim().isNotEmpty)
                          AudioPlayerTile(
                            audioPath: record.audioPath!,
                            controllerFactory:
                                widget.audioPlaybackControllerFactory,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<List<MemoryRecord>> _loadRecords() {
    return switch (widget.filter) {
      MemoryListFilter.all => widget.repository.getAll(),
      MemoryListFilter.important => widget.repository.getImportant(),
      MemoryListFilter.deleteCandidates =>
        widget.repository.getDeleteCandidates(),
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _recordsFuture = _loadRecords();
    });
    await _recordsFuture;
  }

  Future<void> _openDetail(MemoryRecord record) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => MemoryDetailScreen(
          initialRecord: record,
          repository: widget.repository,
          photoLibraryService: widget.photoLibraryService,
          audioPlaybackControllerFactory: widget.audioPlaybackControllerFactory,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _refresh();
  }
}

enum MemoryListFilter {
  all('\u8bb0\u5fc6\u5217\u8868'),
  important('\u91cd\u8981\u7167\u7247'),
  deleteCandidates('\u5f85\u5220\u9664');

  const MemoryListFilter(this.title);

  final String title;
}
