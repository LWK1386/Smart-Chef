import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/grocery_item.dart';
import '../../controllers/planner_controller.dart';

class GroceryListScreen extends StatelessWidget {
  final PlannerController controller = Get.find();

  final Map<String, Color> categoryColors = {
    "General": Colors.grey.shade400,
    "Produce": const Color(0xFF00A676),
    "Dairy": Colors.blue.shade300,
    "Protein": Colors.red.shade300,
    "Bakery": Colors.orange.shade300,
    "Other": Colors.purple.shade300,
  };

  GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Grocery List", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- PIE CHART
          SizedBox(height: 200, child: Obx(() => PieChart(PieChartData(
              sections: controller.categoryTotals.entries.map((e) => PieChartSectionData(
                  value: e.value, title: e.key, color: categoryColors[e.key] ?? Colors.grey,
                  radius: 50, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
              )).toList()
          )))),

          // --- TOTAL
          Obx(() => Text("Total: RM ${controller.totalGroceryPrice.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00A676)))),

          // --- LIST VIEW WITH SWIPE-TO-DELETE
          Expanded(
            child: Obx(() => ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: controller.groceryList.length,
              itemBuilder: (context, index) {
                final item = controller.groceryList[index];

                return Dismissible(
                  key: Key(item.name),
                  background: Container(
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(15)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  onDismissed: (dir) => controller.toggleGroceryItem(item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                    child: ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${item.category} • RM ${item.price.toStringAsFixed(2)}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF00A676)),
                        onPressed: () => _showEditBottomSheet(context, item),
                      ),
                    ),
                  ),
                );
              },
            )),
          ),
        ],
      ),
    );
  }

  // --- EDIT UI
  void _showEditBottomSheet(BuildContext context, GroceryItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.price.toString());
    final RxString category = item.category.obs;
    final List<String> categories = ["General", "Produce", "Dairy", "Protein", "Bakery", "Other"];

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Item", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name", icon: Icon(Icons.local_grocery_store_outlined)),
            ),

            TextFormField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Price (RM)", icon: Icon(Icons.attach_money)),
            ),

            const SizedBox(height: 10),

            Obx(() => DropdownButtonFormField<String>(
              initialValue: category.value,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => category.value = val!,
              decoration: const InputDecoration(labelText: "Category", icon: Icon(Icons.category_outlined)),
            )),

            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A676), minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  controller.editGroceryItem(oldName: item.name, newName: nameCtrl.text, newPrice: double.tryParse(priceCtrl.text) ?? 0.0, newCategory: category.value);
                  Get.back();
                }
              },
              child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }}