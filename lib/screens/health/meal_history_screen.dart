import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/nutrition_model.dart';
import '../../controllers/nutrition_controller.dart';
import '../../theme/colors.dart';
import '../../services/local_db_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef _C = C;

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen>
    with SingleTickerProviderStateMixin {
  String? _editingLogId;
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _servingControllers = {};
  final Map<String, TextEditingController> _proteinControllers = {};
  final Map<String, TextEditingController> _carbsControllers = {};
  final Map<String, TextEditingController> _fatControllers = {};
  final Map<String, bool> _macroOverrideFlags = {};

  final SupabaseClient _client = Supabase.instance.client;
  late AnimationController _fadeAnim;

  DateTime _selectedDate = DateTime.now();
  List<NutritionLog> _logs = [];
  bool _isLoading = false;
  bool _isOffline = false;
  StreamSubscription? _connectivitySub;

  // Meal type config
  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealEmojis = {
    'breakfast': '🌅',
    'lunch': '☀️',
    'dinner': '🌙',
    'snack': '🍎',
  };
  static const _mealColors = {
    'breakfast': Color(0xFFFF9800),
    'lunch': Color(0xFF00A676),
    'dinner': Color(0xFF3B82F6),
    'snack': Color(0xFFEC4899),
  };

  @override
  void initState() {
    super.initState();
    _fadeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _loadLogs();
    _initConnectivity();
  }

  void _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => _isOffline = result.every((r) => r == ConnectivityResult.none));

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      setState(() => _isOffline = result.every((r) => r == ConnectivityResult.none));
      if (!_isOffline) _loadLogs();
    });
  }

  @override
  void dispose() {
    _fadeAnim.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  String get _userId => _client.auth.currentUser?.id ?? '';

  Future<void> _loadLogs() async {
    if (_userId.isEmpty) return;
    setState(() => _isLoading = true);
    _fadeAnim.reset();

    try {
      final startOfDay = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _client
          .from('nutrition_logs')
          .select()
          .eq('user_id', _userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .lt('logged_at', endOfDay.toIso8601String())
          .order('logged_at', ascending: true);

      final logs =
      (data as List).map((e) => NutritionLog.fromMap(e)).toList();

      for (final log in logs) {
        print('=== LOG: ${log.foodName} | path: ${log.imagePath} | url: ${log.imageUrl} ===');
      }

      await _saveCacheLocally(logs);

      setState(() {
        _logs = logs;
        _isLoading = false;
      });
      _fadeAnim.forward();
    } catch (e) {
      print('=== OFFLINE: loading from cache ===');
      final cached = await _loadCacheLocally();

      setState(() {
        _logs = cached;
        _isLoading = false;
      });
      _fadeAnim.forward();
    }
  }

  Future<void> _updateLog(
      NutritionLog log,
      String newName,
      double newServing, {
        double? overrideProtein,
        double? overrideCarbs,
        double? overrideFat,
      }) async {
    try {
      double newProtein;
      double newCarbs;
      double newFat;
      double newCalories;

      if (overrideProtein != null && overrideCarbs != null && overrideFat != null) {
        // User manually entered macros — use directly
        newProtein = overrideProtein;
        newCarbs = overrideCarbs;
        newFat = overrideFat;
      } else {
        // Scale macros proportionally by serving change
        final ratio = newServing / log.servingSize;
        newProtein = log.protein * ratio;
        newCarbs = log.carbs * ratio;
        newFat = log.fat * ratio;
      }

      // Always recalculate calories from macros: P×4 + C×4 + F×9
      newCalories = (newProtein * 4) + (newCarbs * 4) + (newFat * 9);

      await _client.from('nutrition_logs').update({
        'food_name': newName,
        'serving_size': newServing,
        'calories': newCalories,
        'protein': newProtein,
        'carbs': newCarbs,
        'fat': newFat,
      }).eq('id', log.id);

      Get.snackbar('Updated', '$newName updated.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: _C.primary,
          colorText: Colors.white);

      _editingLogId = null;
      _macroOverrideFlags.remove(log.id);
      _loadLogs();

      if (Get.isRegistered<NutritionController>()) {
        Get.find<NutritionController>().loadDashboard();
      }
    } catch (e) {
      Get.snackbar('❌ Error', 'Update failed: $e',
          snackPosition: SnackPosition.TOP);
    }
  }

  Future<void> _deleteLog(String logId) async {
    try {
      await _client.from('nutrition_logs').delete().eq('id', logId);
      setState(() => _logs.removeWhere((l) => l.id == logId));

      await _localDb.deleteNutritionLog(logId);

      if (Get.isRegistered<NutritionController>()) {
        Get.find<NutritionController>().loadDashboard();
      }

      Get.snackbar('🗑️ Deleted', 'Food item removed.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.shade400,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar('❌ Error', 'Delete failed: $e',
          snackPosition: SnackPosition.TOP);
    }
  }

  void _goToPreviousDay() {
    setState(() => _selectedDate =
        _selectedDate.subtract(const Duration(days: 1)));
    _loadLogs();
  }

  void _goToNextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_selectedDate.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
      setState(
              () => _selectedDate = _selectedDate.add(const Duration(days: 1)));
      _loadLogs();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _C.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadLogs();
    }
  }

  double get _totalCalories => _logs.fold(0.0, (s, l) => s + l.calories);
  double get _totalProtein => _logs.fold(0.0, (s, l) => s + l.protein);
  double get _totalCarbs => _logs.fold(0.0, (s, l) => s + l.carbs);
  double get _totalFat => _logs.fold(0.0, (s, l) => s + l.fat);

  Map<String, List<NutritionLog>> get _groupedLogs {
    final map = <String, List<NutritionLog>>{};
    for (final type in _mealOrder) {
      final items = _logs.where((l) => l.mealType == type).toList();
      if (items.isNotEmpty) map[type] = items;
    }
    return map;
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Today';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                _buildDateNavigator(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                        child: CircularProgressIndicator(color: _C.primary)),
                  )
                else if (_logs.isEmpty)
                  _buildEmptyState()
                else ...[
                    _buildDaySummaryCard(),
                    const SizedBox(height: 20),
                    ..._groupedLogs.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildMealSection(entry.key, entry.value),
                    )),
                  ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _C.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
        ),
      ),
      title: const Text(
        'Meal History',
        style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _C.text1,
            letterSpacing: -0.3),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF00A676)),
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadLogs();
          },
        ),
      ],
    );
  }

  Widget _buildDateNavigator() {
    final canGoForward = !_isToday;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          _navBtn(
              icon: Icons.chevron_left_rounded,
              onTap: _goToPreviousDay),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                children: [
                  Text(
                    _dateLabel,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _C.text1),
                  ),
                  if (!_isToday)
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(
                          fontSize: 11, color: _C.text3),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: _C.primary),
                      const SizedBox(width: 4),
                      Text('Tap to pick date',
                          style: TextStyle(
                              fontSize: 10,
                              color: _C.primary.withValues(alpha: 0.7))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _navBtn(
            icon: Icons.chevron_right_rounded,
            onTap: canGoForward ? _goToNextDay : null,
            disabled: !canGoForward,
          ),
        ],
      ),
    );
  }

  Widget _navBtn(
      {required IconData icon,
        required VoidCallback? onTap,
        bool disabled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.transparent
              : _C.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: disabled ? _C.text3 : _C.primary, size: 22),
      ),
    );
  }

  Widget _buildDaySummaryCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF007A57), Color(0xFF00A676)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: _C.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daily Total',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_logs.length} item${_logs.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_totalCalories.toStringAsFixed(1)} kcal',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _summaryMacro('Protein', _totalProtein, _C.protein),
                _summaryMacro('Carbs', _totalCarbs, _C.carbs),
                _summaryMacro('Fat', _totalFat, _C.fat),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMacro(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${value.toStringAsFixed(1)}g',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ],
      ).paddingSymmetric(horizontal: 4),
    );
  }

  Widget _buildMealSection(String mealType, List<NutritionLog> logs) {
    final color = _mealColors[mealType] ?? _C.primary;
    final emoji = _mealEmojis[mealType] ?? '🍽️';
    final totalCal = logs.fold(0.0, (s, l) => s + l.calories);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11)),
                    child:
                    Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealType.capitalizeFirst ?? mealType,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.text1),
                      ),
                      Text(
                        '${logs.length} item${logs.length == 1 ? '' : 's'}',
                        style:
                        const TextStyle(fontSize: 11, color: _C.text3),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${totalCal.toStringAsFixed(1)} kcal',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            ...logs.map((log) => _buildFoodItem(log, color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem(NutritionLog log, Color mealColor) {
    final isEditing = _editingLogId == log.id;

    // Init all controllers
    _nameControllers.putIfAbsent(log.id, () => TextEditingController(text: log.foodName));
    _servingControllers.putIfAbsent(log.id, () => TextEditingController(text: log.servingSize.toInt().toString()));
    _proteinControllers.putIfAbsent(log.id, () => TextEditingController(text: log.protein.toStringAsFixed(1)));
    _carbsControllers.putIfAbsent(log.id, () => TextEditingController(text: log.carbs.toStringAsFixed(1)));
    _fatControllers.putIfAbsent(log.id, () => TextEditingController(text: log.fat.toStringAsFixed(1)));
    _macroOverrideFlags.putIfAbsent(log.id, () => false);

    return Dismissible(
      key: Key('${log.id}_${log.foodName}_${log.loggedAt.millisecondsSinceEpoch}'),
      direction: _isOffline ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (_isOffline) { _showOfflineMessage(); return false; }
        HapticFeedback.mediumImpact();
        return await _showDeleteConfirm(log.foodName);
      },
      onDismissed: (_) => _deleteLog(log.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: const BoxDecoration(color: Color(0xFFFFEBEE)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          ],
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          border: isEditing
              ? Border(top: BorderSide(color: _C.primary.withValues(alpha: 0.15)))
              : const Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showImageDialog(log),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: mealColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: () {
                        final hasLocalImage = log.imagePath != null && File(log.imagePath!).existsSync();
                        final hasRemoteImage = log.imageUrl != null && log.imageUrl!.isNotEmpty;
                        return hasLocalImage
                            ? Image.file(File(log.imagePath!), fit: BoxFit.cover)
                            : hasRemoteImage
                            ? Image.network(
                          log.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => Icon(
                            Icons.restaurant_rounded,
                            color: mealColor.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        )
                            : Icon(
                          Icons.restaurant_rounded,
                          color: mealColor.withValues(alpha: 0.7),
                          size: 20,
                        );
                      }(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.foodName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: _C.text1),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${log.servingSize.toInt()}g  ·  P: ${log.protein.toStringAsFixed(1)}g  C: ${log.carbs.toStringAsFixed(1)}g  F: ${log.fat.toStringAsFixed(1)}g',
                          style: const TextStyle(fontSize: 11, color: _C.text3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${log.calories.toStringAsFixed(1)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: _C.text1)),
                      const Text('kcal', style: TextStyle(fontSize: 10, color: _C.text3)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (_isOffline) { _showOfflineMessage(); return; }
                      HapticFeedback.lightImpact();
                      setState(() {
                        _editingLogId = isEditing ? null : log.id;
                        _nameControllers[log.id]?.text = log.foodName;
                        _servingControllers[log.id]?.text = log.servingSize.toInt().toString();
                        // Reset macro controllers to current log values
                        _proteinControllers[log.id]?.text = log.protein.toStringAsFixed(1);
                        _carbsControllers[log.id]?.text = log.carbs.toStringAsFixed(1);
                        _fatControllers[log.id]?.text = log.fat.toStringAsFixed(1);
                        _macroOverrideFlags[log.id] = false;
                      });
                    },
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _isOffline
                            ? _C.divider
                            : isEditing ? _C.primary.withValues(alpha: 0.15) : _C.bg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        isEditing ? Icons.close_rounded : Icons.edit_rounded,
                        color: _isOffline ? _C.text3 : isEditing ? _C.primary : _C.text3,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Inline edit panel ─────────────────────────────────────────
            if (isEditing) _buildEditPanel(log),
          ],
        ),
      ),
    );
  }

  Widget _buildEditPanel(NutritionLog log) {
    return StatefulBuilder(
      builder: (context, setLocal) {
        final overrideActive = _macroOverrideFlags[log.id] ?? false;

        // Live calorie preview from current field values
        double liveCalories() {
          final p = double.tryParse(_proteinControllers[log.id]?.text ?? '0') ?? 0;
          final c = double.tryParse(_carbsControllers[log.id]?.text ?? '0') ?? 0;
          final f = double.tryParse(_fatControllers[log.id]?.text ?? '0') ?? 0;
          return (p * 4) + (c * 4) + (f * 9);
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Food name ───────────────────────────────────────────────
              const Text('Food name',
                  style: TextStyle(fontSize: 12, color: _C.text2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameControllers[log.id],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.text1),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _C.primary.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Serving size ────────────────────────────────────────────
              const Text('Serving size (g)',
                  style: TextStyle(fontSize: 12, color: _C.text2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _historyServingBtn(
                    icon: Icons.remove_rounded,
                    enabled: !overrideActive,
                    onTap: () {
                      if (overrideActive) return;
                      final current = double.tryParse(_servingControllers[log.id]!.text) ?? log.servingSize;
                      final newVal = (current - 25).clamp(25.0, 9999.0);
                      _servingControllers[log.id]!.text = newVal.toInt().toString();
                      // Scale macros proportionally
                      final ratio = newVal / log.servingSize;
                      _proteinControllers[log.id]!.text = (log.protein * ratio).toStringAsFixed(1);
                      _carbsControllers[log.id]!.text = (log.carbs * ratio).toStringAsFixed(1);
                      _fatControllers[log.id]!.text = (log.fat * ratio).toStringAsFixed(1);
                      setLocal(() {});
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _servingControllers[log.id],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      enabled: !overrideActive,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        if (overrideActive) return;
                        final newServing = double.tryParse(v);
                        if (newServing != null && newServing > 0) {
                          final ratio = newServing / log.servingSize;
                          _proteinControllers[log.id]!.text = (log.protein * ratio).toStringAsFixed(1);
                          _carbsControllers[log.id]!.text = (log.carbs * ratio).toStringAsFixed(1);
                          _fatControllers[log.id]!.text = (log.fat * ratio).toStringAsFixed(1);
                          setLocal(() {});
                        }
                      },
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: overrideActive ? _C.text3 : _C.text1),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        filled: true,
                        fillColor: overrideActive ? _C.bg : Colors.white,
                        suffix: const Text('g', style: TextStyle(color: _C.text3)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _C.primary.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _C.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _historyServingBtn(
                    icon: Icons.add_rounded,
                    enabled: !overrideActive,
                    onTap: () {
                      if (overrideActive) return;
                      final current = double.tryParse(_servingControllers[log.id]!.text) ?? log.servingSize;
                      final newVal = current + 25;
                      _servingControllers[log.id]!.text = newVal.toInt().toString();
                      final ratio = newVal / log.servingSize;
                      _proteinControllers[log.id]!.text = (log.protein * ratio).toStringAsFixed(1);
                      _carbsControllers[log.id]!.text = (log.carbs * ratio).toStringAsFixed(1);
                      _fatControllers[log.id]!.text = (log.fat * ratio).toStringAsFixed(1);
                      setLocal(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Serving presets
              Row(
                children: [50, 100, 150, 200, 250].map((g) =>
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: GestureDetector(
                          onTap: overrideActive ? null : () {
                            _servingControllers[log.id]!.text = g.toString();
                            final ratio = g / log.servingSize;
                            _proteinControllers[log.id]!.text = (log.protein * ratio).toStringAsFixed(1);
                            _carbsControllers[log.id]!.text = (log.carbs * ratio).toStringAsFixed(1);
                            _fatControllers[log.id]!.text = (log.fat * ratio).toStringAsFixed(1);
                            setLocal(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: (!overrideActive && (double.tryParse(_servingControllers[log.id]!.text) ?? 0).toInt() == g)
                                  ? _C.primary
                                  : overrideActive ? _C.bg.withValues(alpha: 0.5) : _C.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('${g}g',
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: (!overrideActive && (double.tryParse(_servingControllers[log.id]!.text) ?? 0).toInt() == g)
                                      ? Colors.white
                                      : overrideActive ? _C.text3 : _C.text2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ).toList(),
              ),

              const SizedBox(height: 16),

              // ── Macro override toggle ───────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nutrition values',
                            style: TextStyle(fontSize: 12, color: _C.text2, fontWeight: FontWeight.w600)),
                        Text(
                          overrideActive
                              ? 'Editing manually — serving size locked'
                              : 'Auto-calculated from serving size',
                          style: TextStyle(
                              fontSize: 10,
                              color: overrideActive ? _C.primary : _C.text3),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setLocal(() {
                        _macroOverrideFlags[log.id] = !overrideActive;
                        if (!_macroOverrideFlags[log.id]!) {
                          // Switching back to serving mode: recalculate from current serving
                          final serving = double.tryParse(_servingControllers[log.id]?.text ?? '') ?? log.servingSize;
                          final ratio = serving / log.servingSize;
                          _proteinControllers[log.id]!.text = (log.protein * ratio).toStringAsFixed(1);
                          _carbsControllers[log.id]!.text = (log.carbs * ratio).toStringAsFixed(1);
                          _fatControllers[log.id]!.text = (log.fat * ratio).toStringAsFixed(1);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: overrideActive
                            ? _C.primary.withValues(alpha: 0.12)
                            : _C.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: overrideActive
                              ? _C.primary.withValues(alpha: 0.4)
                              : _C.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            overrideActive ? Icons.edit_rounded : Icons.lock_outline_rounded,
                            size: 12,
                            color: overrideActive ? _C.primary : _C.text3,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            overrideActive ? 'Manual' : 'Override',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: overrideActive ? _C.primary : _C.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── P / C / F input fields ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _historyMacroField(
                      label: 'Protein',
                      color: _C.protein,
                      controller: _proteinControllers[log.id]!,
                      enabled: overrideActive,
                      onChanged: (_) => setLocal(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _historyMacroField(
                      label: 'Carbs',
                      color: _C.carbs,
                      controller: _carbsControllers[log.id]!,
                      enabled: overrideActive,
                      onChanged: (_) => setLocal(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _historyMacroField(
                      label: 'Fat',
                      color: _C.fat,
                      controller: _fatControllers[log.id]!,
                      enabled: overrideActive,
                      onChanged: (_) => setLocal(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Live calories preview ───────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${liveCalories().toStringAsFixed(1)} kcal',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _C.text1),
                    ),
                    const Text(
                      'Auto-calculated  (P×4 + C×4 + F×9)',
                      style: TextStyle(fontSize: 10, color: _C.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Save button ─────────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  if (_isOffline) { _showOfflineMessage(); return; }
                  final newName = _nameControllers[log.id]!.text.trim();
                  final newServing = double.tryParse(_servingControllers[log.id]!.text) ?? log.servingSize;
                  if (newName.isEmpty) {
                    Get.snackbar('⚠️ Empty', 'Food name cannot be empty.',
                        snackPosition: SnackPosition.TOP);
                    return;
                  }

                  if (_macroOverrideFlags[log.id] == true) {
                    // Pass manual macro values
                    final p = double.tryParse(_proteinControllers[log.id]!.text) ?? log.protein;
                    final c = double.tryParse(_carbsControllers[log.id]!.text) ?? log.carbs;
                    final f = double.tryParse(_fatControllers[log.id]!.text) ?? log.fat;
                    _updateLog(log, newName, newServing,
                        overrideProtein: p, overrideCarbs: c, overrideFat: f);
                  } else {
                    _updateLog(log, newName, newServing);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.primary, Color(0xFF007A57)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: _C.primary.withValues(alpha: 0.35),
                      blurRadius: 8, offset: const Offset(0, 3),
                    )],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Save Changes',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helper: serving +/- button for history screen ──────────────────────────
  Widget _historyServingBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: enabled ? _C.primary.withValues(alpha: 0.1) : _C.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: enabled ? _C.primary : _C.text3, size: 18),
      ),
    );
  }

  // ── Helper: macro input field for history screen ───────────────────────────
  Widget _historyMacroField({
    required String label,
    required Color color,
    required TextEditingController controller,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: enabled ? color : _C.text3, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: enabled ? color : _C.text3,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : _C.bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.5) : _C.divider.withValues(alpha: 0.4),
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: onChanged,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: enabled ? _C.text1 : _C.text3),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffix: Text('g',
                  style: TextStyle(
                      fontSize: 11,
                      color: enabled ? color : _C.text3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: _C.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            _isToday ? 'No meals logged today' : 'No meals on this day',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _C.text1),
          ),
          const SizedBox(height: 8),
          Text(
            _isToday
                ? 'Tap "Add Meal" on the dashboard\nto log your first meal'
                : _isOffline
                ? 'No cached data for this date'
                : 'Nothing was logged on this date',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: _C.text2, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirm(String foodName) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Item',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Remove "$foodName" from your log?',
            style: const TextStyle(color: _C.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showImageDialog(NutritionLog log) {
    final hasLocalImage = log.imagePath != null && File(log.imagePath!).existsSync();
    final hasRemoteImage = log.imageUrl != null && log.imageUrl!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              hasLocalImage
                  ? Image.file(File(log.imagePath!), width: double.infinity, height: 260, fit: BoxFit.cover)
                  : hasRemoteImage
                  ? Image.network(
                log.imageUrl!, width: double.infinity, height: 260, fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(color: _C.primary)),
                errorBuilder: (ctx, _, __) => _noImagePlaceholder(),
              )
                  : _noImagePlaceholder(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.foodName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text1)),
                    const SizedBox(height: 4),
                    Text('${log.servingSize.toInt()}g  ·  ${log.calories.toStringAsFixed(1)} kcal',
                        style: const TextStyle(fontSize: 13, color: _C.text2)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _dialogMacro('Protein', '${log.protein.toStringAsFixed(1)}g', _C.protein),
                        _dialogMacro('Carbs', '${log.carbs.toStringAsFixed(1)}g', _C.carbs),
                        _dialogMacro('Fat', '${log.fat.toStringAsFixed(1)}g', _C.fat),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: double.infinity, height: 44,
                        decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Center(
                          child: Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogMacro(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: _C.text3)),
          ],
        ),
      ),
    );
  }

  final _localDb = LocalDbService();

  Future<void> _saveCacheLocally(List<NutritionLog> logs) async {
    await _localDb.clearNutritionLogsForDate(_userId, _selectedDate);
    if (logs.isNotEmpty) {
      await _localDb.cacheNutritionLogs(logs);
    }
  }

  Future<List<NutritionLog>> _loadCacheLocally() async {
    print('=== LOADING CACHE FOR DATE: $_selectedDate ===');
    print('=== USER ID: $_userId ===');
    final logs = await _localDb.getNutritionLogsForDate(_userId, _selectedDate);
    print('=== CACHE RETURNED: ${logs.length} logs ===');
    for (final log in logs) {
      print('=== CACHED LOG: ${log.foodName} | ${log.loggedAt} ===');
    }
    return logs;
  }

  Widget _noImagePlaceholder() {
    return Container(
      width: double.infinity, height: 180,
      decoration: const BoxDecoration(color: _C.bg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography_rounded, color: _C.text3, size: 48),
          const SizedBox(height: 12),
          const Text('No image captured', style: TextStyle(color: _C.text3, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'dec'
  ][m];

  void _showOfflineMessage() {
    Get.snackbar(
      '📵 You\'re Offline',
      'Connect to the internet to make changes.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade400,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}