import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../controllers/engagement_controller.dart'; // Update path if needed

class EngagementScreen extends StatelessWidget {
  const EngagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the controller when screen loads
    final controller = Get.put(EngagementController());
    final primaryGreen = const Color(0xFF00A676);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Engagement Stats", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildMonthFilter(controller, primaryGreen),
          const SizedBox(height: 20),
          _buildMetricToggle(controller, primaryGreen),
          const SizedBox(height: 40),

          // The Chart Container
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: controller.chartSections,
                      centerSpaceRadius: 70, // Creates the "Donut" hole
                      sectionsSpace: 3,
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 500),
                  ),
                  // Center Text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.totalCenterCount.toString(),
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryGreen),
                      ),
                      Text(
                        "Total ${controller.selectedMetric.value.capitalizeFirst}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Horizontal Scrolling Month Chips
  Widget _buildMonthFilter(EngagementController controller, Color primaryGreen) {
    // Generate the last 5 months based on today's date
    final now = DateTime.now();
    final months = List.generate(5, (index) => DateTime(now.year, now.month - index, 1)).reversed.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() => Row(
        children: months.map((month) {
          final isSelected = controller.selectedMonth.value.year == month.year &&
              controller.selectedMonth.value.month == month.month;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(DateFormat('MMM yyyy').format(month)), // e.g., "Mar 2026"
              selected: isSelected,
              onSelected: (selected) {
                if (selected) controller.updateMonth(month);
              },
              selectedColor: primaryGreen.withOpacity(0.2),
              backgroundColor: Colors.grey[100],
              labelStyle: TextStyle(
                  color: isSelected ? primaryGreen : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
              side: BorderSide.none,
            ),
          );
        }).toList(),
      )),
    );
  }

  Widget _buildMetricToggle(EngagementController controller, Color primaryGreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Obx(() => SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'likes', label: Text('Likes'), icon: Icon(Icons.favorite)),
          ButtonSegment(value: 'comments', label: Text('Comments'), icon: Icon(Icons.comment)),
        ],
        selected: {controller.selectedMetric.value},
        onSelectionChanged: (Set<String> newSelection) {
          controller.updateMetric(newSelection.first);
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) return primaryGreen.withOpacity(0.2);
            return Colors.transparent;
          }),
        ),
      )),
    );
  }
}