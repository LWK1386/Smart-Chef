import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/nutrition_controller.dart';
import '../../models/nutrition_model.dart';
import '../../theme/colors.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef _C = C;

class DietaryPreferencesScreen extends StatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen>
    with SingleTickerProviderStateMixin {
  late final NutritionController _ctrl;
  late final AnimationController _entryAnim;

  // Local editable state
  double _calorieGoal = 2000;
  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isLowCarb = false;
  bool _isHighProtein = false;
  bool _isKeto = false;

  // Macro ratios (0.0 – 1.0), always sum to 1
  double _proteinRatio = 0.30; // 30%
  double _carbsRatio = 0.50;
  double _fatRatio = 0.20;

  final TextEditingController _calCtrl = TextEditingController();
  Worker? _autoSaveWorker;
  final RxInt _changeCounter = 0.obs;
  bool _isOffline = false;
  StreamSubscription? _connectivitySub;

  // Computed gram goals from ratios + calorie goal
  double get _proteinGoalG => (_calorieGoal * _proteinRatio / 4).roundToDouble();
  double get _carbsGoalG   => (_calorieGoal * _carbsRatio   / 4).roundToDouble();
  double get _fatGoalG     => (_calorieGoal * _fatRatio     / 9).roundToDouble();

  int _stepGoal = 10000;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<NutritionController>();
    _entryAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _loadFromController();
    Connectivity().checkConnectivity().then((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
    _autoSaveWorker = debounce(
      _changeCounter,
          (_) => _autoSave(),
      time: const Duration(milliseconds: 800),
    );
  }

  void _triggerSave() {
    if (_isOffline) { _showOfflineMessage(); return; }
    _changeCounter.value++;
  }

  Future<void> _autoSave() async {
    final parsed = double.tryParse(_calCtrl.text);
    if (parsed == null || parsed < 500 || parsed > 10000) return;

    final newGoals = UserGoals(
      userId:       _ctrl.userId,
      calorieGoal:  parsed,
      proteinGoal:  _proteinGoalG,
      carbsGoal:    _carbsGoalG,
      fatGoal:      _fatGoalG,
      waterGoal:    _ctrl.goals.value?.waterGoal ?? 8,
      isVegetarian: _isVegetarian,
      isVegan:      _isVegan,
      isLowCarb:    _isLowCarb,
      isHighProtein: _isHighProtein,
      isKeto:       _isKeto,
      stepGoal: _stepGoal,
    );
    await _ctrl.saveGoals(newGoals);
    // Subtle confirmation — no snackbar spam
    HapticFeedback.lightImpact();
  }

  void _loadFromController() {
    final g = _ctrl.goals.value;
    if (g == null) return;
    _calorieGoal    = g.calorieGoal;
    _isVegetarian   = g.isVegetarian;
    _isVegan        = g.isVegan;
    _isLowCarb      = g.isLowCarb;
    _isHighProtein  = g.isHighProtein;
    _isKeto         = g.isKeto;
    _calCtrl.text   = g.calorieGoal.toInt().toString();
    _stepGoal = _ctrl.goals.value?.stepGoal ?? 10000;

    // Derive ratios from saved gram goals
    final totalCal = g.proteinGoal * 4 + g.carbsGoal * 4 + g.fatGoal * 9;
    if (totalCal > 0) {
      _proteinRatio = (g.proteinGoal * 4) / totalCal;
      _carbsRatio   = (g.carbsGoal   * 4) / totalCal;
      _fatRatio     = (g.fatGoal     * 9) / totalCal;
    }
  }

  @override
  void dispose() {
    _autoSaveWorker?.dispose();
    _entryAnim.dispose();
    _calCtrl.dispose();
    super.dispose();
    _connectivitySub?.cancel();
  }

  // ── Diet preset logic ─────────────────────────────────────────────────────────
  void _applyPreset(String preset) {
    HapticFeedback.selectionClick();
    setState(() {
      // Reset all
      _isVegetarian = _isVegan = _isLowCarb = _isHighProtein = _isKeto = false;
      switch (preset) {
        case 'vegetarian':
          _isVegetarian = true;
          _proteinRatio = 0.20; _carbsRatio = 0.55; _fatRatio = 0.25;
          break;
        case 'vegan':
          _isVegan = true; _isVegetarian = true;
          _proteinRatio = 0.15; _carbsRatio = 0.60; _fatRatio = 0.25;
          break;
        case 'lowcarb':
          _isLowCarb = true;
          _proteinRatio = 0.30; _carbsRatio = 0.20; _fatRatio = 0.50;
          break;
        case 'highprotein':
          _isHighProtein = true;
          _proteinRatio = 0.40; _carbsRatio = 0.40; _fatRatio = 0.20;
          break;
        case 'keto':
          _isKeto = true; _isLowCarb = true;
          _proteinRatio = 0.20; _carbsRatio = 0.05; _fatRatio = 0.75;
          break;
      }
    });
    _triggerSave();
  }

  void _toggleDiet(String diet, bool val) {
    HapticFeedback.lightImpact();
    setState(() {
      switch (diet) {
        case 'vegetarian': _isVegetarian = val; break;
        case 'vegan':
          _isVegan = val;
          if (val) _isVegetarian = true;
          break;
        case 'lowcarb': _isLowCarb = val; break;
        case 'highprotein': _isHighProtein = val; break;
        case 'keto':
          _isKeto = val;
          if (val) _isLowCarb = true;
          break;
      }
    });
    _triggerSave();
  }

  // Keep ratios summing to 1 when slider changes
  void _onProteinChanged(double v) {
    final remaining = 1.0 - v;
    final ratio = _carbsRatio / (_carbsRatio + _fatRatio);
    setState(() {
      _proteinRatio = v;
      _carbsRatio   = remaining * ratio;
      _fatRatio     = remaining * (1 - ratio);
    });
    _triggerSave();
  }

  void _onCarbsChanged(double v) {
    final remaining = 1.0 - v;
    final ratio = _proteinRatio / (_proteinRatio + _fatRatio);
    setState(() {
      _carbsRatio   = v;
      _proteinRatio = remaining * ratio;
      _fatRatio     = remaining * (1 - ratio);
    });
    _triggerSave();
  }

  void _onFatChanged(double v) {
    final remaining = 1.0 - v;
    final ratio = _proteinRatio / (_proteinRatio + _carbsRatio);
    setState(() {
      _fatRatio     = v;
      _proteinRatio = remaining * ratio;
      _carbsRatio   = remaining * (1 - ratio);
    });
    _triggerSave();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _buildCalorieCard(),
                const SizedBox(height: 16),
                _buildStepGoalCard(),
                const SizedBox(height: 16),
                _buildDietTypesCard(),
                const SizedBox(height: 16),
                _buildMacroSlidersCard(),
                const SizedBox(height: 16),
                _buildMacroSummaryCard(),
              ],
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
        left: 16, right: 16, bottom: 14,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Goals',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: _C.text1, letterSpacing: -0.3)),
                Text(
                  _isOffline ? '📵 Offline — changes disabled' : 'Personalise your goals',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOffline ? Colors.orange : _C.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Calorie Goal ──────────────────────────────────────────────────────────────
  Widget _buildCalorieCard() {
    return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
      opacity: _isOffline ? 0.5 : 1.0,
      child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Daily Calorie Goal', 'kcal / day'),
          const SizedBox(height: 16),
          Row(
            children: [
              // Minus
              _stepBtn(Icons.remove_rounded, () {
                final v = (double.tryParse(_calCtrl.text) ?? _calorieGoal) - 50;
                final clamped = v.clamp(500.0, 10000.0);
                _calCtrl.text = clamped.toInt().toString();
                setState(() => _calorieGoal = clamped);
                _triggerSave();
              }),
              const SizedBox(width: 12),
              // Input
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: TextField(
                          controller: _calCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800,
                              color: _C.text1),
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null) setState(() => _calorieGoal = parsed);
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none, isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const Text(' kcal',
                          style: TextStyle(fontSize: 14, color: _C.text3,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Plus
              _stepBtn(Icons.add_rounded, () {
                final v = (double.tryParse(_calCtrl.text) ?? _calorieGoal) + 50;
                final clamped = v.clamp(500.0, 10000.0);
                _calCtrl.text = clamped.toInt().toString();
                setState(() => _calorieGoal = clamped);
                _triggerSave();
              }),
            ],
          ),
          const SizedBox(height: 14),
          // Quick presets
          Row(
            children: [1500, 1800, 2000, 2200, 2500].map((kcal) =>
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _calCtrl.text = kcal.toString();
                        setState(() => _calorieGoal = kcal.toDouble());
                        _triggerSave();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _calorieGoal.toInt() == kcal
                              ? _C.primary : _C.bg,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: _calorieGoal.toInt() == kcal
                                ? _C.primary : _C.divider,
                          ),
                        ),
                        child: Center(
                          child: Text('$kcal',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _calorieGoal.toInt() == kcal
                                      ? Colors.white : _C.text2)),
                        ),
                      ),
                    ),
                  ),
                ),
            ).toList(),
          ),
        ],
      ),
      ),
    );
  }

  // ── Diet Types ────────────────────────────────────────────────────────────────
  Widget _buildDietTypesCard() {
    final diets = [
      ('vegetarian', '🥦', 'Vegetarian', 'No meat or fish', _isVegetarian,
      const Color(0xFF10B981)),
      ('vegan', '🌱', 'Vegan', 'No animal products', _isVegan,
      const Color(0xFF34D399)),
      ('lowcarb', '🥑', 'Low Carb', 'Under 100g carbs/day', _isLowCarb,
      const Color(0xFFF59E0B)),
      ('highprotein', '💪', 'High Protein', 'Over 30% protein', _isHighProtein,
      const Color(0xFF3B82F6)),
      ('keto', '🔥', 'Keto', 'Under 5% carbs', _isKeto,
      const Color(0xFFEC4899)),
    ];

    return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
      opacity: _isOffline ? 0.5 : 1.0,
      child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Diet Type', 'Tap to apply preset'),
          const SizedBox(height: 14),
          ...diets.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _dietTile(
              key: d.$1, emoji: d.$2, title: d.$3,
              subtitle: d.$4, isOn: d.$5, color: d.$6,
            ),
          )),
        ],
      ),
      ),
    );
  }

  Widget _dietTile({
    required String key,
    required String emoji,
    required String title,
    required String subtitle,
    required bool isOn,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => isOn ? _toggleDiet(key, false) : _applyPreset(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isOn ? color.withValues(alpha: 0.08) : _C.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn ? color.withValues(alpha: 0.4) : _C.divider,
            width: isOn ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isOn ? color.withValues(alpha: 0.15) : _C.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji,
                  style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: isOn ? color : _C.text1)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: _C.text3)),
                ],
              ),
            ),
            if (isOn)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Active',
                    style: TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: isOn,
              onChanged: (v) => v ? _applyPreset(key) : _toggleDiet(key, false),
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // ── Macro Sliders ─────────────────────────────────────────────────────────────
  Widget _buildMacroSlidersCard() {
    return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
      opacity: _isOffline ? 0.5 : 1.0,
      child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Macro Ratios', 'Must total 100%'),
          const SizedBox(height: 6),
          // Live total indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total: ${((_proteinRatio + _carbsRatio + _fatRatio) * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, color: _C.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _macroSlider('🥩 Protein', _proteinRatio, _C.protein, _onProteinChanged),
          const SizedBox(height: 18),
          _macroSlider('🌾 Carbs', _carbsRatio, _C.carbs, _onCarbsChanged),
          const SizedBox(height: 18),
          _macroSlider('🫒 Fat', _fatRatio, _C.fat, _onFatChanged),
        ],
      ),
      ),
    );
  }

  Widget _macroSlider(
      String label, double ratio, Color color, ValueChanged<double> onChange) {
    final pct = (ratio * 100).toInt();
    final grams = label.contains('Protein')
        ? _proteinGoalG
        : label.contains('Carbs')
        ? _carbsGoalG
        : _fatGoalG;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _C.text1)),
            Row(
              children: [
                // Percentage badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$pct%',
                      style: const TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                // Gram goal badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${grams.toInt()}g',
                      style: TextStyle(color: color, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.12),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: ratio.clamp(0.05, 0.80),
            min: 0.05,
            max: 0.80,
            onChanged: onChange,
          ),
        ),
      ],
    );
  }

  // ── Macro Summary Card ────────────────────────────────────────────────────────
  Widget _buildMacroSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: _C.dark.withValues(alpha: 0.4),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              const Text('Your Daily Targets',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_calorieGoal.toInt()} kcal',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _targetChip('Protein', '${_proteinGoalG.toInt()}g',
                  '${(_proteinRatio * 100).toInt()}%', _C.protein),
              const SizedBox(width: 10),
              _targetChip('Carbs', '${_carbsGoalG.toInt()}g',
                  '${(_carbsRatio * 100).toInt()}%', _C.carbs),
              const SizedBox(width: 10),
              _targetChip('Fat', '${_fatGoalG.toInt()}g',
                  '${(_fatRatio * 100).toInt()}%', _C.fat),
            ],
          ),
          const SizedBox(height: 14),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Flexible(
                  flex: (_proteinRatio * 100).toInt(),
                  child: Container(height: 10, color: _C.protein),
                ),
                Flexible(
                  flex: (_carbsRatio * 100).toInt(),
                  child: Container(height: 10, color: _C.carbs),
                ),
                Flexible(
                  flex: (_fatRatio * 100).toInt(),
                  child: Container(height: 10, color: _C.fat),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetChip(
      String label, String grams, String pct, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(grams,
                style: TextStyle(color: color,
                    fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text(pct,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 14, offset: const Offset(0, 4),
        )],
      ),
      child: child,
    );
  }

  Widget _cardHeader(String title, String sub) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _C.text1)),
            Text(sub,
                style: const TextStyle(fontSize: 11, color: _C.text3)),
          ],
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: _C.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _C.primary, size: 22),
      ),
    );
  }

  Widget _buildStepGoalCard() {
    return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
      opacity: _isOffline ? 0.5 : 1.0,
      child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Daily Step Goal', 'steps / day'),
          const SizedBox(height: 16),
          Row(
            children: [
              _stepBtn(Icons.remove_rounded, () {
                final newVal = (_stepGoal - 500).clamp(1000, 50000);
                setState(() => _stepGoal = newVal);
                _triggerSave();
              }),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.steps.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      _stepGoal.toString(),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: _C.text1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _stepBtn(Icons.add_rounded, () {
                final newVal = (_stepGoal + 500).clamp(1000, 50000);
                setState(() => _stepGoal = newVal);
                _triggerSave();
              }),
            ],
          ),
          const SizedBox(height: 14),
          // Quick presets
          Row(
            children: [5000, 7500, 10000, 12500, 15000].map((s) =>
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _stepGoal = s);
                        _triggerSave();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _stepGoal == s ? _C.steps : _C.bg,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: _stepGoal == s ? _C.steps : _C.divider,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            s >= 1000 ? '${s ~/ 1000}k' : '$s',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: _stepGoal == s ? Colors.white : _C.text2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ).toList(),
          ),
        ],
      ),
      ),
    );
  }

  void _showOfflineMessage() {
    Get.snackbar(
      '📵 You\'re Offline',
      'Connect to change your preferences.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade400,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}