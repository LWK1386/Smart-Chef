import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/grocery_item.dart';
import '../../models/meal_model.dart';
import '../../controllers/planner_controller.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MealDetailScreen extends StatelessWidget {
  final Meal meal;
  const MealDetailScreen({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlannerController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.initCloudStatus(meal.id.toString());
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        // Sync with controller to show live updates if meal is edited
        final currentMeal = controller.plannedMeals.firstWhere(
          (m) => m.id == meal.id,
          orElse: () => meal,
        );

        // Convert raw strings into clean lists for the UI
        List<String> ingredientList = currentMeal.ingredients.contains('\n')
            ? currentMeal.ingredients.split('\n')
            : currentMeal.ingredients.split(',');

        List<String> stepList = currentMeal.steps.split('\n');

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: const Color(0xFF00A676),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit
                      .expand,
                  children: [
                    // 1. IMAGE AREA
                    Obx(
                      () => _buildHeaderImage(
                        controller.plannedMeals
                            .firstWhere((m) => m.id == meal.id)
                            .imageUrl,
                      ),
                    ),

                    Container(
                      decoration: const BoxDecoration(color: Colors.black26),
                    ),

                    // 2. EDIT BUTTON
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        heroTag: "edit_btn_${currentMeal.id}",
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF00A676),
                        ),
                        onPressed: () => _showEditMealSheet(
                          context,
                          controller,
                          currentMeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // --- SAVE BUTTON
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 15,
                            bottom: 5,
                            right: 10,
                          ),
                          child: Obx(
                            () => FloatingActionButton.small(
                              heroTag: "cloud_btn_${currentMeal.id}",
                              backgroundColor: Colors.white,
                              elevation: 2,
                              child: Icon(
                                controller.isCloudSaved.value
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: controller.isCloudSaved.value
                                    ? Colors.blue
                                    : Colors.blueAccent,
                              ),
                              onPressed: () =>
                                  controller.toggleCloudSave(currentMeal),
                            ),
                          ),
                        ),
                        //--- Grocery list button
                        Padding(
                          padding: const EdgeInsets.only(top: 15, bottom: 5),
                          child: FloatingActionButton.small(
                            heroTag: "grocery_btn_${currentMeal.id}",
                            backgroundColor: Colors.white,
                            elevation: 2,
                            child: const Icon(
                              Icons.add_shopping_cart_outlined,
                              color: Color(0xFF00A676),
                            ),
                            onPressed: () => showGroceryBottomSheet(
                              context,
                              controller,
                              ingredientList,
                            ),
                          ),
                        ),
                      ],
                    ),

                    Text(
                      currentMeal.type.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF00A676),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentMeal.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${currentMeal.kcal} Calories",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),

                    if (currentMeal.isSocialPost)
                      _buildResolveBanner(context, currentMeal, controller),

                    const Divider(height: 40),

                    if (currentMeal.isSocialPost) ...[
                      const Text(
                        "Community Story",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentMeal.steps,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ] else ...[
                      const Text(
                        "Ingredients",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._buildIngredientItems(ingredientList),
                      const SizedBox(height: 30),
                      const Text(
                        "Cooking Steps",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._buildStepItems(stepList),
                    ],
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // --- IMAGE UI HELPER
  Widget _buildFullPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00A676).withValues(alpha: 0.2),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 50,
            color: const Color(0xFF00A676).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            "NO PHOTO FOUND",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00A676).withValues(alpha: 0.5),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImage(String imageUrl) {
    // 1. If empty or null, show placeholder immediately
    if (imageUrl.isEmpty) {
      return _buildFullPlaceholder();
    }

    // 2. Handle Network Images
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildFullPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFullPlaceholder(); // Shows placeholder while loading
        },
      );
    }

    // 3. Handle Local Files
    File localFile = File(imageUrl);
    if (localFile.existsSync()) {
      return Image.file(localFile, fit: BoxFit.cover, width: double.infinity);
    }

    // 4. Fallback if file path is invalid
    return _buildFullPlaceholder();
  }

  // --- SHEET  ---
  void _showEditMealSheet(
      BuildContext context,
      PlannerController controller,
      Meal meal,
      )
  {
    final titleController = TextEditingController(text: meal.title);
    final kcalController = TextEditingController(text: meal.kcal.toString());
    final ingredientsController = TextEditingController(text: meal.ingredients);
    final stepsController = TextEditingController(text: meal.steps);
    final urlController = TextEditingController(
      text: meal.imageUrl.startsWith('http') ? meal.imageUrl : '',
    );

    var selectedType = meal.type.obs;
    var currentImageUrl = meal.imageUrl.obs;

    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- HEADER
              Stack(
                children: [
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Edit Meal",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Get.back(),
                    ),
                  ),
                ],
              ),

              // --- LIVE PREVIEW
              Obx(
                    () => Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    image: currentImageUrl.value.isNotEmpty
                        ? DecorationImage(
                      image: currentImageUrl.value.startsWith('http')
                          ? NetworkImage(currentImageUrl.value)
                          : FileImage(File(currentImageUrl.value))
                      as ImageProvider,
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                ),
              ),

              // --- TYPE SELECTOR
              Obx(
                    () => Wrap(
                  spacing: 10,
                  children: ['Breakfast', 'Lunch', 'Dinner']
                      .map(
                        (type) => ChoiceChip(
                      label: Text(type),
                      selected: selectedType.value == type,
                      selectedColor: Color(0xFF00A676),
                      labelStyle: TextStyle(
                        color: selectedType.value == type
                            ? Colors.white
                            : Colors.black,
                      ),
                      onSelected: (_) => selectedType.value = type,
                    ),
                  )
                      .toList(),
                ),
              ),

              // --- ALL INPUT FIELDS
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: kcalController,
                decoration: const InputDecoration(labelText: "Calories"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: ingredientsController,
                decoration: const InputDecoration(labelText: "Ingredients"),
                maxLines: 2,
              ),
              TextField(
                controller: stepsController,
                decoration: const InputDecoration(labelText: "Steps"),
                maxLines: 3,
              ),

              const SizedBox(height: 15),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: "Paste Image URL",
                  prefixIcon: Icon(Icons.link),
                ),
                onChanged: (val) => currentImageUrl.value = val,
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00A676).withValues(alpha: 0.1),
                  foregroundColor: Color(0xFF00A676),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    currentImageUrl.value = picked.path;
                    urlController.text = "";
                  }
                },
                icon: const Icon(Icons.photo_library),
                label: const Text("Pick from Gallery"),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00A676),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  await controller.updateMeal(
                    meal.copyWith(
                      title: titleController.text,
                      type: selectedType.value,
                      kcal: int.tryParse(kcalController.text) ?? meal.kcal,
                      ingredients: ingredientsController.text,
                      steps: stepsController.text,
                      imageUrl: currentImageUrl.value,
                    ),
                  );
                  Get.back();
                },
                child: const Text(
                  "Save Changes",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showGroceryBottomSheet(
    BuildContext context,
    PlannerController controller,
    List<String> ingredients,
  )
  {
    // 1. Persistent State Maps
    final Map<String, TextEditingController> textControllers = {
      for (var i in ingredients) i: TextEditingController(text: i),
    };
    final Map<String, RxBool> isSelected = {
      for (var i in ingredients) i: true.obs,
    };
    final Map<String, RxString> categorySelections = {
      for (var i in ingredients) i: "General".obs,
    };

    final List<String> categories = [
      "General",
      "Produce",
      "Dairy",
      "Protein",
      "Bakery",
      "Other",
    ];

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const Text(
              "Add to Grocery List",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: ingredients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 15),
                itemBuilder: (context, index) {
                  final item = ingredients[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Checkbox + Editable Text
                        Obx(
                          () => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFF00A676),
                            value: isSelected[item]!.value,
                            onChanged: (val) => isSelected[item]!.value = val!,
                            title: TextField(
                              controller: textControllers[item],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        // Category Selection
                        Obx(
                          () => DropdownButtonFormField<String>(
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: "Category",
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            initialValue: categorySelections[item]!.value,
                            items: categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                categorySelections[item]!.value = val!,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A676),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  for (var item in ingredients) {
                    if (isSelected[item]!.value) {
                      controller.toggleGroceryItem(
                        GroceryItem(
                          id: textControllers[item]!
                              .text, // Use the MODIFIED text
                          name: textControllers[item]!.text,
                          category: categorySelections[item]!.value,
                        ),
                      );
                    }
                  }
                  Get.back();
                },
                child: const Text(
                  "CONFIRM & ADD",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // --- HELPER  ---
  // --- Change Community Story To Receipt Banner
  Widget _buildResolveBanner(
    BuildContext context,
    Meal meal,
    PlannerController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Want to organize this into a recipe?",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: controller.isLoading.value
                  ? null
                  : () => controller.resolveRecipe(meal),
              child: controller.isLoading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("AUTO-ORGANIZE"),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIngredientItems(List<String> list) {
    return list
        .where((i) => i.trim().isNotEmpty)
        .map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00A676),
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.trim(),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildStepItems(List<String> list) {
    return list
        .where((s) => s.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFF00A676),
                  child: Text(
                    "${entry.key + 1}",
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    entry.value.trim(),
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }


}
