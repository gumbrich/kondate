class CoopSavedProduct {
  final String canonicalKey;
  final String productLabel;
  final String productUrl;

  const CoopSavedProduct({
    required this.canonicalKey,
    required this.productLabel,
    required this.productUrl,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'canonicalKey': canonicalKey,
      'productLabel': productLabel,
      'productUrl': productUrl,
    };
  }

  factory CoopSavedProduct.fromJson(Map<String, dynamic> json) {
    return CoopSavedProduct(
      canonicalKey: json['canonicalKey'] as String? ?? '',
      productLabel: json['productLabel'] as String? ?? '',
      productUrl: json['productUrl'] as String? ?? '',
    );
  }
}
