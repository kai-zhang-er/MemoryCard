import 'package:flutter/material.dart';

import '../services/export_service.dart';
import '../services/memory_repository.dart';
import '../services/photo_library_service.dart';
import 'memory_card_screen.dart';
import 'memory_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.photoLibraryServiceFactory,
    this.exportServiceFactory,
  });

  final MemoryRepository repository;
  final PhotoLibraryService Function() photoLibraryServiceFactory;
  final ExportService Function(MemoryRepository repository)?
      exportServiceFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('\u8bb0\u5fc6\u5361')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Memory Cards',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openMemoryCard(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('\u5f00\u59cb\u4e00\u5c40'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openMemoryCard(sessionLimit: 5),
              icon: const Icon(Icons.today_outlined),
              label: const Text('\u4eca\u65e5 5 \u5f20'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.all),
              icon: const Icon(Icons.list_alt),
              label: const Text('\u8bb0\u5fc6\u5217\u8868'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.important),
              icon: const Icon(Icons.star_outline),
              label: const Text('\u91cd\u8981\u7167\u7247'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openList(MemoryListFilter.deleteCandidates),
              icon: const Icon(Icons.delete_outline),
              label: const Text('\u5f85\u5220\u9664'),
            ),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportMemories,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(
                _isExporting
                    ? '\u5bfc\u51fa\u4e2d...'
                    : '\u5bfc\u51fa\u8d44\u6599',
              ),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '\u7167\u7247\u53ea\u8bfb\u663e\u793a\uff1b\u5f55\u97f3\u548c\u8bb0\u5fc6\u6570\u636e\u53ea\u4fdd\u5b58\u5728\u672c\u673a\uff0c\u4e0d\u4e0a\u4f20\u3002',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMemories() async {
    setState(() => _isExporting = true);
    try {
      final service = widget.exportServiceFactory?.call(widget.repository) ??
          ExportService(widget.repository);
      final result = await service.exportMemories();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('\u5df2\u5bfc\u51fa\uff1a${result.exportDirectory.path}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\u5bfc\u51fa\u5931\u8d25\uff1a$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _openMemoryCard({int? sessionLimit}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryCardScreen(
          photoLibraryService: widget.photoLibraryServiceFactory(),
          memoryRepository: widget.repository,
          sessionLimit: sessionLimit,
        ),
      ),
    );
  }

  void _openList(MemoryListFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryListScreen(
          repository: widget.repository,
          filter: filter,
          photoLibraryService: widget.photoLibraryServiceFactory(),
        ),
      ),
    );
  }
}
