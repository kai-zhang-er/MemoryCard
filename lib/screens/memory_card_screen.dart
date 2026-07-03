import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/photo_asset.dart';
import '../services/photo_library_service.dart';
import '../utils/date_utils.dart';
import '../widgets/photo_card.dart';

class MemoryCardScreen extends StatefulWidget {
  MemoryCardScreen({
    super.key,
    required this.photoLibraryService,
    Random? random,
  }) : random = random ?? Random();

  final PhotoLibraryService photoLibraryService;
  final Random random;

  @override
  State<MemoryCardScreen> createState() => _MemoryCardScreenState();
}

class _MemoryCardScreenState extends State<MemoryCardScreen> {
  MemoryCardState _state = MemoryCardState.loading;
  PhotoPermissionResult? _permission;
  List<PhotoAsset> _assets = const [];
  PhotoAsset? _currentAsset;
  Uint8List? _thumbnailBytes;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开始一局')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_state) {
            MemoryCardState.loading => const _CenteredMessage(
                icon: Icons.photo_library_outlined,
                title: '正在读取本地照片',
                message: '只读取缩略图和元数据，不保存原始照片。',
                showProgress: true,
              ),
            MemoryCardState.permissionDenied => _PermissionDeniedView(
                onRetry: _loadLibrary,
                onOpenSettings: widget.photoLibraryService.openSettings,
              ),
            MemoryCardState.empty => _CenteredMessage(
                icon: Icons.image_not_supported_outlined,
                title: '没有可用照片',
                message: _permission == PhotoPermissionResult.limited
                    ? '当前只授权了部分照片，但没有可显示的图片。'
                    : '相册里暂时没有找到图片。',
              ),
            MemoryCardState.thumbnailFailed => _CenteredMessage(
                icon: Icons.broken_image_outlined,
                title: '缩略图加载失败',
                message: _errorMessage ?? '这张照片暂时无法显示，请换一张。',
                actionLabel: '换一张',
                onAction: _pickRandomPhoto,
              ),
            MemoryCardState.loaded => _LoadedPhotoView(
                asset: _currentAsset!,
                thumbnailBytes: _thumbnailBytes!,
                isLimited: _permission == PhotoPermissionResult.limited,
                onPickAnother: _pickRandomPhoto,
              ),
          },
        ),
      ),
    );
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _state = MemoryCardState.loading;
      _errorMessage = null;
    });

    try {
      final permission = await widget.photoLibraryService.requestPermission();
      _permission = permission;
      if (!permission.canAccessPhotos) {
        if (!mounted) {
          return;
        }
        setState(() => _state = MemoryCardState.permissionDenied);
        return;
      }

      final assets = await widget.photoLibraryService.getPhotoAssets();
      if (!mounted) {
        return;
      }
      if (assets.isEmpty) {
        setState(() {
          _assets = const [];
          _state = MemoryCardState.empty;
        });
        return;
      }

      _assets = assets;
      await _pickRandomPhoto();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _state = MemoryCardState.thumbnailFailed;
      });
    }
  }

  Future<void> _pickRandomPhoto() async {
    if (_assets.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _state = MemoryCardState.empty);
      return;
    }

    setState(() {
      _state = MemoryCardState.loading;
      _errorMessage = null;
    });

    final asset = _assets[widget.random.nextInt(_assets.length)];
    try {
      final thumbnail =
          await widget.photoLibraryService.getThumbnail(asset.assetId);
      if (!mounted) {
        return;
      }
      if (thumbnail == null || thumbnail.isEmpty) {
        setState(() {
          _currentAsset = asset;
          _thumbnailBytes = null;
          _errorMessage = '没有拿到可显示的缩略图。';
          _state = MemoryCardState.thumbnailFailed;
        });
        return;
      }

      setState(() {
        _currentAsset = asset;
        _thumbnailBytes = thumbnail;
        _state = MemoryCardState.loaded;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentAsset = asset;
        _thumbnailBytes = null;
        _errorMessage = error.toString();
        _state = MemoryCardState.thumbnailFailed;
      });
    }
  }
}

enum MemoryCardState {
  loading,
  permissionDenied,
  empty,
  thumbnailFailed,
  loaded,
}

class _LoadedPhotoView extends StatelessWidget {
  const _LoadedPhotoView({
    required this.asset,
    required this.thumbnailBytes,
    required this.isLimited,
    required this.onPickAnother,
  });

  final PhotoAsset asset;
  final Uint8List thumbnailBytes;
  final bool isLimited;
  final VoidCallback onPickAnother;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        PhotoCard(
          child: Image.memory(
            thumbnailBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '这张照片你还记得吗？',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '拍摄时间：${formatNullableDate(asset.createdAt)}',
          textAlign: TextAlign.center,
        ),
        if (asset.title != null && asset.title!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            asset.title!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onPickAnother,
          icon: const Icon(Icons.shuffle),
          label: const Text('换一张'),
        ),
        const SizedBox(height: 12),
        Text(
          isLimited ? '当前是有限相册授权，只会显示你允许访问的照片。' : '照片只读显示，不会复制、修改或上传。',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.onRetry,
    required this.onOpenSettings,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.lock_outline,
      title: '需要相册权限',
      message: 'Memory Cards 只读取本地照片缩略图和拍摄时间，用来展示记忆卡。',
      actionLabel: '重新请求',
      onAction: onRetry,
      secondaryActionLabel: '打开设置',
      onSecondaryAction: onOpenSettings,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (showProgress) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
