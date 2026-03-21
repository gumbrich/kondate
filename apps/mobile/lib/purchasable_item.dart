enum PurchasableCategory {
  gemuese,
  obst,
  fleisch,
  fisch,
  milchprodukte,
  trockenwaren,
  konserven,
  gewuerze,
  getraenke,
  sonstiges,
}

class PurchasableItem {
  final String displayName;
  final PurchasableCategory category;
  final String shopSearchQuery;
  final String coopSearchQuery;
  final String? coopPreferredSearchQuery;
  final String? coopPreferredProductLabel;
  final double quantity;
  final String unit;
  final String? preferredPackage;
  final String? purchaseHeuristic;
  final String? note;

  const PurchasableItem({
    required this.displayName,
    required this.category,
    required this.shopSearchQuery,
    required this.coopSearchQuery,
    this.coopPreferredSearchQuery,
    this.coopPreferredProductLabel,
    required this.quantity,
    required this.unit,
    this.preferredPackage,
    this.purchaseHeuristic,
    this.note,
  });
}
