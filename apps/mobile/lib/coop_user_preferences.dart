class CoopUserPreferenceOverride {
  final String canonicalKey;
  final String preferredSearchQuery;
  final String preferredProductLabel;

  const CoopUserPreferenceOverride({
    required this.canonicalKey,
    required this.preferredSearchQuery,
    required this.preferredProductLabel,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'canonicalKey': canonicalKey,
      'preferredSearchQuery': preferredSearchQuery,
      'preferredProductLabel': preferredProductLabel,
    };
  }

  factory CoopUserPreferenceOverride.fromJson(Map<String, dynamic> json) {
    return CoopUserPreferenceOverride(
      canonicalKey: json['canonicalKey'] as String? ?? '',
      preferredSearchQuery: json['preferredSearchQuery'] as String? ?? '',
      preferredProductLabel: json['preferredProductLabel'] as String? ?? '',
    );
  }
}
