class HouseholdMemberDto {
  final String userId;
  final String displayName;

  const HouseholdMemberDto({
    required this.userId,
    required this.displayName,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
    };
  }

  factory HouseholdMemberDto.fromJson(Map<String, dynamic> json) {
    return HouseholdMemberDto(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
    );
  }
}

class HouseholdDto {
  final String householdId;
  final String name;
  final List<HouseholdMemberDto> members;

  const HouseholdDto({
    required this.householdId,
    required this.name,
    required this.members,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'householdId': householdId,
      'name': name,
      'members': members.map((HouseholdMemberDto m) => m.toJson()).toList(),
    };
  }

  factory HouseholdDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMembers =
        json['members'] as List<dynamic>? ?? <dynamic>[];

    return HouseholdDto(
      householdId: json['householdId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      members: rawMembers
          .whereType<Map<String, dynamic>>()
          .map(HouseholdMemberDto.fromJson)
          .toList(),
    );
  }
}

class MealPlanEntryDto {
  final String weekday;
  final String? dishIdea;
  final String? recipeId;

  const MealPlanEntryDto({
    required this.weekday,
    this.dishIdea,
    this.recipeId,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weekday': weekday,
      'dishIdea': dishIdea,
      'recipeId': recipeId,
    };
  }

  factory MealPlanEntryDto.fromJson(Map<String, dynamic> json) {
    return MealPlanEntryDto(
      weekday: json['weekday'] as String? ?? '',
      dishIdea: json['dishIdea'] as String?,
      recipeId: json['recipeId'] as String?,
    );
  }
}

class TrustedSitesDto {
  final List<String> sites;
  final int topN;

  const TrustedSitesDto({
    required this.sites,
    required this.topN,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sites': sites,
      'topN': topN,
    };
  }

  factory TrustedSitesDto.fromJson(Map<String, dynamic> json) {
    return TrustedSitesDto(
      sites: (json['sites'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      topN: json['topN'] as int? ?? 3,
    );
  }
}

class ShoppingItemStateDto {
  final String itemKey;
  final bool checked;

  const ShoppingItemStateDto({
    required this.itemKey,
    required this.checked,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'itemKey': itemKey,
      'checked': checked,
    };
  }

  factory ShoppingItemStateDto.fromJson(Map<String, dynamic> json) {
    return ShoppingItemStateDto(
      itemKey: json['itemKey'] as String? ?? '',
      checked: json['checked'] as bool? ?? false,
    );
  }
}

class HouseholdSyncSnapshotDto {
  final HouseholdDto household;
  final List<MealPlanEntryDto> mealPlanEntries;
  final TrustedSitesDto trustedSites;
  final List<ShoppingItemStateDto> shoppingItemStates;

  const HouseholdSyncSnapshotDto({
    required this.household,
    required this.mealPlanEntries,
    required this.trustedSites,
    required this.shoppingItemStates,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'household': household.toJson(),
      'mealPlanEntries':
          mealPlanEntries.map((MealPlanEntryDto e) => e.toJson()).toList(),
      'trustedSites': trustedSites.toJson(),
      'shoppingItemStates': shoppingItemStates
          .map((ShoppingItemStateDto s) => s.toJson())
          .toList(),
    };
  }

  factory HouseholdSyncSnapshotDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMealPlan =
        json['mealPlanEntries'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawStates =
        json['shoppingItemStates'] as List<dynamic>? ?? <dynamic>[];

    return HouseholdSyncSnapshotDto(
      household: HouseholdDto.fromJson(
        json['household'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      mealPlanEntries: rawMealPlan
          .whereType<Map<String, dynamic>>()
          .map(MealPlanEntryDto.fromJson)
          .toList(),
      trustedSites: TrustedSitesDto.fromJson(
        json['trustedSites'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      shoppingItemStates: rawStates
          .whereType<Map<String, dynamic>>()
          .map(ShoppingItemStateDto.fromJson)
          .toList(),
    );
  }
}
