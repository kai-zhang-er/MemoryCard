import 'package:flutter/material.dart';

import '../models/memory_record.dart';
import '../services/audio_playback_service.dart';
import '../services/memory_repository.dart';
import '../widgets/audio_player_tile.dart';
import '../widgets/record_status_chips.dart';

class MemoryListScreen extends StatefulWidget {
  const MemoryListScreen({
    super.key,
    required this.repository,
    required this.filter,
    this.audioPlaybackControllerFactory = createAudioPlaybackController,
  });

  final MemoryRepository repository;
  final MemoryListFilter filter;
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
            return Center(child: Text('读取失败：${snapshot.error}'));
          }

          final records = snapshot.data ?? const <MemoryRecord>[];
          if (records.isEmpty) {
            return const Center(
              child: Text('还没有记录。回到首页开始一局，或添加一条假记忆验证数据库。'),
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
                    title: Text(record.assetId),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text('Memory ID: ${record.memoryId}'),
                        Text('更新时间: ${record.updatedAt.toLocal()}'),
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
}

enum MemoryListFilter {
  all('记忆列表'),
  important('重要照片'),
  deleteCandidates('待删除');

  const MemoryListFilter(this.title);

  final String title;
}
