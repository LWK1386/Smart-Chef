
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/nutrition_controller.dart';
import '../../screens/health/add_meal_screen.dart';
import '../../theme/colors.dart';
import 'meal_history_screen.dart';
import 'nutrition_analytics_screen.dart';
import 'dietary_preferences_screen.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef _C = C;

// SCREEN
class NutritionDashboardScreen extends StatefulWidget {
  const NutritionDashboardScreen({super.key});

  @override
  State<NutritionDashboardScreen> createState() =>
      _NutritionDashboardScreenState();
}

class _NutritionDashboardScreenState extends State<NutritionDashboardScreen>
    with TickerProviderStateMixin {
  late final NutritionController _ctrl;
  late final AnimationController _ringAnim;
  late final AnimationController _barsAnim;
  late final AnimationController _entryAnim;

  bool _isOffline = false;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();

    _ctrl = Get.put(NutritionController());

    _ringAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _barsAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _entryAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _entryAnim.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _ringAnim.forward();
      _barsAnim.forward();
    });

    Connectivity().checkConnectivity().then((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
  }

  @override
  void dispose() {
    _ringAnim.dispose();
    _barsAnim.dispose();
    _entryAnim.dispose();
    super.dispose();
    _connectivitySub?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Obx(() {
        if (_ctrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: _C.primary),
          );
        }
        return _buildBody();
      }),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 12),
              _buildCalorieHeroCard(),
              const SizedBox(height: 12),
              _buildQuickActionRow(),
              const SizedBox(height: 12),
              _buildMacroCard(),
              const SizedBox(height: 16),
              _buildWaterCard(),
              const SizedBox(height: 16),
              _buildActivityRow(),
              const SizedBox(height: 96), // FAB clearance
            ]),
          ),
        ),
      ],
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: _C.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      expandedHeight: 70,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                        fontSize: 13,
                        color: _C.text2,
                        fontWeight: FontWeight.w500),
                  ),
                  const Text(
                    'Nutrition',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _C.text1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF00A676)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _ctrl.loadDashboard();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero calorie ring card ──────────────────────────────────────────────────
  Widget _buildCalorieHeroCard() {
    return AnimatedBuilder(
      animation: _ringAnim,
      builder: (_, __) {
        final t = CurvedAnimation(
            parent: _ringAnim, curve: Curves.easeOutCubic)
            .value;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color(0xFF00A676),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: _C.dark.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Row(
            children: [
              // Ring
              SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Obx(() => CustomPaint(
                      size: const Size(148, 148),
                      painter: _RingPainter(
                        progress: _ctrl.calorieProgress * t,
                      ),
                    )),
                    Obx(() => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(_ctrl.totalCalories.value * t).toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const Text('kcal',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Container(
                            width: 32, height: 1, color: Colors.white24),
                        const SizedBox(height: 4),
                        Obx(() => Text(
                          'of ${_ctrl.calorieGoal.toInt()} goal',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        )),
                      ],
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Stats
              Expanded(
                child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _heroStat(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Consumed',
                      value:
                      '${_ctrl.totalCalories.value.toInt()} kcal',
                      color: const Color(0xFFFFB74D),
                    ),
                    const SizedBox(height: 14),
                    _heroStat(
                      icon: Icons.fitness_center_rounded,
                      label: 'Burned',
                      value:
                      '${_ctrl.healthData.value?.caloriesBurned.toInt() ?? 0} kcal',
                      color: const Color(0xFF81C784),
                    ),
                    const SizedBox(height: 14),
                    _heroStat(
                      icon: Icons.battery_charging_full_rounded,
                      label: 'Remaining',
                      value:
                      '${_ctrl.caloriesRemaining.toInt()} kcal',
                      color: const Color(0xFF64B5F6),
                    ),
                  ],
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Get.to(
                  () => const NutritionAnalyticsScreen(),
              transition: Transition.rightToLeft,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10, offset: const Offset(0, 3),
                )],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _C.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.show_chart_rounded,
                        color: _C.primary, size: 17),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('View Trends',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700, color: _C.text1)),
                      Text('Analytics',
                          style: TextStyle(fontSize: 10, color: _C.text3)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: _C.text3),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Get.to(
                  () => const DietaryPreferencesScreen(),
              transition: Transition.rightToLeft,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10, offset: const Offset(0, 3),
                )],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _C.carbs.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: _C.carbs, size: 17),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Goals',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700, color: _C.text1)),
                      Text('Preferences',
                          style: TextStyle(fontSize: 10, color: _C.text3)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: _C.text3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Macro Card ──────────────────────────────────────────────────────────────
  Widget _buildMacroCard() {
    return GestureDetector(
        onTap: () => Get.to(
          () => const MealHistoryScreen(),
      transition: Transition.rightToLeft,
    ),
    child: _card(
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Macronutrients', 'View History →'),
          Obx(() {
            final g = _ctrl.goals.value;
            if (g == null) return const SizedBox.shrink();
            final active = <String>[];
            if (g.isVegetarian) active.add('🥦 Vegetarian');
            if (g.isVegan)      active.add('🌱 Vegan');
            if (g.isLowCarb)    active.add('🥑 Low Carb');
            if (g.isHighProtein) active.add('💪 High Protein');
            if (g.isKeto)       active.add('🔥 Keto');
            if (active.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Wrap(
                spacing: 6,
                children: active.map((label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(label,
                      style: const TextStyle(fontSize: 11, color: _C.primary,
                          fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            );
          }),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _barsAnim,
            builder: (_, __) {
              final t = CurvedAnimation(
                  parent: _barsAnim, curve: Curves.easeOutCubic)
                  .value;
              return Obx(() => Column(
                children: [
                  _macroBar(
                      emoji: '🥩',
                      label: 'Protein',
                      current: _ctrl.totalProtein.value,
                      goal: _ctrl.proteinGoal.value,
                      progress: _ctrl.proteinProgress * t,
                      color: _C.protein),
                  const SizedBox(height: 14),
                  _macroBar(
                      emoji: '🌾',
                      label: 'Carbs',
                      current: _ctrl.totalCarbs.value,
                      goal: _ctrl.carbsGoal.value,
                      progress: _ctrl.carbsProgress * t,
                      color: _C.carbs),
                  const SizedBox(height: 14),
                  _macroBar(
                      emoji: '🫒',
                      label: 'Fat',
                      current: _ctrl.totalFat.value,
                      goal: _ctrl.fatGoal.value,
                      progress: _ctrl.fatProgress * t,
                      color: _C.fat),
                ],
              ));
            },
          ),
        ],
      ),
    ),
    );
  }

  Widget _macroBar({
    required String emoji,
    required String label,
    required double current,
    required double goal,
    required double progress,
    required Color color,
  }) {
    final bool isExceeded = current > goal;
    final double overPercent = isExceeded ? ((current - goal) / goal * 100) : 0;
    final Color activeColor = isExceeded ? _C.errorRed : color;
    final double clampedProgress = progress.clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: isExceeded
          ? const EdgeInsets.fromLTRB(10, 10, 10, 10)
          : EdgeInsets.zero,
      decoration: isExceeded
          ? BoxDecoration(
        color: _C.errorRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.errorRed.withValues(alpha: 0.25)),
      )
          : const BoxDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isExceeded ? _C.errorRed : _C.text1)),
                if (isExceeded) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _C.errorRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_rounded,
                            color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          '+${overPercent.toInt()}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${current.toInt()}',
                      style: TextStyle(
                          color: activeColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: ' / ${goal.toInt()}g',
                      style: const TextStyle(color: _C.text3, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Stack(children: [
            Container(
              height: 9,
              decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5)),
            ),
            FractionallySizedBox(
              widthFactor: clampedProgress,
              child: Container(
                height: 9,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isExceeded
                        ? [_C.errorRed.withValues(alpha: 0.7), _C.errorRed]
                        : [color.withValues(alpha: 0.65), color],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 2))
                  ],
                ),
              ),
            ),
            // Red glowing dot at end of bar when exceeded
            if (isExceeded)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _C.errorRed,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                          color: _C.errorRed.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1),
                    ],
                  ),
                ),
              ),
          ]),
          // Message below bar when exceeded
          if (isExceeded) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: _C.errorRed),
                const SizedBox(width: 4),
                Text(
                  '${(current - goal).toInt()}g over your daily $label goal',
                  style: const TextStyle(
                      fontSize: 11,
                      color: _C.errorRed,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Water Tracker ───────────────────────────────────────────────────────────
  Widget _buildWaterCard() {
    return _card(
        child: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: _C.water.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.water_drop_rounded,
                      color: _C.water, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Water Intake',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.text1)),
              ]),
              Text(
                '${_ctrl.waterGlasses.value} / ${_ctrl.waterGoal} glasses',
                style: const TextStyle(
                    fontSize: 13,
                    color: _C.water,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
            _ctrl.waterGoal.value,
            (i) => Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () {
                if (_isOffline) {
                  Get.snackbar(
                    '📵 You\'re Offline',
                    'Connect to update water intake.',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.orange.shade400,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                  return;
                }
                HapticFeedback.lightImpact();
                if (i >= _ctrl.waterGlasses.value) {
                  _ctrl.setWaterGlasses(i + 1);
                }
              },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.elasticOut,
                  width: 30,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isOffline
                        ? (i < _ctrl.waterGlasses.value
                        ? _C.water.withValues(alpha: 0.4)
                        : _C.water.withValues(alpha: 0.05))
                        : (i < _ctrl.waterGlasses.value
                        ? _C.water
                        : _C.water.withValues(alpha: 0.09)),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: i < _ctrl.waterGlasses.value
                        ? [
                      BoxShadow(
                          color: _C.water.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                        : [
                      const BoxShadow(
                          color: Colors.transparent,
                          blurRadius: 0,
                          offset: Offset(0, 0))
                    ],
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 16,
                    color: _isOffline
                        ? _C.water.withValues(alpha: 0.3)
                        : (i < _ctrl.waterGlasses.value
                        ? Colors.white
                        : _C.water.withValues(alpha: 0.35)),
                  ),
                ),
              ),
            )),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: _ctrl.waterProgress,
              backgroundColor: _C.water.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(_C.water),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_ctrl.waterGlasses.value * 250} ml consumed today',
            style:
            const TextStyle(fontSize: 11, color: _C.text3),
          ),
          ],
      ),
        ));
  }

  // ── Activity Row ────────────────────────────────────────────────────────────
  Widget _buildActivityRow() {
    return Obx(() {
      final h = _ctrl.healthData.value;
      final steps = h?.steps ?? 0;
      final burned = h?.caloriesBurned ?? 0;

      return Row(
        children: [
          Expanded(
            child: _activityCard(
              icon: Icons.directions_walk_rounded,
              color: _C.steps,
              title: 'Steps',
              value: '$steps',
              sub: 'Goal: ${(_ctrl.stepGoal.value / 1000).toStringAsFixed(1)}k',
              progress: (steps / _ctrl.stepGoal.value).clamp(0.0, 1.0),
              badge: _ctrl.pedestrianStatus.value == 'walking' ? '🚶 Walking' : '⏸ Stopped',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _activityCard(
              icon: Icons.local_fire_department_rounded,
              color: _C.burn,
              title: 'Burned',
              value: '${burned.toInt()}',
              sub: 'kcal active',
              progress: (burned / 500).clamp(0.0, 1.0),
              badge: 'Pedometer',
            ),
          ),
        ],
      );
    });
  }

  Widget _activityCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String sub,
    required double progress,
    required String badge,
  }) {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 19),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7)),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(fontSize: 11, color: _C.text2)),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _C.text1,
                  height: 1.1)),
          Text(sub,
              style:
              const TextStyle(fontSize: 11, color: _C.text3)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ─────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      heroTag: 'add_meal_fab',
      onPressed: () {
        Get.to(() => const AddMealScreen(), transition: Transition.downToUp);
      },
      backgroundColor: _C.primary,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      label: const Text(
        'Add Meal',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.055),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, String sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.text1)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8)),
          child: Text(sub,
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 🌅';
    if (h < 17) return 'Good afternoon ☀️';
    return 'Good evening 🌙';
  }
}

// CUSTOM PAINTER — Calorie Ring
class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 11;
    const sw = 13.0;

    // Track
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw);

    if (progress <= 0) return;

    // Arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: const [Color(0xFF81C784), Color(0xFFA5D6A7), _C.primary],
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arcPaint,
    );

    // End dot
    final angle = -math.pi / 2 + math.pi * 2 * progress;
    final dot = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    canvas.drawCircle(dot, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 3.5, Paint()..color = _C.primary);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}