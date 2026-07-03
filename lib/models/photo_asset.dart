class PhotoAsset {
  const PhotoAsset({
    required this.assetId,
    this.createdAt,
  });

  final String assetId;
  final DateTime? createdAt;
}
