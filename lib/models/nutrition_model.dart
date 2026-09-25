class NutritionLog {
  final String id;
  final String userId;
  final String mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingSize;
  final String? barcode;
  final DateTime loggedAt;
  final String? imagePath;
  final String? imageUrl;

  NutritionLog({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.servingSize = 100,
    this.barcode,
    required this.loggedAt,
    this.imagePath,
    this.imageUrl,
  });

  factory NutritionLog.fromMap(Map<String, dynamic> map) {
    return NutritionLog(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      mealType: map['meal_type'] ?? 'snack',
      foodName: map['food_name'] ?? '',
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0,
      servingSize: (map['serving_size'] as num?)?.toDouble() ?? 100,
      barcode: map['barcode'],
      loggedAt: DateTime.tryParse(map['logged_at'] ?? '') ?? DateTime.now(),
      imagePath: map['image_path'],
      imageUrl: map['image_url'],
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'meal_type': mealType,
    'food_name': foodName,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'serving_size': servingSize,
    'barcode': barcode,
    'logged_at': loggedAt.toIso8601String(),
    'image_path': imagePath,
    'image_url': imageUrl,
  };
}

class UserGoals {
  final String userId;
  final double calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final int waterGoal;
  final bool isVegetarian;
  final bool isVegan;
  final bool isLowCarb;
  final bool isHighProtein;
  final bool isKeto;
  final int stepGoal;

  UserGoals({
    required this.userId,
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.carbsGoal = 250,
    this.fatGoal = 65,
    this.waterGoal = 8,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isLowCarb = false,
    this.isHighProtein = false,
    this.isKeto = false,
    this.stepGoal = 10000,
  });

  factory UserGoals.fromMap(Map<String, dynamic> map) {
    return UserGoals(
      userId: map['user_id'] ?? '',
      calorieGoal: (map['calorie_goal'] as num?)?.toDouble() ?? 2000,
      proteinGoal: (map['protein_goal'] as num?)?.toDouble() ?? 150,
      carbsGoal: (map['carbs_goal'] as num?)?.toDouble() ?? 250,
      fatGoal: (map['fat_goal'] as num?)?.toDouble() ?? 65,
      waterGoal: (map['water_goal'] as num?)?.toInt() ?? 8,
      isVegetarian: map['is_vegetarian'] ?? false,
      isVegan: map['is_vegan'] ?? false,
      isLowCarb: map['is_low_carb'] ?? false,
      isHighProtein: map['is_high_protein'] ?? false,
      isKeto: map['is_keto'] ?? false,
      stepGoal: (map['step_goal'] as num?)?.toInt() ?? 10000,
    );
  }

  // Default fallback when no DB record exists
  factory UserGoals.defaults(String userId) => UserGoals(
    userId: userId,
    stepGoal: 10000,
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'calorie_goal': calorieGoal.toInt(),
    'protein_goal': proteinGoal.toInt(),
    'carbs_goal': carbsGoal.toInt(),
    'fat_goal': fatGoal.toInt(),
    'water_goal': waterGoal.toInt(),
    'is_vegetarian': isVegetarian,
    'is_vegan': isVegan,
    'is_low_carb': isLowCarb,
    'is_high_protein': isHighProtein,
    'is_keto': isKeto,
    'step_goal': stepGoal,
  };
}

class DailyHealthData {
  final String userId;
  final int steps;
  final double caloriesBurned;
  final int waterIntake;
  final int? heartRate;
  final String source; // 'manual' | 'pedometer'
  final DateTime recordedAt;

  DailyHealthData({
    required this.userId,
    this.steps = 0,
    this.caloriesBurned = 0,
    this.waterIntake = 0,
    this.heartRate,
    this.source = 'manual',
    required this.recordedAt,
  });

  factory DailyHealthData.fromMap(Map<String, dynamic> map) {
    return DailyHealthData(
      userId: map['user_id'] ?? '',
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      caloriesBurned: (map['calories_burned'] as num?)?.toDouble() ?? 0,
      waterIntake: (map['water_intake'] as num?)?.toInt() ?? 0,
      source: map['source'] ?? 'manual',
      recordedAt: DateTime.tryParse(map['recorded_at'] ?? '') ?? DateTime.now(),
    );
  }

  factory DailyHealthData.empty(String userId) => DailyHealthData(
    userId: userId,
    steps: 0,
    caloriesBurned: 0,
    waterIntake: 0,
    recordedAt: DateTime.now(),
  );
}
