import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/waste_recipe_model.dart';

class RecipeService {
  static const String apiKey = "fc36808696c7405e89a45aad686b2cdc";

  /// Fetch recipes by ingredient names
  static Future<List<Recipe>> fetchRecipesByIngredients(List<String> ingredients) async {
    if (ingredients.isEmpty) return [];

    final ingredientString = ingredients.join(",");
    final url = Uri.parse(
      "https://api.spoonacular.com/recipes/findByIngredients"
          "?ingredients=$ingredientString"
          "&number=6"
          "&ranking=1"
          "&ignorePantry=true"
          "&apiKey=$apiKey",
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Failed to load recipes: ${response.statusCode}");
    }

    final List<dynamic> data = jsonDecode(response.body);
    List<Recipe> recipes = [];

    for (var item in data) {
      if (item is! Map<String, dynamic>) continue;
      final recipeId = item['id'];
      if (recipeId == null) continue;

      final recipeDetailUrl = Uri.parse(
        "https://api.spoonacular.com/recipes/$recipeId/information"
            "?includeNutrition=true"
            "&apiKey=$apiKey",
      );

      final detailResponse = await http.get(recipeDetailUrl);
      if (detailResponse.statusCode != 200) continue;

      final detailData = jsonDecode(detailResponse.body);
      if (detailData is! Map<String, dynamic>) continue;

      recipes.add(Recipe.fromJson(detailData));
    }

    return recipes;
  }
}