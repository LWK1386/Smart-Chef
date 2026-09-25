import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_model.dart';
import '../services/pedometer_service.dart';
import '../services/local_db_service.dart';

class NutritionController extends GetxController {
  final SupabaseClient _client = Supabase.instance.client;

  // ─── Observable State ───────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Today's nutrition data
  final RxDouble totalCalories = 0.0.obs;
  final RxDouble totalProtein = 0.0.obs;
  final RxDouble totalCarbs = 0.0.obs;
  final RxDouble totalFat = 0.0.obs;

  // Goals
  final Rx<UserGoals?> goals = Rx<UserGoals?>(null);

  // Health data (steps, burned, water)
  final Rx<DailyHealthData?> healthData = Rx<DailyHealthData?>(null);

  // Today's individual meal logs
  final RxList<NutritionLog> todayLogs = <NutritionLog>[].obs;

  // Water intake (reactive for real-time tap updates)
  final RxInt waterGlasses = 0.obs;

  // ─── Computed getters ────────────────────────────────────────────────────────
  final RxDouble calorieGoal = 2000.0.obs;
  final RxDouble proteinGoal = 150.0.obs;
  final RxDouble carbsGoal   = 250.0.obs;
  final RxDouble fatGoal     = 65.0.obs;
  final RxInt    waterGoal   = 8.obs;
  final RxString pedestrianStatus = 'unknown'.obs;
  final RxInt stepGoal = 10000.obs;

  Timer? _midnightTimer;
  Timer? _stepSaveTimer;

  double get calorieProgress => (totalCalories.value / calorieGoal.value).clamp(0.0, 1.0);
  double get proteinProgress => (totalProtein.value / proteinGoal.value).clamp(0.0, 1.0);
  double get carbsProgress => (totalCarbs.value / carbsGoal.value).clamp(0.0, 1.0);
  double get fatProgress => (totalFat.value / fatGoal.value).clamp(0.0, 1.0);
  double get waterProgress => (waterGlasses.value / waterGoal.value).clamp(0.0, 1.0);
  double get caloriesRemaining => calorieGoal.value - totalCalories.value +1;

  String _cachedUserId = '';
  String get userId {
    final id = _client.auth.currentUser?.id ?? '';
    if (id.isNotEmpty) _cachedUserId = id;
    return id.isNotEmpty ? id : _cachedUserId;
  }
  final _localDb = LocalDbService();

