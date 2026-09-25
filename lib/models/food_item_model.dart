import 'package:get/get.dart';
import 'nutrition_model.dart';

class FoodItem {
  final String id;
  String name;
  final String brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String? barcode;
  final String? imageUrl;
  final String? imagePath;

  double get calculatedCaloriesPer100g =>
      (proteinPer100g * 4) + (carbsPer100g * 4) + (fatPer100g * 9);

  FoodItem({
    required this.id,
    required this.name,
    this.brand = '',
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.barcode,
    this.imageUrl,
    this.imagePath,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      brand: map['brand'] ?? '',
      caloriesPer100g: (map['calories_per_100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g: (map['protein_per_100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (map['carbs_per_100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (map['fat_per_100g'] as num?)?.toDouble() ?? 0,
      barcode: map['barcode'],
      imageUrl: map['image_url'],
    );
  }

  Map<String, double> nutritionForServing(double grams) {
    final ratio = grams / 100.0;
    return {
      'calories': caloriesPer100g * ratio,
      'protein': proteinPer100g * ratio,
      'carbs': carbsPer100g * ratio,
      'fat': fatPer100g * ratio,
    };
  }

  static List<FoodItem> mockFoods() => [
    FoodItem(id: 'f1', name: 'Chicken Breast', brand: 'Generic', caloriesPer100g: 156.4, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
    FoodItem(id: 'f2', name: 'Brown Rice', brand: 'Generic', caloriesPer100g: 213.8, proteinPer100g: 4.5, carbsPer100g: 44.8, fatPer100g: 1.8),
    FoodItem(id: 'f3', name: 'Oatmeal', brand: 'Quaker', caloriesPer100g: 438.1, proteinPer100g: 16.9, carbsPer100g: 66.3, fatPer100g: 6.9),
    FoodItem(id: 'f4', name: 'Greek Yogurt', brand: 'Chobani', caloriesPer100g: 96.4, proteinPer100g: 9, carbsPer100g: 3.6, fatPer100g: 5),
    FoodItem(id: 'f5', name: 'Banana', brand: 'Fresh', caloriesPer100g: 100.3, proteinPer100g: 1.1, carbsPer100g: 22.8, fatPer100g: 0.3),
    FoodItem(id: 'f6', name: 'Salmon Fillet', brand: 'Fresh', caloriesPer100g: 197.0, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13),
    FoodItem(id: 'f7', name: 'Whole Egg', brand: 'Generic', caloriesPer100g: 155.4, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11),
    FoodItem(id: 'f8', name: 'Avocado', brand: 'Fresh', caloriesPer100g: 170.3, proteinPer100g: 2, carbsPer100g: 8.5, fatPer100g: 14.7),
    FoodItem(id: 'f9', name: 'Sweet Potato', brand: 'Fresh', caloriesPer100g: 86.5, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1),
    FoodItem(id: 'f10', name: 'Almonds', brand: 'Generic', caloriesPer100g: 613.1, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 49.9),
    FoodItem(id: 'f11', name: 'Whey Protein Shake', brand: 'Optimum Nutrition', caloriesPer100g: 384.0, proteinPer100g: 80, carbsPer100g: 7, fatPer100g: 4),
    FoodItem(id: 'f12', name: 'Broccoli', brand: 'Fresh', caloriesPer100g: 41.6, proteinPer100g: 2.8, carbsPer100g: 6.6, fatPer100g: 0.4),
    FoodItem(id: 'f13', name: 'White Rice', brand: 'Generic', caloriesPer100g: 125.5, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
    FoodItem(id: 'f14', name: 'Peanut Butter', brand: 'Skippy', caloriesPer100g: 618.0, proteinPer100g: 25, carbsPer100g: 20, fatPer100g: 50),
    FoodItem(id: 'f15', name: 'Milk (Full Cream)', brand: 'Generic', caloriesPer100g: 61.7, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3),
  ];
}

class MealCartItem {
  final String cartId;
  final FoodItem food;
  final RxDouble servingGrams;
  final RxBool isEditing;
  final RxString foodName;
  final String? imagePath;
  final String? imageUrl;

  // ── Manual override fields (null = use calculated value from servingGrams) ──
  // When set, these take priority over the computed getters below.
  final Rx<double?> _overrideProtein = Rx<double?>(null);
  final Rx<double?> _overrideCarbs   = Rx<double?>(null);
  final Rx<double?> _overrideFat     = Rx<double?>(null);

  MealCartItem({
    required this.cartId,
    required this.food,
    double initialServing = 100,
    bool initialEditing = false,
    this.imagePath,
    this.imageUrl,
  })  : servingGrams = initialServing.obs,
        isEditing = initialEditing.obs,
        foodName = food.name.obs;

  double get calories {
    final p = _overrideProtein.value ?? food.proteinPer100g * servingGrams.value / 100;
    final c = _overrideCarbs.value   ?? food.carbsPer100g   * servingGrams.value / 100;
    final f = _overrideFat.value     ?? food.fatPer100g     * servingGrams.value / 100;
    return (p * 4) + (c * 4) + (f * 9);
  }

  double get protein => _overrideProtein.value ?? food.proteinPer100g * servingGrams.value / 100;
  double get carbs   => _overrideCarbs.value   ?? food.carbsPer100g   * servingGrams.value / 100;
  double get fat     => _overrideFat.value     ?? food.fatPer100g     * servingGrams.value / 100;

  bool get hasMacroOverride =>
      _overrideProtein.value != null ||
          _overrideCarbs.value   != null ||
          _overrideFat.value     != null;

  // ── Called by controller to set manual macros ──────────────────────────────
  void setMacroOverride(double protein, double carbs, double fat) {
    _overrideProtein.value = protein;
    _overrideCarbs.value   = carbs;
    _overrideFat.value     = fat;
  }

  // ── Called when user switches back to serving-size mode ───────────────────
  void clearMacroOverride() {
    _overrideProtein.value = null;
    _overrideCarbs.value   = null;
    _overrideFat.value     = null;
  }

  NutritionLog toNutritionLog({
    required String userId,
    required String mealType,
  }) {
    return NutritionLog(
      id: '',
      userId: userId,
      mealType: mealType,
      foodName: foodName.value,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingSize: servingGrams.value,
      barcode: food.barcode,
      imagePath: imagePath,
      loggedAt: DateTime.now(),
      imageUrl: imageUrl,
    );
  }
}