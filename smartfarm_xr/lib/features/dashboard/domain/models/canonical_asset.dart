class CanonicalAsset {
  final String assetId;
  final String name;
  final String geometryType;
  final String assetType;
  final String category;
  final Map<String, dynamic> raw;

  const CanonicalAsset({
    required this.assetId,
    required this.name,
    required this.geometryType,
    required this.assetType,
    required this.category,
    required this.raw,
  });

  factory CanonicalAsset.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> properties =
        (map['properties'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final Map<String, dynamic> meta =
        (properties['meta'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final Map<String, dynamic> geometry =
        (map['geometry'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final String resolvedAssetId = (map['asset_id'] ??
            properties['asset_id'] ??
            meta['asset_id'] ??
            '')
        .toString();
    return CanonicalAsset(
      assetId: resolvedAssetId,
      name: (map['name'] ?? '').toString(),
      geometryType: (geometry['type'] ?? '').toString(),
      assetType: (meta['asset_type'] ?? '').toString(),
      category: (meta['category'] ?? '').toString(),
      raw: Map<String, dynamic>.from(map),
    );
  }
}
