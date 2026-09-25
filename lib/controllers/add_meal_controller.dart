import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_model.dart';
import '../models/food_item_model.dart';
import '../services/gemini_service.dart';
import 'nutrition_controller.dart';
import '../screens/health/food_camera_screen.dart';

class AddMealController extends GetxController {
  final SupabaseClient _client = Supabase.instance.client;

  // ─── State ────────────────────────────────────────────────────────────────────
  final RxString selectedMealType = 'breakfast'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isScanning = false.obs;

  final RxList<FoodItem> searchResults = <FoodItem>[].obs;
  final RxList<MealCartItem> cartItems = <MealCartItem>[].obs;
  final Rx<NutritionLog?> editingLog = Rx<NutritionLog?>(null);

  final TextEditingController searchController = TextEditingController();

  // ─── Computed ─────────────────────────────────────────────────────────────────
  double get totalCalories => cartItems.fold(0, (s, i) => s + i.calories);
  double get totalProtein  => cartItems.fold(0, (s, i) => s + i.protein);
  double get totalCarbs    => cartItems.fold(0, (s, i) => s + i.carbs);
  double get totalFat      => cartItems.fold(0, (s, i) => s + i.fat);
  bool   get cartIsEmpty   => cartItems.isEmpty;

  String get userId => _client.auth.currentUser?.id ?? '';

  // ─── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  // ─── Edit mode ────────────────────────────────────────────────────────────────
  void initEditMode(NutritionLog log) {
    editingLog.value = log;
    selectedMealType.value = log.mealType;

    final fakeFoodItem = FoodItem(
      id: log.id,
      name: log.foodName,
      caloriesPer100g: log.calories / (log.servingSize / 100),
      proteinPer100g:  log.protein  / (log.servingSize / 100),
      carbsPer100g:    log.carbs    / (log.servingSize / 100),
      fatPer100g:      log.fat      / (log.servingSize / 100),
      barcode: log.barcode,
    );

    cartItems.add(MealCartItem(
      cartId: 'edit_${log.id}',
      food: fakeFoodItem,
      initialServing: log.servingSize,
    ));
  }

  // ─── Meal Type ────────────────────────────────────────────────────────────────
  void selectMealType(String type) => selectedMealType.value = type;

  // ─── Search ───────────────────────────────────────────────────────────────────
  Future<void> triggerSearch() async {
    final q = searchController.text.trim();
    if (q.isEmpty) return;
    searchQuery.value = q;
    // Small delay ensures keyboard submit has finished
    await Future.delayed(const Duration(milliseconds: 100));
    await _runSearch();
  }

  void onSearchChanged(String query) {
    // Only clear results if user clears the field
    if (query.isEmpty) {
      searchQuery.value = '';
      searchResults.clear();
    }
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    searchResults.clear();
  }

