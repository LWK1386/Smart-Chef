class Recipe {
  final String title;
  final String image;
  final String instructions;
  final List<String> ingredients;
  final List<String> steps;
  final String kcal;
  final String duration;

  Recipe({
    required this.title,
    required this.image,
    required this.instructions,
    required this.ingredients,
    required this.steps,
    required this.kcal,
    required this.duration,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    //Parse ingredients
    List<String> ingredientsList = (json['extendedIngredients'] as List<dynamic>?)
        ?.map((e) => e['original'].toString())
        .toList() ?? [];

    //Parse steps
    List<String> stepsList = [];
    if (json['analyzedInstructions'] != null && (json['analyzedInstructions'] as List).isNotEmpty) {
      final instructionList = json['analyzedInstructions'][0]['steps'] as List;
      stepsList = instructionList.map((e) => e['step'].toString()).toList();
    }

    //Extract Calories (Kcal) from Nutrition list
    String foundKcal = "---";
    final nutrients = json['nutrition']?['nutrients'];
    if (nutrients != null) {
      final calorieData = nutrients.firstWhere(
            (n) => n['name'] == 'Calories',
        orElse: () => null,
      );

      if (calorieData != null && calorieData['amount'] != null) {
        foundKcal = "${(calorieData['amount'] as num).round()} kcal";
      }
    }

    return Recipe(
      title: json['title'] ?? 'Sustainable Dish',
      image: json['image'] ?? '',
      instructions: json['instructions'] ?? 'No instructions available.',
      ingredients: ingredientsList,
      steps: stepsList,
      kcal: foundKcal,
      duration: "${json['readyInMinutes'] ?? '--'} mins",
    );
  }
}