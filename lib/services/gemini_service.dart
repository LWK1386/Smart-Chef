import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String apiKey = "hidden";
  static const String pixabayApiKey = "hidden";

  static const String _nutritionApiKey = 'hidden';

  //Detect ingredients from image
  static Future<List<String>> detectIngredients(File image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": """
Identify all visible food ingredients in this image.

Rules:
- Only return ingredient names
- Use lowercase
- Comma separated
- No sentences

Example:
tomato, egg, onion
"""
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Gemini request failed: ${response.body}");
    }

    final data = jsonDecode(response.body);

    if (data["candidates"] == null || data["candidates"].isEmpty) {
      return [];
    }

    final parts = data["candidates"][0]["content"]["parts"];

    if (parts == null || parts.isEmpty) {
      return [];
    }

    final text = parts[0]["text"] ?? "";

    print("Gemini response: $text");

    List<String> ingredients = [];

    for (String item in text.toLowerCase().split(",")) {
      final cleaned = item.trim();
      if (cleaned.isNotEmpty) {
        ingredients.add(cleaned);
      }
    }

    return ingredients;
  }

  //AI Fix Ingredients
  static Future<List<String>> fixIngredients(List<String> ingredients) async {
    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
    );

    final prompt = """
You are a food ingredient validator.

Fix and clean this ingredient list:
${ingredients.join(", ")}

Rules:
- Correct spelling mistakes
- Convert plural to singular
- Remove anything that is NOT edible food
- Remove objects, animals, furniture, tools, etc
- Keep only real cooking ingredients

Return ONLY a comma separated list in lowercase.
""";

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      return ingredients;
    }

    final data = jsonDecode(response.body);
    final text = data["candidates"][0]["content"]["parts"][0]["text"] ?? "";

    List<String> cleaned = [];

    for (String item in text.toLowerCase().split(",")) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        cleaned.add(trimmed);
      }
    }

    // If returns empty list,still have something to work with.
    if (cleaned.isEmpty) {
      return ["egg", "rice"]; // fallback ingredients
    }

    return cleaned;
  }

  // Generate Recipes
  static Future<List<Map<String, String>>> generateRecipes(List<String> ingredients, {int targetCount = 6}) async {
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    //kcal and duration
    final prompt = """
        You are a creative AI chef. Using: ${ingredients.join(", ")}, invent $targetCount unique recipes. 
        For each recipe, provide:
        - title: Name of recipe
        - kcal: Estimated calories (e.g. "320 kcal")
        - duration: Total time (e.g. "25 mins")
        - ingredients: Bullet points (e.g. "- ingredient 1\\n- ingredient 2")
        - steps: Numbered list (e.g. "1. Step one.\\n2. Step two.")
        
        Return strictly in this JSON format:
        {
          "recipes": [
            {
              "title": "Recipe Name",
              "kcal": "400 kcal",
              "duration": "30 mins",
              "ingredients": "- item 1\\n- item 2",
              "steps": "1. Step 1\\n2. Step 2"
            }
          ]
        }
        """;

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}),
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final text = data["candidates"][0]["content"]["parts"][0]["text"] ?? "";

    try {
      final cleanedText = text.replaceAll(RegExp(r'```(json)?'), '').trim();
      final parsed = jsonDecode(cleanedText) as Map<String, dynamic>;
      final List<dynamic> recipesList = parsed["recipes"] ?? [];

      List<Map<String, String>> recipes = [];

      for (var recipe in recipesList) {
        if (recipes.length >= targetCount) break;

        final title = recipe["title"] ?? "";
        final imageUrl = await fetchRecipeImagePixabay(title);

        if (imageUrl.isNotEmpty) {
          recipes.add({
            "title": title,
            "kcal": recipe["kcal"] ?? "---",
            "duration": recipe["duration"] ?? "---",
            "ingredients": recipe["ingredients"] ?? "",
            "steps": recipe["steps"] ?? "",
            "image": imageUrl,
          });
        }
      }

      //Recursive call if not enough recipes with images
      if (recipes.length < targetCount) {
        final more = await generateRecipes(ingredients, targetCount: targetCount - recipes.length);
        recipes.addAll(more);
      }

      return recipes;
    } catch (e) {
      print("Failed to parse: $e");
      return [];
    }
  }

  //Fetch Image
  static Future<String> fetchRecipeImagePixabay(String query) async {
    try {
      final url = Uri.parse(
        "https://pixabay.com/api/?key=$pixabayApiKey&q=${Uri.encodeComponent(query)}&image_type=photo&per_page=3",
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hits = data["hits"] as List<dynamic>?;

        if (hits != null && hits.isNotEmpty) {
          final image = hits[0]["previewURL"] ?? "";

          // ensure CDN format
          if (image.contains("cdn.pixabay.com")) {
            return image;
          }

          return "";
        }
      }

      return "";
    } catch (e) {
      return "";
    }
  }

  static Future<Map<String, dynamic>?> analyzeFoodImage(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_nutritionApiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                },
                {
                  'text': '''You are a nutrition expert. Look at this food image carefully.
                    1. First check if this image actually contains food
                    2. If NO food is visible or image is unclear, return this exact JSON:
                       {"error": "not_food"} or {"error": "unclear"}
                    3. If food IS visible:
                       - Identify the exact food name and brand if visible
                       - Search for accurate nutrition information online
                       - Estimate the portion size in grams based on what you see
                    Respond ONLY in valid JSON with exactly these keys for food:
                    {
                      "food_name": "",
                      "estimated_grams": 0,
                      "calories_per_serving": 0,
                      "protein_per_serving": 0,
                      "carbs_per_serving": 0,
                      "fat_per_serving": 0
                    }
                    Or for errors:
                    {"error": "not_food"} or {"error": "unclear"}
                    No extra text, no markdown, just the JSON.'''
                }
              ]
            }
          ],
          'tools': [
            {'google_search': {}}
          ],
        }),
      );

      print('=== GEMINI STATUS: ${response.statusCode} ===');
      print('=== GEMINI BODY: ${response.body} ===');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'] as String;

        print('=== GEMINI TEXT: $text ===');

        final jsonMatch = RegExp(r'\{[\s\S]*?\}').firstMatch(text);
        if (jsonMatch == null) {
          print('=== NO JSON FOUND ===');
          return null;
        }

        final clean = jsonMatch.group(0)!;
        print('=== EXTRACTED JSON: $clean ===');

        return Map<String, dynamic>.from(jsonDecode(clean));
      } else {
        print('=== GEMINI HTTP ERROR: ${response.body} ===');
        return null;
      }
    } catch (e) {
      print('=== GEMINI ERROR: $e ===');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> searchFoodNutrition(String foodName) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_nutritionApiKey',
      );

      final prompt = '''
You are a nutrition database. For the food "$foodName", provide accurate nutrition data per 100g.

Respond ONLY with a valid JSON object in this exact format:
{
  "food_name": "exact food name",
  "calories_per_100g": number,
  "protein_per_100g": number,
  "carbs_per_100g": number,
  "fat_per_100g": number,
  "serving_size_g": number
}

Rules:
- calories_per_100g must equal (protein_per_100g × 4) + (carbs_per_100g × 4) + (fat_per_100g × 9)
- serving_size_g is the typical single serving in grams (e.g. 300 for nasi lemak, 100 for bread)
- If the food doesn't exist or is not a food, respond with: {"error": "not_food"}
- No markdown, no explanation, JSON only
''';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gemini-2.5-flash',
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'tools': [
          ],
        }),
      );

      print('=== GEMINI SEARCH STATUS: ${response.statusCode} ===');

      if (response.statusCode == 429) {
        return {'error': 'rate_limit'};
      }
      if (response.statusCode == 400) {
        return {'error': 'quota_exceeded'};
      }
      if (response.statusCode != 200) {
        return {'error': 'api_error', 'code': response.statusCode};
      }

      final body = jsonDecode(response.body);
      final text = (body['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?) ?? '';

      print('=== GEMINI SEARCH TEXT: $text ===');

      // Extract JSON from response
      final match = RegExp(r'\{[\s\S]*?\}').firstMatch(text);
      if (match == null) return null;

      final result = jsonDecode(match.group(0)!);
      if (result['error'] != null) return null;

      print('=== GEMINI SEARCH RESULT: $result ===');
      return result;
    } catch (e) {
      print('=== GEMINI SEARCH ERROR: $e ===');
      return null;
    }
  }
}
