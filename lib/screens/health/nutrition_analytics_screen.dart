import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/nutrition_model.dart';
import '../../controllers/nutrition_controller.dart';
import '../../theme/colors.dart';
import '../../services/local_db_service.dart';
import 'package:collection/collection.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef _C = C;

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class NutritionAnalyticsScreen extends StatefulWidget {
  const NutritionAnalyticsScreen({super.key});

  @override
  State<NutritionAnalyticsScreen> createState() =>
      _NutritionAnalyticsScreenState();
}

class _NutritionAnalyticsScreenState extends State<NutritionAnalyticsScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _client = Supabase.instance.client;
  late final NutritionController _ctrl;

  final _localDb = LocalDbService();

  // Animation controllers
  late final AnimationController _fadeAnim;
  late final AnimationController _chartAnim;

  // State
  String _period = 'Weekly'; // 'Weekly' | 'Monthly'
  bool _isLoading = true;
  List<_DayData> _chartData = [];
  List<NutritionLog> _recentLogs = [];
  String _deletingId = '';
  bool _isOffline = false;
  StreamSubscription? _connectivitySub;

  String get _userId => _client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<NutritionController>();
    _fadeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _chartAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _loadData();
    Connectivity().checkConnectivity().then((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
  }

  @override
  void dispose() {
    _fadeAnim.dispose();
    _chartAnim.dispose();
    super.dispose();
    _connectivitySub?.cancel();
  }

  // ── Data Loading ─────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _chartAnim.reset();
    try {
      final days = _period == 'Weekly' ? 7 : 30;
      final end = DateTime.now();
      final start = end.subtract(Duration(days: days - 1));

      List<NutritionLog> allLogs = [];
      try {
        final logsData = await _client
            .from('nutrition_logs')
            .select()
            .eq('user_id', _userId)
            .gte('logged_at', DateTime(start.year, start.month, start.day).toIso8601String())
            .lte('logged_at', DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String())
            .order('logged_at', ascending: true);
        allLogs = (logsData as List).map((e) => NutritionLog.fromMap(e)).toList();

        // Cache ALL logs from the full date range — not just today
        if (allLogs.isNotEmpty) {
          await _localDb.cacheNutritionLogs(allLogs);
          print('=== ANALYTICS: cached ${allLogs.length} logs to SQLite ===');
        }
      } catch (e) {
        // Offline — load each day from SQLite
        for (int i = 0; i < days; i++) {
          final d = start.add(Duration(days: i));
          final cached = await _localDb.getNutritionLogsForDate(_userId, d);
          allLogs.addAll(cached);
        }
        print('=== ANALYTICS OFFLINE: loaded ${allLogs.length} logs from SQLite ===');
      }

      // Build per-day aggregates
      final Map<String, _DayData> byDay = {};
      for (int i = 0; i < days; i++) {
        final d = start.add(Duration(days: i));
        final key = _dateKey(d);
        byDay[key] = _DayData(date: d);
      }
      for (final log in allLogs) {
        final key = _dateKey(log.loggedAt);
        if (byDay.containsKey(key)) {
          byDay[key]!.calories += log.calories;
          byDay[key]!.protein += log.protein;
          byDay[key]!.carbs += log.carbs;
          byDay[key]!.fat += log.fat;
        }
      }

      final Map<String, double> burnedByDay = {};
      try {
        final healthRawData = await _client
            .from('health_data')
            .select('user_id, steps, calories_burned, water_intake, source, recorded_at')
            .eq('user_id', _userId)
            .gte('recorded_at', DateTime(start.year, start.month, start.day).toIso8601String())
            .lte('recorded_at', DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String())
            .order('recorded_at', ascending: true);

        await _localDb.cacheHealthDataList(
            List<Map<String, dynamic>>.from(healthRawData));

        for (final row in healthRawData as List) {
          final date = DateTime.tryParse(row['recorded_at'] ?? '');
          if (date == null) continue;
          final key = _dateKey(date);
          final burned = (row['calories_burned'] as num?)?.toDouble() ?? 0;
          if (!burnedByDay.containsKey(key) || burned > burnedByDay[key]!) {
            burnedByDay[key] = burned;
          }
        }
        print('=== ANALYTICS: burned calories loaded from Supabase ===');
      } catch (e) {
        // Offline — load from cached_health_data for each day
        for (int i = 0; i < days; i++) {
          final d = start.add(Duration(days: i));
          final cached = await _localDb.getCachedHealthData(_userId, d);
          if (cached != null) {
            burnedByDay[_dateKey(d)] = cached.caloriesBurned;
          }
        }
        print('=== ANALYTICS OFFLINE: burned calories loaded from SQLite ===');
      }

      for (final d in byDay.values) {
        d.burned = burnedByDay[_dateKey(d.date)] ?? 0;
      }

      List<NutritionLog> recent = [];
      try {
        final recentData = await _client
            .from('nutrition_logs')
            .select()
            .eq('user_id', _userId)
            .order('logged_at', ascending: false)
            .limit(10);
        recent = (recentData as List).map((e) => NutritionLog.fromMap(e)).toList();
      } catch (e) {
        // Offline — use allLogs already fetched, sorted newest first
        recent = allLogs
            .sorted((a, b) => b.loggedAt.compareTo(a.loggedAt))
            .take(10)
            .toList();
      }

      setState(() {
        _chartData = byDay.values.toList();
        _recentLogs = recent;
        _isLoading = false;
      });
      _fadeAnim.forward();
      _chartAnim.forward();
    } catch (e) {
      // Fallback to mock data
      _loadMockData();
    }
  }

  void _loadMockData() {
    final rand = math.Random(7);
    final now = DateTime.now();
    final days = _period == 'Weekly' ? 7 : 30;
    _chartData = List.generate(days, (i) {
      final d = now.subtract(Duration(days: days - 1 - i));
      return _DayData(date: d)
        ..calories = 1200 + rand.nextInt(900).toDouble()
        ..burned = 0
        ..protein = 80 + rand.nextInt(70).toDouble()
        ..carbs = 150 + rand.nextInt(100).toDouble()
        ..fat = 40 + rand.nextInt(40).toDouble();
    });
    setState(() => _isLoading = false);
    _fadeAnim.forward();
    _chartAnim.forward();
  }

  Future<void> _deleteLog(String id) async {
    setState(() => _deletingId = id);
    try {
      await _client.from('nutrition_logs').delete().eq('id', id);
      setState(() => _recentLogs.removeWhere((l) => l.id == id));
      _ctrl.deleteLog(id);
      await _localDb.deleteNutritionLog(id);
      HapticFeedback.mediumImpact();
      Get.snackbar('🗑️ Deleted', 'Entry removed.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: _C.errorRed,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar('❌ Error', 'Delete failed.',
          snackPosition: SnackPosition.TOP);
    } finally {
      setState(() => _deletingId = '');
    }
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: _C.primary))
                : FadeTransition(
              opacity: _fadeAnim,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _C.card,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Get.back(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analytics',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _C.text1,
                        letterSpacing: -0.3)),
                Text('Nutrition History',
                    style: TextStyle(
                        fontSize: 12,
                        color: _C.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Period dropdown
          GestureDetector(
            onTap: () => _showPeriodPicker(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_period,
                      style: const TextStyle(
                          fontSize: 13,
                          color: _C.primary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _C.primary, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00A676)),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _C.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Select Period',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.text1)),
            const SizedBox(height: 16),
            for (final p in ['Weekly', 'Monthly'])
              GestureDetector(
                onTap: () {
                  Get.back();
                  if (_period != p) {
                    setState(() => _period = p);
                    _loadData();
                  }
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _period == p
                        ? _C.primary
                        : _C.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(p,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _period == p ? Colors.white : _C.text1)),
                  ),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _buildSummaryRow(),
        const SizedBox(height: 16),
        _buildCalorieLineChart(),
        const SizedBox(height: 16),
        _buildIntakeVsBurnedChart(),
        const SizedBox(height: 16),
        _buildMacroPieChart(),
        const SizedBox(height: 16),
        _buildRecentEntries(),
      ],
    );
  }

  // ── Summary Row ───────────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    if (_chartData.isEmpty) return const SizedBox.shrink();
    final totalCal = _chartData.fold(0.0, (s, d) => s + d.calories);
    final avgCal = totalCal / _chartData.length;
    final maxCal = _chartData.map((d) => d.calories).reduce(math.max);
    final goal = _ctrl.calorieGoal.value;
    final daysOver = _chartData.where((d) => d.calories > goal).length;

    return Row(
      children: [
        Expanded(child: _summaryTile('Avg Daily', '${avgCal.toInt()} kcal',
            Icons.show_chart_rounded, _C.primary)),
        const SizedBox(width: 10),
        Expanded(child: _summaryTile('Peak Day', '${maxCal.toInt()} kcal',
            Icons.trending_up_rounded, _C.carbs)),
        const SizedBox(width: 10),
        Expanded(child: _summaryTile('Over Goal', '$daysOver days',
            Icons.warning_amber_rounded,
            daysOver > 0 ? _C.errorRed : _C.success)),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _C.text3)),
        ],
      ),
    );
  }

  // ── Calorie Line Chart ────────────────────────────────────────────────────────
  Widget _buildCalorieLineChart() {
    return _chartCard(
      title: 'Intake Calorie Trend',
      subtitle: _period,
      icon: Icons.show_chart_rounded,
      iconColor: _C.primary,
      child: SizedBox(
        height: 180,
        child: AnimatedBuilder(
          animation: _chartAnim,
          builder: (_, __) {
            final t = CurvedAnimation(
                parent: _chartAnim, curve: Curves.easeOutCubic).value;
            return CustomPaint(
              size: const Size(double.infinity, 180),
              painter: _LineChartPainter(
                data: _chartData,
                goal: _ctrl.calorieGoal.value,
                progress: t,
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Intake vs Burned Bar Chart ────────────────────────────────────────────────
  Widget _buildIntakeVsBurnedChart() {
    return _chartCard(
      title: 'Intake vs Burned',
      subtitle: 'kcal comparison',
      icon: Icons.bar_chart_rounded,
      iconColor: _C.burn,
      child: Column(
        children: [
          // Legend
          Row(
            children: [
              const SizedBox(width: 36),
              _legendDot('Intake', _C.primary),
              const SizedBox(width: 46),
              _legendDot('Burned', _C.burn),
              const SizedBox(width: 46),
              _legendDot('Exceed', _C.warning),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 56),
              _legendDot('Intake goal', _C.text3, isDashed: true),
              const SizedBox(width: 46),
              _legendDot('Burned goal', _C.steps, isDashed: true),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: AnimatedBuilder(
              animation: _chartAnim,
              builder: (_, __) {
                final t = CurvedAnimation(
                    parent: _chartAnim, curve: Curves.easeOutCubic).value;
                return CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: _BarChartPainter(
                    data: _chartData,
                    goal: _ctrl.calorieGoal.value,
                    stepGoalCalories: _ctrl.stepGoal.value * 0.04,
                    progress: t,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color, {bool isDashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDashed
            ? Row(children: List.generate(3, (_) => Container(
            width: 4, height: 2, margin: const EdgeInsets.only(right: 2),
            color: color)))
            : Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: _C.text2,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Macro Pie Chart ────────────────────────────────────────────────────────────
  Widget _buildMacroPieChart() {
    if (_chartData.isEmpty) return const SizedBox.shrink();
    final totalP = _chartData.fold(0.0, (s, d) => s + d.protein);
    final totalC = _chartData.fold(0.0, (s, d) => s + d.carbs);
    final totalF = _chartData.fold(0.0, (s, d) => s + d.fat);
    final total = totalP + totalC + totalF;
    if (total == 0) return const SizedBox.shrink();

    final pPct = (totalP / total * 100).toInt();
    final cPct = (totalC / total * 100).toInt();
    final fPct = (totalF / total * 100).toInt();

    return _chartCard(
      title: 'Macro Distribution',
      subtitle: _period,
      icon: Icons.pie_chart_rounded,
      iconColor: _C.protein,
      child: Row(
        children: [
          // Pie
          SizedBox(
            width: 130,
            height: 130,
            child: AnimatedBuilder(
              animation: _chartAnim,
              builder: (_, __) {
                final t = CurvedAnimation(
                    parent: _chartAnim, curve: Curves.easeOutCubic).value;
                return CustomPaint(
                  painter: _PieChartPainter(
                    protein: totalP,
                    carbs: totalC,
                    fat: totalF,
                    progress: t,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _macroLegendRow('🥩 Protein', pPct, _C.protein,
                    '${totalP.toInt()}g'),
                const SizedBox(height: 12),
                _macroLegendRow('🌾 Carbs', cPct, _C.carbs,
                    '${totalC.toInt()}g'),
                const SizedBox(height: 12),
                _macroLegendRow('🫒 Fat', fPct, _C.fat,
                    '${totalF.toInt()}g'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroLegendRow(
      String label, int pct, Color color, String grams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _C.text1)),
            Text('$pct%  $grams',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // ── Recent Entries ────────────────────────────────────────────────────────────
  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent Entries', '${_recentLogs.length} items'),
        const SizedBox(height: 10),
        if (_recentLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(children: [
                Text('🍽️', style: TextStyle(fontSize: 36)),
                SizedBox(height: 8),
                Text('No entries yet',
                    style: TextStyle(color: _C.text2, fontSize: 14)),
              ]),
            ),
          )
        else
          ...(_recentLogs.map((log) => _buildLogTile(log))),
      ],
    );
  }

  Widget _buildLogTile(NutritionLog log) {
    final isDeleting = _deletingId == log.id;
    final mealColors = {
      'breakfast': const Color(0xFFF59E0B),
      'lunch': const Color(0xFF10B981),
      'dinner': const Color(0xFF6366F1),
      'snack': const Color(0xFFEC4899),
    };
    final color = mealColors[log.mealType] ?? _C.primary;
    final emoji = {'breakfast': '🌅', 'lunch': '☀️',
      'dinner': '🌙', 'snack': '🍎'}[log.mealType] ?? '🍴';

    return Dismissible(
      key: Key('analytics_${log.id}'),
      direction: _isOffline
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (_isOffline) { return false; }
        HapticFeedback.mediumImpact();
        return await _showDeleteConfirm(log.foodName);
      },
      onDismissed: (_) => _deleteLog(log.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _C.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('Delete',
                style: TextStyle(
                    color: _C.errorRed, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: _C.errorRed),
          ],
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDeleting ? 0.4 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.foodName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.text1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${log.mealType.capitalizeFirst}  ·  ${_formatDate(log.loggedAt)}',
                      style: const TextStyle(fontSize: 11, color: _C.text3),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${log.calories.toInt()}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _C.text1)),
                  const Text('kcal',
                      style: TextStyle(fontSize: 10, color: _C.text3)),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: (isDeleting || _isOffline) ? null : () async {
                  if (_isOffline) {
                    Get.snackbar('📵 You\'re Offline',
                        'Connect to delete entries.',
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: Colors.orange.shade400,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2));
                    return;
                  }
                  final confirm = await _showDeleteConfirm(log.foodName);
                  if (confirm == true) _deleteLog(log.id);
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    // Grey out when offline
                    color: _isOffline
                        ? Colors.grey.withValues(alpha: 0.08)
                        : _C.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: isDeleting
                      ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _C.errorRed))
                      : Icon(Icons.delete_outline_rounded,
                      // Grey icon when offline
                      color: _isOffline ? Colors.grey : _C.errorRed,
                      size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Entry?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove "$name" from your log?',
            style: const TextStyle(color: _C.text2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: _C.text2))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: _C.errorRed, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────────
  Widget _chartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _C.text1)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: _C.text3)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
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

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day}/${d.month}';
  }
}

// DATA MODEL
class _DayData {
  final DateTime date;
  double calories = 0;
  double burned = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
  _DayData({required this.date});
}

// LINE CHART PAINTER
class _LineChartPainter extends CustomPainter {
  final List<_DayData> data;
  final double goal;
  final double progress;

  _LineChartPainter(
      {required this.data, required this.goal, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const labelHeight = 20.0;
    const leftPad = 40.0;
    const rightPad = 8.0;
    final chartH = size.height - labelHeight;
    final chartW = size.width - leftPad - rightPad;

    final maxCal = math.max(
        data.map((d) => d.calories).reduce(math.max), goal * 1.1);

    double xOf(int i) => leftPad + (i / (data.length - 1)) * chartW;
    double yOf(double v) => chartH - (v / maxCal) * chartH * progress;

    // Grid lines
    final gridPaint = Paint()
      ..color = _C.divider
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartH * (1 - i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y),
          gridPaint);
      final val = (maxCal * i / 4).toInt();
      _drawLabel(canvas, '$val', Offset(0, y - 8),
          const TextStyle(fontSize: 9, color: _C.text3));
    }

    // Goal line (dashed)
    final goalY = yOf(goal);
    final dashPaint = Paint()
      ..color = _C.text3.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    double dx = leftPad;
    while (dx < size.width - rightPad) {
      canvas.drawLine(Offset(dx, goalY), Offset(dx + 6, goalY), dashPaint);
      dx += 10;
    }

    if (data.length < 2) return;

    // Gradient fill
    final path = Path();
    path.moveTo(xOf(0), yOf(data[0].calories));
    for (int i = 1; i < data.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(data[i - 1].calories);
      final x1 = xOf(i), y1 = yOf(data[i].calories);
      final cpx = (x0 + x1) / 2;
      path.cubicTo(cpx, y0, cpx, y1, x1, y1);
    }
    path.lineTo(xOf(data.length - 1), chartH);
    path.lineTo(xOf(0), chartH);
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _C.primary.withValues(alpha: 0.25 * progress),
              _C.primary.withValues(alpha: 0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)));

    // Line
    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(data[0].calories));
    for (int i = 1; i < data.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(data[i - 1].calories);
      final x1 = xOf(i), y1 = yOf(data[i].calories);
      final cpx = (x0 + x1) / 2;
      linePath.cubicTo(cpx, y0, cpx, y1, x1, y1);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = _C.primary
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Dots + x labels
    for (int i = 0; i < data.length; i++) {
      final x = xOf(i);
      final y = yOf(data[i].calories);
      final isOver = data[i].calories > goal;

      // Show only some x labels to avoid crowding
      final showLabel = data.length <= 7 || i % (data.length ~/ 6) == 0;
      if (showLabel) {
        final d = data[i].date;
        _drawLabel(canvas, '${d.month}/${d.day}',
            Offset(x - 12, chartH + 4),
            const TextStyle(fontSize: 9, color: _C.text3));
      }

      // Dot
      canvas.drawCircle(Offset(x, y), 4,
          Paint()..color = isOver ? _C.warning : _C.primary);
      canvas.drawCircle(Offset(x, y), 2.5,
          Paint()..color = Colors.white);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.progress != progress || old.data != data;
}

// BAR CHART PAINTER
class _BarChartPainter extends CustomPainter {
  final List<_DayData> data;
  final double goal;
  final double stepGoalCalories;
  final double progress;

  _BarChartPainter(
      {required this.data, required this.goal,
        required this.stepGoalCalories, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final displayData = data;

    const labelH = 20.0;
    const leftPad = 36.0;
    final chartH = size.height - labelH;
    final chartW = size.width - leftPad;

    final maxVal = math.max(
      math.max(
        displayData.map((d) => math.max(d.calories, d.burned)).reduce(math.max),
        goal * 1.1,
      ),
      stepGoalCalories * 1.1, // make sure step goal line is always visible
    );

    final groupW = chartW / displayData.length;
    const barPad = 2.0;
    final barW = ((groupW - barPad * 3) / 2).clamp(2.0, 20.0);

    // Calorie goal line — grey dashed
    final goalY = chartH - (goal / maxVal) * chartH * progress;
    final calDashPaint = Paint()
      ..color = _C.text3.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    double dx = leftPad;
    while (dx < size.width) {
      canvas.drawLine(Offset(dx, goalY), Offset(dx + 5, goalY), calDashPaint);
      dx += 9;
    }

    // Step goal burned line — steps color dashed
    final stepGoalY = chartH - (stepGoalCalories / maxVal) * chartH * progress;
    final stepDashPaint = Paint()
      ..color = _C.steps.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    double sx = leftPad;
    while (sx < size.width) {
      canvas.drawLine(
          Offset(sx, stepGoalY), Offset(sx + 6, stepGoalY), stepDashPaint);
      sx += 11;
    }

    // Step goal label on the right edge
    final stepLabelPainter = TextPainter(
      text: TextSpan(
        text: '${stepGoalCalories.toInt()}kcal',
        style: TextStyle(
          fontSize: 8,
          color: _C.steps.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stepLabelPainter.paint(
      canvas,
      Offset(size.width - stepLabelPainter.width - 2, stepGoalY - 11),
    );

    // Calorie goal label on the right edge
    final calLabelPainter = TextPainter(
      text: TextSpan(
        text: '${goal.toInt()}kcal',
        style: TextStyle(
          fontSize: 8,
          color: _C.text3.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    calLabelPainter.paint(
      canvas,
      Offset(size.width - calLabelPainter.width - 2, goalY - 11),
    );

    for (int i = 0; i < displayData.length; i++) {
      final d = displayData[i];
      final groupX = leftPad + i * groupW;

      final isOver = d.calories > goal;
      final intakeH = (d.calories / maxVal) * chartH * progress;
      final goalH = (goal / maxVal) * chartH * progress;

      if (isOver) {
        // Green portion up to goal
        final greenRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(groupX + barPad, chartH - goalH, barW, goalH),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        );
        canvas.drawRRect(greenRect,
            Paint()..color = _C.primary.withValues(alpha: 0.85));

        // Red overflow above goal
        final overflowH = intakeH - goalH;
        final redRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(groupX + barPad, chartH - intakeH, barW, overflowH),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(redRect,
            Paint()..color = _C.warning.withValues(alpha: 0.9));
      } else {
        final intakeRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(groupX + barPad, chartH - intakeH, barW, intakeH),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(intakeRect,
            Paint()..color = _C.primary.withValues(alpha: 0.85));
      }

      // Burned bar — highlight green if it meets the step goal
      final burnedH = (d.burned / maxVal) * chartH * progress;
      final metStepGoal = d.burned >= stepGoalCalories;
      final burnedRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
            groupX + barPad * 2 + barW, chartH - burnedH, barW, burnedH),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(
        burnedRect,
        Paint()
          ..color = metStepGoal
              ? _C.steps.withValues(alpha: 0.9)   // brighter when goal met
              : _C.burn.withValues(alpha: 0.75),  // normal orange otherwise
      );

      // X label
      final interval = displayData.length <= 7
          ? 1
          : displayData.length <= 14
          ? 2
          : 5;
      final show = i % interval == 0 || i == displayData.length - 1;
      if (show) {
        final tp = TextPainter(
          text: TextSpan(
              text: '${d.date.day}/${d.date.month}',
              style: const TextStyle(fontSize: 8, color: _C.text3)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(groupX + barPad, chartH + 4));
      }
    }

    // Y labels
    for (int i = 0; i <= 3; i++) {
      final y = chartH * (1 - i / 3);
      final val = (maxVal * i / 3).toInt();
      final tp = TextPainter(
        text: TextSpan(
            text: '$val',
            style: const TextStyle(fontSize: 8, color: _C.text3)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 6));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.progress != progress ||
          old.data != data ||
          old.stepGoalCalories != stepGoalCalories;
}

// PIE CHART PAINTER
class _PieChartPainter extends CustomPainter {
  final double protein, carbs, fat, progress;

  _PieChartPainter(
      {required this.protein,
        required this.carbs,
        required this.fat,
        required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final total = protein + carbs + fat;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeW = 18.0;
    const startAngle = -math.pi / 2;

    final segments = [
      (protein / total, _C.protein),
      (carbs / total, _C.carbs),
      (fat / total, _C.fat),
    ];

    // Background ring
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _C.divider
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW);

    double angle = startAngle;
    for (final seg in segments) {
      final sweep = seg.$1 * math.pi * 2 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        sweep,
        false,
        Paint()
          ..color = seg.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt,
      );
      angle += sweep;
    }

    // Center label
    final pPct = (protein / total * 100).toInt();
    _drawCenterText(canvas, center, '$pPct%', 'Protein');
  }

  void _drawCenterText(Canvas canvas, Offset center, String val, String label) {
    final valPainter = TextPainter(
      text: TextSpan(
          text: val,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.protein)),
      textDirection: TextDirection.ltr,
    )..layout();
    valPainter.paint(canvas,
        center - Offset(valPainter.width / 2, valPainter.height));

    final labelPainter = TextPainter(
      text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, color: _C.text3)),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas,
        center - Offset(labelPainter.width / 2, -2));
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => old.progress != progress;
}