  Future<void> scanBarcode() async {
    isScanning.value = true;
    try {
      final Map<String, dynamic>? foodData = await Get.to(
            () => const FoodCameraScreen(),
        transition: Transition.downToUp,
      );

      if (foodData != null && foodData.isNotEmpty) {
        final estimatedGrams = (foodData['estimated_grams'] ?? 100).toDouble();
        final factor = estimatedGrams > 0 ? (100 / estimatedGrams) : 1.0;

        final proteinPer100g = (foodData['protein_per_serving'] ?? 0).toDouble() * factor;
        final carbsPer100g   = (foodData['carbs_per_serving']   ?? 0).toDouble() * factor;
        final fatPer100g     = (foodData['fat_per_serving']     ?? 0).toDouble() * factor;
        final caloriesPer100g = (proteinPer100g * 4) + (carbsPer100g * 4) + (fatPer100g * 9);

        final food = FoodItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: foodData['food_name'] ?? 'Unknown Food',
          caloriesPer100g: caloriesPer100g,
          proteinPer100g:  proteinPer100g,
          carbsPer100g:    carbsPer100g,
          fatPer100g:      fatPer100g,
        );
        addToCart(food,
            imagePath: foodData['image_path'],
            imageUrl: foodData['image_url']);

        final cartId = cartItems.last.cartId;
        updateServing(cartId, estimatedGrams);
      }
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> _runSearch() async {
    // Use controller text as backup in case searchQuery wasn't set yet
    final q = searchQuery.value.trim().isNotEmpty
        ? searchQuery.value.trim()
        : searchController.text.trim();
    if (q.isEmpty) { searchResults.clear(); return; }

    isSearching.value = true;
    searchResults.clear();

    try {
      // 1. Try Supabase first
      final data = await _client
          .from('food_items')
          .select()
          .ilike('name', '%$q%')
          .limit(20);

      final supabaseResults =
      (data as List).map((e) => FoodItem.fromMap(e)).toList();

      if (supabaseResults.isNotEmpty) {
        searchResults.value = supabaseResults;
        return;
      }

      // 2. Try Gemini AI
      final geminiResult = await GeminiService.searchFoodNutrition(q);

      if (geminiResult == null) {
        searchResults.value = [];
        return;
      }

      if (geminiResult['error'] == 'rate_limit') {
        Get.snackbar('⚠️ Too Many Requests',
            'Please wait a moment and try again.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.shade400,
            colorText: Colors.white);
        searchResults.value = [];
        return;
      }

      if (geminiResult['error'] == 'quota_exceeded') {
        Get.snackbar('⚠️ AI Credit Exhausted',
            'Daily AI search limit reached. Try again tomorrow.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.shade400,
            colorText: Colors.white);
        searchResults.value = [];
        return;
      }

      if (geminiResult['error'] != null) {
        Get.snackbar('❌ Search Failed',
            'Could not find nutrition data. Try a different term.',
            snackPosition: SnackPosition.TOP);
        searchResults.value = [];
        return;
      }

      final food = FoodItem(
        id: '',
        name: geminiResult['food_name'] ?? q,
        brand: 'AI Estimated',
        caloriesPer100g: (geminiResult['calories_per_100g'] as num?)?.toDouble() ?? 0,
        proteinPer100g:  (geminiResult['protein_per_100g']  as num?)?.toDouble() ?? 0,
        carbsPer100g:    (geminiResult['carbs_per_100g']    as num?)?.toDouble() ?? 0,
        fatPer100g:      (geminiResult['fat_per_100g']      as num?)?.toDouble() ?? 0,
      );

      searchResults.value = [food];
      await _cacheFoodToSupabase(food,
          servingSize: (geminiResult['serving_size_g'] as num?)?.toDouble() ?? 100);
    } catch (e) {
      print('=== SEARCH ERROR: $e ===');
      searchResults.value = [];
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> _cacheFoodToSupabase(FoodItem food, {double servingSize = 100}) async {
    try {
      await _client.from('food_items').insert({
        'name':              food.name,
        'brand':             food.brand,
        'calories_per_100g': food.caloriesPer100g,
        'protein_per_100g':  food.proteinPer100g,
        'carbs_per_100g':    food.carbsPer100g,
        'fat_per_100g':      food.fatPer100g,
      });
    } catch (e) {
      print('=== CACHE ERROR: $e ===');
    }
  }

  // ─── Cart Management ──────────────────────────────────────────────────────────
  void addToCart(FoodItem food, {String? imagePath, String? imageUrl}) {
    final exists = cartItems.any((i) => i.food.id == food.id);
    if (exists) {
      Get.snackbar('Already Added', '${food.name} is already in this meal.',
          snackPosition: SnackPosition.TOP);
      return;
    }

    cartItems.add(MealCartItem(
      cartId: '${food.id}_${DateTime.now().millisecondsSinceEpoch}',
      food: food,
      initialServing: 100,
      imagePath: imagePath,
      imageUrl: imageUrl,
    ));
    clearSearch();
  }

  void updateServing(String cartId, double grams) {
    final item = cartItems.firstWhereOrNull((i) => i.cartId == cartId);
    if (item == null) return;
    // Clear any manual override so macros go back to being weight-based
    item.clearMacroOverride();
    item.servingGrams.value = grams.clamp(1, 9999);
    cartItems.refresh();
  }

  /// Called when user manually edits P/C/F in the override fields.
  /// Stores the values directly on the item and refreshes the list.
  void updateMacros(String cartId, double protein, double carbs, double fat) {
    final item = cartItems.firstWhereOrNull((i) => i.cartId == cartId);
    if (item == null) return;
    item.setMacroOverride(protein, carbs, fat);
    cartItems.refresh();
  }

  /// Called when user toggles back from manual mode to serving mode.
  void clearMacroOverride(String cartId) {
    final item = cartItems.firstWhereOrNull((i) => i.cartId == cartId);
    if (item == null) return;
    item.clearMacroOverride();
    cartItems.refresh();
  }

  void removeFromCart(String cartId) {
    cartItems.removeWhere((i) => i.cartId == cartId);
  }

  void toggleEditing(String cartId) {
    for (final item in cartItems) {
      item.isEditing.value =
      (item.cartId == cartId) ? !item.isEditing.value : false;
    }
  }

  // ─── Save / Update ────────────────────────────────────────────────────────────
  Future<void> saveMeal() async {
    if (cartItems.isEmpty) {
      Get.snackbar('⚠️ Empty', 'Add at least one food item before saving.',
          snackPosition: SnackPosition.TOP);
      return;
    }

    isSaving.value = true;
    try {
      if (editingLog.value != null) {
        await _updateLog();
      } else {
        await _insertAllCartItems();
      }

      if (Get.isRegistered<NutritionController>()) {
        await Get.find<NutritionController>().loadDashboard();
      }

      Get.back();
      Get.snackbar(
        'Meal Saved',
        '${cartItems.length} item(s) logged to ${_mealLabel(selectedMealType.value)}.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: const Color(0xFFFFFFFF),
      );
    } catch (e) {
      Get.snackbar('❌ Error', 'Failed to save: $e',
          snackPosition: SnackPosition.TOP);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _insertAllCartItems() async {
    final rows = cartItems
        .map((item) => item
        .toNutritionLog(userId: userId, mealType: selectedMealType.value)
        .toMap())
        .toList();
    await _client.from('nutrition_logs').insert(rows);
  }

  Future<void> _updateLog() async {
    final log = editingLog.value!;
    final item = cartItems.first;
    await _client.from('nutrition_logs').update({
      'meal_type':   selectedMealType.value,
      'food_name':   item.foodName.value,
      'calories':    item.calories,
      'protein':     item.protein,
      'carbs':       item.carbs,
      'fat':         item.fat,
      'serving_size': item.servingGrams.value,
    }).eq('id', log.id);
  }

  Future<void> deleteLog(String logId) async {
    try {
      await _client.from('nutrition_logs').delete().eq('id', logId);
      if (Get.isRegistered<NutritionController>()) {
        final nc = Get.find<NutritionController>();
        nc.todayLogs.removeWhere((l) => l.id == logId);
        nc.loadDashboard();
      }
      Get.snackbar('🗑️ Deleted', 'Food item removed.',
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar('❌ Error', 'Delete failed: $e',
          snackPosition: SnackPosition.TOP);
    }
  }

  String _mealLabel(String type) {
    return const {
      'breakfast': 'Breakfast',
      'lunch':     'Lunch',
      'dinner':    'Dinner',
      'snack':     'Snack',
    }[type] ?? type;
  }
}