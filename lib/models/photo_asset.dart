class PhotoAsset {
  const PhotoAsset({
    required this.assetId,
    this.createdAt,
    this.width,
    this.height,
    this.title,
  });

  final String assetId;
  final DateTime? createdAt;
  final int? width;
  final int? height;
  final String? title;
}
