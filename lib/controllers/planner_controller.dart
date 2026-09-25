import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../models/grocery_item.dart';
import '../models/meal_model.dart';
import '../models/post_model.dart';
import '../services/local_db_service.dart';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';

class PlannerController extends GetxController {
  final LocalDbService _dbService = LocalDbService();
  final SupabaseService _supabaseService = SupabaseService();

  // Observable states
  var isLoading = false.obs;
  var plannedMeals = <Meal>[].obs;
  var selectedDay = DateTime.now().obs;
  var focusedDay = DateTime.now().obs;
  var searchQuery = "".obs;
  var selectedCategory = "All".obs;
  // State for Grocery
  var groceryList = <GroceryItem>[].obs;
  var priceCache = <String, double>{}.obs;
  double get totalGroceryPrice => groceryList.fold(0, (sum, item) => sum + item.price);
  // Supabase
  var isCloudSaved = false.obs;
  var cloudSavedMeals = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchMealsForDate(selectedDay.value);
    loadGroceryList();
  }

  // --- Grocery List Logic ---

  Future<void> loadGroceryList() async {
    final List<Map<String, dynamic>> items = await _dbService.getAllGroceryItems();

    groceryList.assignAll(items.map((map) => GroceryItem.fromMap(map)).toList());
  }

  // "Add/Remove" Toggle
  Future<void> toggleGroceryItem(GroceryItem item) async {
    if (groceryList.any((i) => i.name == item.name)) {
      // Remove from list and DB
      groceryList.removeWhere((i) => i.name == item.name);
      await _dbService.removeGroceryItem(item.name);
    } else {
      // Add to list and DB
      groceryList.add(item);
      await _dbService.upsertGroceryItem(item.name, item.price, item.category);
    }
  }

  // Update Price ("Live Editor")
  Future<void> updateGroceryPrice(GroceryItem item, double newPrice) async {
    item.price = newPrice;
    // Pass the category here so the DB doesn't lose it or throw an error!
    await _dbService.upsertGroceryItem(item.name, newPrice, item.category);
    groceryList.refresh();
  }

  Future<void> editGroceryItem({
    required String oldName,
    required String newName,
    required double newPrice,
    required String newCategory,
  }) async {
    // Remove old entry if the name changed
    if (oldName != newName) {
      await _dbService.removeGroceryItem(oldName);
    }

    // Update/Insert new entry
    await _dbService.upsertGroceryItem(newName, newPrice, newCategory);

    // Refresh list
    await loadGroceryList();
  }

  Map<String, double> get categoryTotals {
    Map<String, double> totals = {};
    for (var item in groceryList) {
      String cat = item.category;
      totals[cat] = (totals[cat] ?? 0) + item.price;
    }
    return totals;
  }

  // --- Database Methods (MEAL) ---
  Future<void> fetchMealsForDate(DateTime date) async {
    try {
      isLoading.value = true;
      String formattedDate = date.toIso8601String().split('T')[0];
      List<Meal> meals = await _dbService.getMealsByDate(formattedDate);

      final typeOrder = {'Breakfast': 0, 'Lunch': 1, 'Dinner': 2};
      meals.sort(
        (a, b) => (typeOrder[a.type] ?? 99).compareTo(typeOrder[b.type] ?? 99),
      );

      plannedMeals.assignAll(meals);
    } catch (e) {
      Get.snackbar("Error", "Could not load plan");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addMeal(Meal meal) async {
    await _dbService.insertMeal(meal);
    await fetchMealsForDate(selectedDay.value);
    Get.snackbar("Success", "${meal.title} added!");
  }

  Future<void> deleteMeal(int id) async {
    await _dbService.deleteMeal(id);
    await fetchMealsForDate(selectedDay.value);
    Get.snackbar("Deleted", "Meal removed");
  }

  Future<void> updateMeal(Meal meal) async {
    try {
      // 1. UPDATE LOCAL DB
      await _dbService.updateMeal(meal);

      // 2. REFRESH LOCAL UI
      await fetchMealsForDate(selectedDay.value);

      // 3. SMART CLOUD SYNC
      // Check if the meal is already in the cloud
      bool isSynced = await _supabaseService.isMealSavedInCloud(meal.id.toString());

      if (isSynced) {
        // We call the cloud save again.
        // Ensure your 'saveMealToCloud' inside SupabaseService uses .upsert()
        await _supabaseService.saveMealToCloud(
          recipeId: meal.id.toString(),
          title: meal.title,
          kcal: meal.kcal.toString(),
          imageUrl: meal.imageUrl,
          ingredients: meal.ingredients,
          steps: meal.steps,
        );
        debugPrint("Cloud Sync: Updated ${meal.title} successfully.");
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  // --- AI & Integration ---
  void addFromPost(PostModel post, String mealType) {
    final meal = Meal(
      id: null,
      title: post.title,
      type: mealType,
      kcal: 500,
      imageUrl: post.imageUrl ?? "https://loremflickr.com/800/600/food,recipe",
      ingredients: "Unstructured Content",
      steps: post.content,
      date: selectedDay.value.toIso8601String().split('T')[0],
      isSocialPost: true,
    );

    addMeal(meal);
  }

  Future<void> resolveRecipe(Meal meal) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyCeHUyp3gMl9cBndMQvYWrIxlZGHLrCcHg',
      );

      final prompt =
          """
      Convert this community post into a clean JSON recipe.
      Title: ${meal.title}
      Content: ${meal.steps}

      Return ONLY JSON. Use this format:
      {"kcal": 500, "ingredients": "Item 1\\nItem 2", "steps": "Step 1\\nStep 2"}
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      String text = response.text ?? "";

      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');

      if (start != -1 && end != -1) {
        final jsonString = text.substring(start, end + 1);
        final Map<String, dynamic> data = jsonDecode(jsonString);

        // --- THE GLOBAL SAVE ---
        await _dbService.updateAllMealsWithTitle(
          title: meal.title,
          ingredients: data['ingredients'] ?? "",
          steps: data['steps'] ?? "",
          kcal: data['kcal'] is int ? data['kcal'] : 500,
        );

        await fetchMealsForDate(selectedDay.value);

        Get.snackbar(
          "Success!",
          "All instances of '${meal.title}' have been organized.",
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      Get.snackbar("Error", "Could not save the AI version.");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> generateSmartPlan({
    required DateTime start,
    required DateTime end,
    required List<String> mealTypes,
    String? craving,
  }) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: 'AIzaSyCeHUyp3gMl9cBndMQvYWrIxlZGHLrCcHg',
      );

      int daysCount = end.difference(start).inDays + 1;
      List<String> rangeDates = List.generate(
        daysCount,
        (i) => start.add(Duration(days: i)).toIso8601String().split('T')[0],
      );

      String requestedTypes = mealTypes.join(', ');

      final prompt = """
      Generate a healthy meal plan for these dates: ${rangeDates.join(', ')}.
      ONLY generate these meal types: $requestedTypes. 
      If the user only asks for Breakfast, return ONLY Breakfast objects.
      
      User Preference: ${craving ?? 'Healthy and balanced'}.
      
      Return ONLY a JSON array. 
      For "image_query", provide 1-2 words of the MAIN VISUAL element (e.g., 'Omelette', 'Pancakes').
      
      Format: [{"date": "YYYY-MM-DD", "type": "$requestedTypes", "title": "...", "image_query": "...", "kcal": 500, "ingredients": "...", "steps": "..."}]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      String? text = response.text;

      if (text != null) {
        final jsonStart = text.indexOf('[');
        final jsonEnd = text.lastIndexOf(']');
        final cleanJson = text.substring(jsonStart, jsonEnd + 1);
        final List<dynamic> dataList = jsonDecode(cleanJson);

        for (int i = 0; i < dataList.length; i++) {
          final item = dataList[i];
          String imageUrl = await fetchMealImage(
            item['image_query'] ?? item['title'],
            i,
          );

          final meal = Meal(
            title: item['title'] ?? "Healthy Food",
            type: item['type'] ?? "Lunch",
            kcal: (item['kcal'] is int)
                ? item['kcal']
                : (int.tryParse(item['kcal'].toString()) ?? 500),
            imageUrl: imageUrl,
            ingredients: item['ingredients'] ?? "",
            steps: item['steps'] ?? "",
            date: item['date'],
            isSocialPost: false,
          );
          await _dbService.insertMeal(meal);
        }

        fetchMealsForDate(selectedDay.value);
        Get.back();
        Get.snackbar("Plan Ready", "Generated $daysCount days of meals.");
      }
    } catch (e) {
      debugPrint("Gemini Error: $e");
      Get.snackbar("Error", "AI generation failed.");
    } finally {
      isLoading.value = false;
    }
  }

  Future<String> fetchMealImage(String query, int index) async {
    final String cleanQuery = Uri.encodeComponent(query);

    final mealDbUrl = "https://www.themealdb.com/api/json/v1/1/search.php?s=$cleanQuery";

    try {
      final response = await http.get(Uri.parse(mealDbUrl)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['meals'] != null && data['meals'].isNotEmpty) {
          return data['meals'][0]['strMealThumb']; // Real recipe photo
        }
      }
    } catch (e) {
      debugPrint("MealDB failed: $e");
    }

    return "https://images.pexels.com/photos/search/$cleanQuery/?orientation=landscape";
  }

  // Handles both search and category filtering
  List<Meal> get filteredMeals {
    return plannedMeals.where((meal) {
      bool matchesSearch = meal.title.toLowerCase().contains(
        searchQuery.value.toLowerCase(),
      );
      bool matchesCategory =
          selectedCategory.value == "All" ||
          meal.type == selectedCategory.value;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // --- Helpers ---
  int get totalKcal => plannedMeals.fold(0, (sum, item) => sum + item.kcal);

  void updateSelectedDay(DateTime selected, DateTime focused) {
    selectedDay.value = selected;
    focusedDay.value = focused;
    fetchMealsForDate(selected);
  }

  Future<void> initCloudStatus(String recipeId) async {
    isCloudSaved.value = false;

    isCloudSaved.value = await _supabaseService.isMealSavedInCloud(recipeId);
  }

  Future<void> saveMealToCloud(Meal meal) async {
    try {
      isLoading.value = true;

      await _supabaseService.saveMealToCloud(
        recipeId: meal.id.toString(),
        title: meal.title,
        kcal: meal.kcal.toString(),
        imageUrl: meal.imageUrl,
        ingredients: meal.ingredients,
        steps: meal.steps,
      );

      Get.snackbar("Success", "Meal saved to your Cloud Planner!");
    } catch (e) {
      Get.snackbar("Error", "Could not save to cloud: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // --- SAVE MEAL ---
  // Handle the Save Meal object (for the Detail Screen)
  Future<void> toggleCloudSave(Meal meal) async {
    try {
      final isAlreadySaved = await _supabaseService.isMealSavedInCloud(meal.id.toString());

      if (isAlreadySaved) {
        await _supabaseService.removeMealFromCloud(meal.id.toString());
        isCloudSaved.value = false;
        Get.snackbar("Removed", "Removed from Cloud Planner");
      } else {
        await _supabaseService.saveMealToCloud(
          recipeId: meal.id.toString(),
          title: meal.title,
          kcal: meal.kcal.toString(),
          imageUrl: meal.imageUrl,
          ingredients: meal.ingredients,
          steps: meal.steps,
        );
        isCloudSaved.value = true;
        Get.snackbar("Saved", "Saved to Cloud Planner");
      }
    } catch (e) {
      Get.snackbar("Error", "Could not update cloud: $e");
    }
  }

// Handle the String recipeId (for the Saved Meals Sheet)
  Future<void> removeByRecipeId(String recipeId) async {
    await _supabaseService.removeMealFromCloud(recipeId);
    fetchSavedMeals();
    Get.snackbar("Removed", "Meal removed from Cloud Planner");
  }

  Future<void> fetchSavedMeals() async {
    final data = await _supabaseService.fetchSavedMeals();
    cloudSavedMeals.assignAll(data);
  }

  Future<void> addMealFromCloud(Map<String, dynamic> mealData, String type) async {
    final meal = Meal(
      title: mealData['title'],
      type: type,
      kcal: int.tryParse(mealData['kcal'].toString()) ?? 0,
      imageUrl: mealData['image_url'],
      ingredients: mealData['ingredients'],
      steps: mealData['steps'],
      date: DateFormat('yyyy-MM-dd').format(selectedDay.value),
    );

    await addMeal(meal);
    Get.snackbar("Added", "${meal.title} added to your plan!");
  }
}
