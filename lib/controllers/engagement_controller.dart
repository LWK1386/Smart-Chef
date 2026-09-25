import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class EngagementController extends GetxController {
  final supabase = Supabase.instance.client;

  var isLoading = true.obs;
  var selectedMetric = 'likes'.obs;
  var selectedMonth = DateTime.now().obs;

  // Data for the chart
  var chartSections = <PieChartSectionData>[].obs;
  var totalCenterCount = 0.obs;

  // Store raw data to avoid re-fetching when switching likes <-> comments
  List<dynamic> _rawPostData = [];

  final List<Color> chartColors = [
    const Color(0xFF00A676), // Mint
    const Color(0xFFFF9800), // Orange
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF2196F3), // Blue
    const Color(0xFFF44336), // Red
  ];

  @override
  void onInit() {
    super.onInit();
    fetchEngagementData();
  }

  void updateMetric(String metric) {
    selectedMetric.value = metric;
    _processChartData();
  }

  void updateMonth(DateTime newMonth) {
    selectedMonth.value = newMonth;
    fetchEngagementData();
  }

  Future<void> fetchEngagementData() async {
    try {
      isLoading.value = true;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Calculate month boundaries for Supabase query
      final startOfMonth = DateTime(selectedMonth.value.year, selectedMonth.value.month, 1);
      final endOfMonth = DateTime(selectedMonth.value.year, selectedMonth.value.month + 1, 0, 23, 59, 59);

      // Fetch posts with like and comment counts
      _rawPostData = await supabase
          .from('posts')
          .select('title, likes(count), comments(count)')
          .eq('user_id', userId)
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      _processChartData();
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      Get.snackbar("Error", "Could not load engagement data");
    } finally {
      isLoading.value = false;
    }
  }

  void _processChartData() {
    List<PieChartSectionData> sections = [];
    int total = 0;
    int colorIndex = 0;

    for (var post in _rawPostData) {
      // Safely extract counts (Supabase returns count queries as lists of maps)
      int likes = (post['likes'] != null && post['likes'].isNotEmpty) ? post['likes'][0]['count'] as int : 0;
      int comments = (post['comments'] != null && post['comments'].isNotEmpty) ? post['comments'][0]['count'] as int : 0;

      int targetCount = selectedMetric.value == 'likes' ? likes : comments;

      if (targetCount > 0) {
        total += targetCount;
        sections.add(
          PieChartSectionData(
            value: targetCount.toDouble(),
            title: targetCount.toString(),
            color: chartColors[colorIndex % chartColors.length],
            radius: 50,
            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: _Badge(post['title'].toString().split(' ').first), // Takes first word of title
            badgePositionPercentageOffset: 1.3,
          ),
        );
        colorIndex++;
      }
    }

    // Handle empty state visually
    if (sections.isEmpty) {
      sections.add(
          PieChartSectionData(
            value: 1,
            title: "0",
            color: Colors.grey[200],
            radius: 50,
          )
      );
    }

    chartSections.value = sections;
    totalCenterCount.value = total;
  }
}

// Helper widget to show post title outside the pie slice
class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.black87)),
    );
  }
}