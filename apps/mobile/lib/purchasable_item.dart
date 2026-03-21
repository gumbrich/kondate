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
  final double quantity;
  final String unit;
  final String? preferredPackage;
  final String? note;

  const PurchasableItem({
    required this.displayName,
    required this.category,
    required this.shopSearchQuery,
    required this.quantity,
    required this.unit,
    this.preferredPackage,
    this.note,
  });
}
