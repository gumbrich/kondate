import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'coop_saved_product.dart';

class CoopSavedProductsStore {
  static const String _storageKey = 'coop_saved_products_v1';

  Future<Map<String, CoopSavedProduct>> loadSavedProducts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
      return <String, CoopSavedProduct>{};
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <String, CoopSavedProduct>{};
    }

    final Map<String, CoopSavedProduct> result = <String, CoopSavedProduct>{};

    for (final dynamic entry in decoded) {
      if (entry is Map<String, dynamic>) {
        final CoopSavedProduct product = CoopSavedProduct.fromJson(entry);
        if (product.canonicalKey.isNotEmpty) {
          result[product.canonicalKey] = product;
        }
      } else if (entry is Map) {
        final Map<String, dynamic> converted = <String, dynamic>{};
        entry.forEach((dynamic key, dynamic value) {
          converted[key.toString()] = value;
        });
        final CoopSavedProduct product = CoopSavedProduct.fromJson(converted);
        if (product.canonicalKey.isNotEmpty) {
          result[product.canonicalKey] = product;
        }
      }
    }

    return result;
  }

  Future<void> saveSavedProducts(
    Map<String, CoopSavedProduct> products,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> payload = products.values
        .map((CoopSavedProduct product) => product.toJson())
        .toList();

    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<void> saveProduct(CoopSavedProduct product) async {
    final Map<String, CoopSavedProduct> current = await loadSavedProducts();
    current[product.canonicalKey] = product;
    await saveSavedProducts(current);
  }

  Future<void> removeProduct(String canonicalKey) async {
    final Map<String, CoopSavedProduct> current = await loadSavedProducts();
    current.remove(canonicalKey);
    await saveSavedProducts(current);
  }
}
