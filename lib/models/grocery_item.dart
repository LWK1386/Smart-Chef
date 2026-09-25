class GroceryItem {
  final String id;
  final String name;
  double price;
  String category;

  GroceryItem({
    required this.id,
    required this.name,
    this.price = 0.0,
    this.category = "General" // Default category
  });

  factory GroceryItem.fromMap(Map<String, dynamic> map) {
    return GroceryItem(
      id: map['name'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      category: map['category'] ?? "General",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
    };
  }
}