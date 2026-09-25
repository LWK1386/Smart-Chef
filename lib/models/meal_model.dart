class Meal {
  final int? id;
  final String title;
  final String type;
  final int kcal;
  final String imageUrl;
  final String ingredients;
  final String steps;
  final String date;
  final bool isSocialPost;

  Meal({
    this.id,
    required this.title,
    required this.type,
    required this.kcal,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.date,
    this.isSocialPost = false,
  });

  Meal copyWith({
    int? id,
    String? title,
    String? type,
    int? kcal,
    String? imageUrl,
    String? ingredients,
    String? steps,
    String? date,
    bool? isSocialPost,
  }) {
    return Meal(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      kcal: kcal ?? this.kcal,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      date: date ?? this.date,
      isSocialPost: isSocialPost ?? this.isSocialPost,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'kcal': kcal,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'steps': steps,
      'date': date,
      'isSocialPost': isSocialPost ? 1 : 0,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'],
      title: map['title'],
      type: map['type'],
      kcal: map['kcal'],
      imageUrl: map['imageUrl'],
      ingredients: map['ingredients'],
      steps: map['steps'],
      date: map['date'],
      isSocialPost: map['isSocialPost'] == 1,
    );
  }
}