  // ─── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    loadDashboard().then((_) {
      _startPedometer();
    });
    _scheduleMidnightReset();
  }



  // ─── Main Loader ─────────────────────────────────────────────────────────────
  Future<void> loadDashboard() async {
    if (userId.isEmpty) return;

    // Check connectivity FIRST — skip auth refresh if offline
    final connectResult = await Connectivity().checkConnectivity();
    final isOffline = connectResult.every((r) => r == ConnectivityResult.none);

    if (!isOffline) {
      // Only refresh session when online
      try {
        await Supabase.instance.client.auth.refreshSession()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    isLoading.value = true;
    try {
      await Future.wait([
        _loadGoals(),
        _loadTodayLogs(),
        _loadHealthData(),
      ]);
    } catch (e) {
      _handleError('loadDashboard', e);
    } finally {
      isLoading.value = false;

      if (isOffline) {
        Get.snackbar(
          'Offline Mode',
          'Showing cached data. Please connect to the internet to sync.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orangeAccent,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _startPedometer() {
    PedometerService.startListening(
      stepsCallback: (steps) {
        final currentWater = waterGlasses.value > 0
            ? waterGlasses.value
            : healthData.value?.waterIntake ?? 0;

        healthData.value = DailyHealthData(
          userId: userId,
          steps: steps,
          caloriesBurned: PedometerService.estimatedCaloriesBurned,
          waterIntake: currentWater,
          source: 'pedometer',
          recordedAt: DateTime.now(),
        );
        _saveStepsToSupabase(steps);
      },
      statusCallback: (status) {
        pedestrianStatus.value = status;
      },
    );
  }

  void _saveStepsToSupabase(int steps) {
    _stepSaveTimer?.cancel();
    _stepSaveTimer = Timer(const Duration(seconds: 5), () async {

      // Save to SQLite — works online AND offline
      await _localDb.cacheHealthData(DailyHealthData(
        userId: userId,
        steps: steps,
        caloriesBurned: PedometerService.estimatedCaloriesBurned,
        waterIntake: waterGlasses.value,
        source: 'pedometer',
        recordedAt: DateTime.now(),
      ));

      // Then try Supabase — only works online
      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        await _client.from('health_data').upsert({
          'user_id': userId,
          'steps': steps,
          'calories_burned': PedometerService.estimatedCaloriesBurned,
          'water_intake': waterGlasses.value,
          'source': 'pedometer',
          'recorded_at': startOfDay.toIso8601String(),
        }, onConflict: 'user_id, recorded_at');
        print('=== STEPS SAVED TO SUPABASE: $steps ===');
      } catch (e) {
        print('=== STEPS SAVE ERROR (offline, SQLite saved): $e ===');
      }
    });
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1); // next midnight
    final timeUntilMidnight = midnight.difference(now);

    _midnightTimer = Timer(timeUntilMidnight, () {
      // Reset water to 0 at midnight
      waterGlasses.value = 0;
      healthData.value = DailyHealthData(
        userId: userId,
        steps: 0,
        caloriesBurned: 0,
        waterIntake: 0,
        source: 'manual',
        recordedAt: DateTime.now(),
      );
      // Reload fresh data for the new day
      loadDashboard();
      // Schedule next midnight reset
      _scheduleMidnightReset();
    });
  }

  // ─── Goals ───────────────────────────────────────────────────────────────────
  Future<void> _loadGoals() async {
    try {
      final data = await _client
          .from('user_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      final g = data != null
          ? UserGoals.fromMap(data)
          : UserGoals.defaults(userId);

      goals.value       = g;
      calorieGoal.value = g.calorieGoal;
      proteinGoal.value = g.proteinGoal;
      carbsGoal.value   = g.carbsGoal;
      fatGoal.value     = g.fatGoal;
      waterGoal.value   = g.waterGoal;
      stepGoal.value    = g.stepGoal;

      await _localDb.cacheUserGoals(g);
    } catch (e) {
      // Try SQLite cache first
      final cached = await _localDb.getCachedUserGoals(userId);
      final g = cached ?? UserGoals.defaults(userId);
      goals.value       = g;
      calorieGoal.value = g.calorieGoal;
      proteinGoal.value = g.proteinGoal;
      carbsGoal.value   = g.carbsGoal;
      fatGoal.value     = g.fatGoal;
      waterGoal.value   = g.waterGoal;
      stepGoal.value    = g.stepGoal;
    }
  }

  Future<void> saveGoals(UserGoals newGoals) async {
    isSaving.value = true;
    try {
      await _client.from('user_goals').upsert(
        newGoals.toMap(),
        onConflict: 'user_id',
      );
      goals.value       = newGoals;
      calorieGoal.value = newGoals.calorieGoal;
      proteinGoal.value = newGoals.proteinGoal;
      carbsGoal.value   = newGoals.carbsGoal;
      fatGoal.value     = newGoals.fatGoal;
      waterGoal.value   = newGoals.waterGoal;
      stepGoal.value = newGoals.stepGoal;

      await _localDb.cacheUserGoals(newGoals);
    } catch (e) {
      _handleError('saveGoals', e);
    } finally {
      isSaving.value = false;
    }
  }

  // ─── Today's Logs ────────────────────────────────────────────────────────────
  Future<void> _loadTodayLogs() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _client
          .from('nutrition_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .lt('logged_at', endOfDay.toIso8601String())
          .order('logged_at', ascending: false)
          .timeout(const Duration(seconds: 3));

      final logs = (data as List).map((e) => NutritionLog.fromMap(e)).toList();
      todayLogs.value = logs;
      _recalcTotals(logs);
      await _localDb.cacheNutritionLogs(logs);
    } catch (e) {
      final today = DateTime.now();
      final cached = await _localDb.getNutritionLogsForDate(userId, today);
      if (cached.isNotEmpty) {
        todayLogs.value = cached;
        _recalcTotals(cached);
      } else {
        _useMockNutritionData();
      }
    }
  }

  void _recalcTotals(List<NutritionLog> logs) {
    totalCalories.value = logs.fold(0, (sum, l) => sum + l.calories);
    totalProtein.value = logs.fold(0, (sum, l) => sum + l.protein);
    totalCarbs.value = logs.fold(0, (sum, l) => sum + l.carbs);
    totalFat.value = logs.fold(0, (sum, l) => sum + l.fat);
  }

  void _useMockNutritionData() {
    totalCalories.value = 1450;
    totalProtein.value = 98;
    totalCarbs.value = 165;
    totalFat.value = 52;
  }

  Future<void> logMeal({
    required String mealType,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double servingSize = 100,
    String? barcode,
  }) async {
    isSaving.value = true;
    try {
      final log = NutritionLog(
        id: '',
        userId: userId,
        mealType: mealType,
        foodName: foodName,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        servingSize: servingSize,
        barcode: barcode,
        loggedAt: DateTime.now(),
      );

      await _client.from('nutrition_logs').insert(log.toMap());
      await _loadTodayLogs(); // Refresh
      Get.snackbar('Logged', '$foodName added to $mealType.',
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      _handleError('logMeal', e);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteLog(String logId) async {
    try {
      await _client.from('nutrition_logs').delete().eq('id', logId);
      todayLogs.removeWhere((l) => l.id == logId);
      _recalcTotals(todayLogs);
      await _localDb.deleteNutritionLog(logId);
    } catch (e) {
      _handleError('deleteLog', e);
    }
  }

  // ─── Health Data ─────────────────────────────────────────────────────────────
  Future<void> _loadHealthData() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final data = await _client
          .from('health_data')
          .select()
          .eq('user_id', userId)
          .gte('recorded_at', startOfDay.toIso8601String())
          .lt('recorded_at', startOfDay.add(const Duration(days: 1)).toIso8601String())
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (data != null) {
        final loaded = DailyHealthData.fromMap(data);
        // Only use DB steps if pedometer hasn't started yet
        if (healthData.value == null || healthData.value!.source != 'pedometer') {
          healthData.value = loaded;
        } else {
          // Pedometer already running — only restore water, don't overwrite steps
          waterGlasses.value = loaded.waterIntake;
        }
        waterGlasses.value = loaded.waterIntake;
        await _localDb.cacheHealthData(loaded);
      } else {
        final cached = await _localDb.getCachedHealthData(userId, today);
        healthData.value = cached ?? DailyHealthData.empty(userId);
        waterGlasses.value = healthData.value!.waterIntake;
      }
    } catch (e) {
      final today = DateTime.now();
      final cached = await _localDb.getCachedHealthData(userId, today);
      healthData.value = cached ?? DailyHealthData.empty(userId);
      waterGlasses.value = healthData.value!.waterIntake;
    }
  }

  Future<void> setWaterGlasses(int count) async {
    waterGlasses.value = count;

    // Update local SQLite cache immediately — don't wait for Supabase
    if (healthData.value != null) {
      final updated = DailyHealthData(
        userId: userId,
        steps: healthData.value!.steps,
        caloriesBurned: healthData.value!.caloriesBurned,
        waterIntake: count,                    // updated count
        source: healthData.value!.source,
        recordedAt: healthData.value!.recordedAt,
      );
      await _localDb.cacheHealthData(updated);
    }

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      await _client.from('health_data').upsert({
        'user_id': userId,
        'water_intake': count,
        'steps': healthData.value?.steps ?? 0,
        'calories_burned': healthData.value?.caloriesBurned ?? 0,
        'source': healthData.value?.source ?? 'manual',
        'recorded_at': startOfDay.toIso8601String(),
      }, onConflict: 'user_id, recorded_at');
    } catch (e) {
      // Silent fail — SQLite already updated above
    }
  }

  // ─── Weekly data for charts ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWeeklyCalories() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 6));

      final data = await _client
          .from('nutrition_logs')
          .select('calories, logged_at')
          .eq('user_id', userId)
          .gte('logged_at', startDate.toIso8601String())
          .lte('logged_at', endDate.toIso8601String())
          .order('logged_at', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ─── Error handler ───────────────────────
  void _handleError(String context, dynamic e) {
    print('NutritionController.$context error: $e');
    Get.snackbar(
      '❌ Error',
      e.toString(),
      snackPosition: SnackPosition.TOP,
    );
  }

  @override
  void onClose() {
    _stepSaveTimer?.cancel();
    _midnightTimer?.cancel();
    PedometerService.stopListening();
    super.onClose();
  }
}