import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:smart_chef/screens/planner/planner_screen.dart';
import 'package:smart_chef/screens/waste/ingredients_choice.dart';
import 'package:smart_chef/screens/waste/waste_screen.dart';
import '../controllers/post_controller.dart';
import '/screens/blog/blog_feed_screen.dart';
import '/screens/profile/me_screen.dart';
import 'package:smart_chef/screens/health/nutrition_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    BlogFeedScreen(),
    const SmartPlannerScreen(), //change this to your module - SHA
    IngredientChoicePage(), //change this to your module - WK
    NutritionDashboardScreen(), //change this to your module - JX
    const MeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });

          // Check if controller exists to prevent crashes on first load
          if (Get.isRegistered<PostController>()) {
            final postController = Get.find<PostController>();

            if (index == 0) {
              // User is on Blog Feed, Turn Sensor On
              postController.canShake = true;
            } else {
              // Turn Sensor Off if other page
              postController.canShake = false;
            }
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00A676),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.delete_outline),
            label: 'Waste',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}