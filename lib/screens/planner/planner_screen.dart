import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../controllers/planner_controller.dart';
import '../../controllers/post_controller.dart';
import '../../models/meal_model.dart';
import 'grocery_list_screen.dart';
import 'meal_detail_screen.dart';
import 'dart:io';

class SmartPlannerScreen extends GetView<PlannerController> {
  const SmartPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlannerController());
    final PostController postController = Get.find<PostController>();

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: const Color(0xFF00A676),
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        spacing: 12,
        children: [
          SpeedDialChild(
            child: const Icon(
              Icons.shopping_cart,
              color: Colors.white,
            ),
            backgroundColor: const Color(0xFF00A676),
            label: 'View Grocery List',
            onTap: () => Get.to(() => GroceryListScreen()),
          ),
          SpeedDialChild(
            child: const Icon(Icons.auto_awesome, color: Colors.white),
            backgroundColor: const Color(0xFF00A676),
            label: 'Smart AI Generation',
            onTap: () => _showSmartSetupSheet(context, controller),
          ),
          SpeedDialChild(
            child: const Icon(Icons.local_fire_department, color: Colors.white),
            backgroundColor: Color(0xFF00A676),
            label: 'Community Favorites',
            onTap: () =>
                _showAddOptionSheet(context, controller, postController),
          ),
          SpeedDialChild(
            child: const Icon(Icons.bookmark, color: Colors.white),
            backgroundColor: const Color(0xFF00A676),
            label: 'My Saved Meals',
            onTap: () {
              controller.fetchSavedMeals();
              _showSavedMealSheet(context, controller);
            },
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 50),
          _buildHeader(controller),
          _buildCalendar(controller),
          _buildDailySummary(controller),

          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.plannedMeals.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00A676)),
                );
              }
              if (controller.plannedMeals.isEmpty) {
                return const Center(
                  child: Text(
                    "No meals planned for today",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                itemCount: controller.plannedMeals.length,
                itemBuilder: (context, index) {
                  return _buildMealCard(
                    controller.plannedMeals[index],
                    controller,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- PLANNER UI HELPER METHODS ---
  Widget _buildHeader(PlannerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 30),
            onPressed: () => controller.updateSelectedDay(
              controller.selectedDay.value.subtract(const Duration(days: 7)),
              controller.focusedDay.value.subtract(const Duration(days: 7)),
            ),
          ),
          Obx(
            () => Text(
              DateFormat('MMMM yyyy').format(controller.focusedDay.value),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 30),
            onPressed: () => controller.updateSelectedDay(
              controller.selectedDay.value.add(const Duration(days: 7)),
              controller.focusedDay.value.add(const Duration(days: 7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(PlannerController controller) {
    return Obx(
      () => TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: controller.focusedDay.value,
        headerVisible: false,
        calendarFormat: CalendarFormat.week,
        selectedDayPredicate: (day) =>
            isSameDay(controller.selectedDay.value, day),
        onDaySelected: controller.updateSelectedDay,
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: Color(0xFF00A676),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Color(0x8000A676),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummary(PlannerController controller) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.orange, size: 20),
            const SizedBox(width: 5),
            Text(
              "Total for today: ${controller.totalKcal} kcal",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ADD OPTION SHEET
  // --- COMMUNITY FAVORITE ---
  void _showAddOptionSheet(BuildContext context, PlannerController controller, PostController postController) {
    controller.searchQuery.value = "";

    Get.bottomSheet(
      isScrollControlled: true,
      ignoreSafeArea: false,
      DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // --- DRAG HANDLE ---
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              "Community Favorites",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- SEARCH BAR ---
                          TextField(
                            onChanged: (value) => controller.searchQuery.value = value,
                            decoration: InputDecoration(
                              hintText: "Search recipes...",
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF00A676)),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- CONTENT SECTION ---
                          Obx(() {
                            // 1. Handle actual Offline/Empty State
                            if (postController.posts.isEmpty) {
                              return _buildOfflineState(context, postController);
                            }

                            // 2. Handle Search Filtering
                            final filteredPosts = postController.posts
                                .where((post) => post.title.toLowerCase().contains(
                              controller.searchQuery.value.toLowerCase(),
                            ))
                                .toList();

                            if (filteredPosts.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40.0),
                                  child: Text("No recipes match your search"),
                                ),
                              );
                            }

                            // 3. Regular List View
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredPosts.length,
                              itemBuilder: (context, index) {
                                final post = filteredPosts[index];
                                var selectedType = "Lunch".obs;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          post.imageUrl ?? "",
                                          width: 60, height: 60, fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 60, height: 60, color: Colors.grey[200],
                                            child: const Icon(Icons.restaurant, size: 20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Obx(() => DropdownButton<String>(
                                              value: selectedType.value,
                                              isDense: true,
                                              underline: const SizedBox(),
                                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00A676)),
                                              items: ['Breakfast', 'Lunch', 'Dinner'].map((t) =>
                                                  DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))
                                              ).toList(),
                                              onChanged: (val) => selectedType.value = val!,
                                            )),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle, color: Color(0xFF00A676), size: 32),
                                        onPressed: () {
                                          controller.addFromPost(post, selectedType.value);
                                          Get.back();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- OFFLINE STATE WIDGET ---
  Widget _buildOfflineState(BuildContext context, PostController postController) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "Offline Mode",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't load community recipes.\nPlease check your connection.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => postController.fetchPosts(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("RETRY"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A676),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MY SAVED MEAL ---
  void _showSavedMealSheet(BuildContext context, PlannerController controller) {
    controller.fetchSavedMeals();

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const Text(
              "My Saved Meals",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Obx(
                () => ListView.builder(
                  itemCount: controller.cloudSavedMeals.length,
                  itemBuilder: (context, index) {
                    final meal = controller.cloudSavedMeals[index];
                    var selectedType = "Lunch".obs;

                    return Card(
                      color: Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            // 1. IMAGE
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Builder(
                                builder: (context) {
                                  final String imagePath = meal['image_url'] ?? "";

                                  // Check if it's a web URL
                                  if (imagePath.startsWith('http')) {
                                    return Image.network(
                                      imagePath,
                                      key: ValueKey(imagePath),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                    );
                                  }
                                  // Check if it's a local Gallery path (not empty and not http)
                                  else if (imagePath.isNotEmpty) {
                                    return Image.file(
                                      File(imagePath),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported),
                                    );
                                  }
                                  // Fallback for no image
                                  else {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.restaurant, color: Colors.grey),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 2. TITLE AND DROPDOWN
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meal['title'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Obx(() => DropdownButton<String>(
                                    isDense: true,
                                    value: selectedType.value,
                                    items: ['Breakfast', 'Lunch', 'Dinner'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                    onChanged: (val) => selectedType.value = val!,
                                  )),
                                ],
                              ),
                            ),

                            // 3. ACTION BUTTONS
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFF00A676), size: 30),
                              onPressed: () {
                                controller.addMealFromCloud(meal, selectedType.value);
                                Get.back();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.bookmark_remove, color: Colors.redAccent),
                              onPressed: () async {
                                // Do not cast as 'Meal'. Pass the ID string.
                                await controller.removeByRecipeId(meal['recipe_id'].toString());
                                controller.fetchSavedMeals();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- AI GENERATE MEAL SHEET ---
  void _showSmartSetupSheet(
    BuildContext context,
    PlannerController controller,
  )
  {
    var rangeStart = controller.selectedDay.value.obs;
    var rangeEnd = controller.selectedDay.value.obs;
    var selectedTypes = <String>['Breakfast', 'Lunch', 'Dinner'].obs;
    final cravingController = TextEditingController();

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "✨ Smart Generation Setup",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Obx(
                () => TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 30)),
                  lastDay: DateTime.now().add(const Duration(days: 90)),
                  focusedDay: rangeStart.value,
                  rangeSelectionMode: RangeSelectionMode.toggledOn,
                  rangeStartDay: rangeStart.value,
                  rangeEndDay: rangeEnd.value,
                  onRangeSelected: (start, end, focused) {
                    if (start != null) rangeStart.value = start;
                    rangeEnd.value = end ?? start ?? DateTime.now();
                  },
                  calendarStyle: const CalendarStyle(
                    rangeStartDecoration: BoxDecoration(
                      color: Color(0xFF00A676),
                      shape: BoxShape.circle,
                    ),
                    rangeEndDecoration: BoxDecoration(
                      color: Color(0xFF00A676),
                      shape: BoxShape.circle,
                    ),
                    rangeHighlightColor: Color(0x3300A676),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Include Meals:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Obx(
                () => Wrap(
                  spacing: 10,
                  children: ['Breakfast', 'Lunch', 'Dinner'].map((type) {
                    bool isSelected = selectedTypes.contains(type);

                    return FilterChip(
                      label: Text(
                        type,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF00A676),
                        ),
                      ),
                      selected: isSelected,

                      checkmarkColor: Colors.white,

                      selectedColor: const Color(0xFF00A676),

                      backgroundColor: Colors.grey.shade200,

                      onSelected: (val) => val
                          ? selectedTypes.add(type)
                          : selectedTypes.remove(type),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: cravingController,
                decoration: InputDecoration(
                  hintText: "Cravings? (e.g., Spicy, Italian)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  prefixIcon: const Icon(
                    Icons.fastfood,
                    color: Color(0xFF00A676),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Obx(
                () => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A676),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: controller.isLoading.value
                      ? null
                      : () {
                          controller.generateSmartPlan(
                            start: rangeStart.value,
                            end: rangeEnd.value,
                            mealTypes: selectedTypes,
                            craving: cravingController.text,
                          );
                        },
                  child: controller.isLoading.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "GENERATE MY PLAN",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // --- MEAL CARD ---
  Widget _buildMealCard(Meal meal, PlannerController controller) {
    // Use Obx to make the card listen to updates in the controller
    return Obx(() {
      // Re-fetch the meal from the list so we have the absolute latest version
      final currentMeal = controller.plannedMeals.firstWhere(
        (m) => m.id == meal.id,
        orElse: () => meal,
      );

      return GestureDetector(
        onTap: () => Get.to(() => MealDetailScreen(meal: currentMeal)),
        onLongPress: () => _showDeleteDialog(currentMeal, controller),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Hero(
                  tag: 'meal-${currentMeal.id}',
                  // Use the helper you already have to handle File vs Network
                  child: _buildCardImage(currentMeal.imageUrl),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentMeal.type.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF00A676),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "${currentMeal.kcal} kcal",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMeal.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCardImage(String imageUrl) {
    bool isLocalFile =
        imageUrl.startsWith('/') ||
        imageUrl.startsWith('data/');

    if (isLocalFile && File(imageUrl).existsSync()) {
      return Image.file(
        File(imageUrl),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00A676).withValues(alpha: 0.1),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 45,
          color: Color(0xFF00A676),
        ),
      ),
    );
  }

  // --- DELETE MEAL ---
  void _showDeleteDialog(Meal meal, PlannerController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 50),
            const SizedBox(height: 15),
            const Text(
              "Delete Meal",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Are you sure you want to remove '${meal.title}' from your plan? This action cannot be undone.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      controller.deleteMeal(meal.id!);
                      Get.back();
                    },
                    child: const Text("Delete"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
