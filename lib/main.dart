import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:smart_chef/screens/blog/blog_feed_screen.dart';
import 'package:smart_chef/screens/dashboard_screen.dart';
import 'package:smart_chef/services/local_db_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_chef/screens/login/login_screen.dart';
import 'package:smart_chef/screens/health/nutrition_dashboard_screen.dart';
import 'package:smart_chef/screens/health/meal_history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://onpgamhynuwavemaskqy.supabase.co',
    anonKey: 'sb_publishable_EDvi6-MQTfeM9NWQvVZDXg_kIhcDpCu',
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );
  // Initialize SQLite
  await LocalDbService().database;

  // Check if a user session is already saved on the phone
  final session = Supabase.instance.client.auth.currentSession;

  runApp(GetMaterialApp(
    // If session exists, skip login and go to the main app layout
    initialRoute: session != null ? '/home' : '/login',
    getPages: [
      GetPage(name: '/login', page: () => LoginScreen()),
      GetPage(name: '/home', page: () => DashboardScreen()),
    ],
  ));
}

final supabase = Supabase.instance.client;

class SmartChefApp extends StatelessWidget {
  const SmartChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SmartChef',
      theme: ThemeData(
        primaryColor: const Color(0xFF00A676),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: const Color(0xFFFF9800)),
      ),
      // 1. Define the initial route (where the app starts)
      initialRoute: '/login',

      // 2. Map the names to the actual Screen widgets
      getPages: [
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
        ),
        GetPage(
          name: '/home',
           page: () => const DashboardScreen(),
         ),
        GetPage(
          name: '/nutrition',
          page: () => const NutritionDashboardScreen(),
        ),
        GetPage(
          name: '/meal-history',
          page: () => const MealHistoryScreen(),
        ),
      ],
    );
  }
}
