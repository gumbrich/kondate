class CoopProductPreference {
  final String canonicalKey;
  final String preferredSearchQuery;
  final String preferredProductLabel;

  const CoopProductPreference({
    required this.canonicalKey,
    required this.preferredSearchQuery,
    required this.preferredProductLabel,
  });
}

class CoopProductPreferences {
  static const List<CoopProductPreference> defaults =
      <CoopProductPreference>[
    CoopProductPreference(
      canonicalKey: 'stückige tomaten',
      preferredSearchQuery: 'stückige tomaten 400g',
      preferredProductLabel: 'Stückige Tomaten, Dose 400 g',
    ),
    CoopProductPreference(
      canonicalKey: 'gehackte tomaten',
      preferredSearchQuery: 'gehackte tomaten 400g',
      preferredProductLabel: 'Gehackte Tomaten, Dose 400 g',
    ),
    CoopProductPreference(
      canonicalKey: 'geschälte tomaten',
      preferredSearchQuery: 'geschälte tomaten 400g',
      preferredProductLabel: 'Geschälte Tomaten, Dose 400 g',
    ),
    CoopProductPreference(
      canonicalKey: 'passierte tomaten',
      preferredSearchQuery: 'passierte tomaten 500g',
      preferredProductLabel: 'Passierte Tomaten, 500 g',
    ),
    CoopProductPreference(
      canonicalKey: 'gemischtes hackfleisch',
      preferredSearchQuery: 'hackfleisch gemischt 500g',
      preferredProductLabel: 'Hackfleisch gemischt, 500 g',
    ),
    CoopProductPreference(
      canonicalKey: 'milch',
      preferredSearchQuery: 'milch 1l',
      preferredProductLabel: 'Milch, 1 l',
    ),
    CoopProductPreference(
      canonicalKey: 'sahne',
      preferredSearchQuery: 'rahm 200ml',
      preferredProductLabel: 'Rahm, 200 ml',
    ),
    CoopProductPreference(
      canonicalKey: 'joghurt',
      preferredSearchQuery: 'nature joghurt 500g',
      preferredProductLabel: 'Nature Joghurt, 500 g',
    ),
    CoopProductPreference(
      canonicalKey: 'parmesan',
      preferredSearchQuery: 'parmesan gerieben',
      preferredProductLabel: 'Parmesan, gerieben',
    ),
    CoopProductPreference(
      canonicalKey: 'mozzarella',
      preferredSearchQuery: 'mozzarella',
      preferredProductLabel: 'Mozzarella',
    ),
    CoopProductPreference(
      canonicalKey: 'kartoffel_festkochend',
      preferredSearchQuery: 'kartoffeln festkochend',
      preferredProductLabel: 'Kartoffeln, festkochend',
    ),
    CoopProductPreference(
      canonicalKey: 'paprika_rot',
      preferredSearchQuery: 'paprika rot',
      preferredProductLabel: 'Paprika rot',
    ),
    CoopProductPreference(
      canonicalKey: 'paprika_gelb',
      preferredSearchQuery: 'paprika gelb',
      preferredProductLabel: 'Paprika gelb',
    ),
  ];

  static CoopProductPreference? findByCanonicalKey(String canonicalKey) {
    for (final CoopProductPreference preference in defaults) {
      if (preference.canonicalKey == canonicalKey) {
        return preference;
      }
    }
    return null;
  }
}
