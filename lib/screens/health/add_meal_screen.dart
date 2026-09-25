import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/add_meal_controller.dart';
import '../../models/nutrition_model.dart';
import '../../models/food_item_model.dart';
import '../../theme/colors.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef _C = C;

class AddMealScreen extends StatefulWidget {
  /// Pass an existing log to enter Edit mode
  final NutritionLog? editLog;

  const AddMealScreen({super.key, this.editLog});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen>
    with SingleTickerProviderStateMixin {
  late final AddMealController _ctrl;
  late final AnimationController _slideAnim;
  final FocusNode _searchFocus = FocusNode();

  final Map<String, TextEditingController> _servingControllers = {};
  final Map<String, TextEditingController> _proteinControllers = {};
  final Map<String, TextEditingController> _carbsControllers = {};
  final Map<String, TextEditingController> _fatControllers = {};
  final Map<String, RxBool> _macroOverrideFlags = {};

  bool get _isEditMode => widget.editLog != null;
  bool _isOffline = false;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(AddMealController());

    if (_isEditMode) {
      _ctrl.initEditMode(widget.editLog!);
    }

    _slideAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    Connectivity().checkConnectivity().then((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) =>
        setState(() => _isOffline = r.every((c) => c == ConnectivityResult.none)));
  }

  @override
  void dispose() {
    _slideAnim.dispose();
    _searchFocus.dispose();
    // Only delete if not being reused
    Get.delete<AddMealController>();
    super.dispose();
    _connectivitySub?.cancel();

    for (final c in _servingControllers.values) {
      c.dispose();
    }
    for (final c in _proteinControllers.values) {
      c.dispose();
    }
    for (final c in _carbsControllers.values) {
      c.dispose();
    }
    for (final c in _fatControllers.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildMealTypeSelector(),
          const SizedBox(height: 4),
          _buildSearchBar(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
          _buildBottomSummary(),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _C.card,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Get.back(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Edit Food Item' : 'Add Meal',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _C.text1,
                    letterSpacing: -0.3,
                  ),
                ),
                Obx(() => Text(
                  _ctrl.selectedMealType.value.capitalizeFirst ?? '',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _C.primary,
                      fontWeight: FontWeight.w600),
                )),
              ],
            ),
          ),
          // Food scanner button
          Obx(() => GestureDetector(
            onTap: _ctrl.isScanning.value ? null : () {
              if (_isOffline) {
                Get.snackbar('📵 You\'re Offline',
                    'Connect to use the food scanner.',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.orange.shade400,
                    colorText: Colors.white);
                return;
              }
              _ctrl.scanBarcode();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (_ctrl.isScanning.value || _isOffline)
                    ? _C.primary.withValues(alpha: 0.1)
                    : _C.primary,
                borderRadius: BorderRadius.circular(13),
                boxShadow: _ctrl.isScanning.value
                    ? null
                    : [
                  BoxShadow(
                    color: _C.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: _ctrl.isScanning.value
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _C.primary),
              )
                  : const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 22),
            ),
          )),
        ],
      ),
    );
  }

  // ── Meal Type Selector ──────────────────────────────────────────────────────
  Widget _buildMealTypeSelector() {
    const types = [
      ('breakfast', '🌅', 'Breakfast'),
      ('lunch', '☀️', 'Lunch'),
      ('dinner', '🌙', 'Dinner'),
      ('snack', '🍎', 'Snack'),
    ];

    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: types.map((t) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Obx(() {
                final active = _ctrl.selectedMealType.value == t.$1;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _ctrl.selectMealType(t.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? _C.primary : _C.bg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: active
                          ? [
                        BoxShadow(
                          color: _C.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(t.$2,
                            style: TextStyle(
                                fontSize: active ? 18 : 16)),
                        const SizedBox(height: 2),
                        Text(
                          t.$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : _C.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _isOffline ? _C.divider.withValues(alpha: 0.5) : _C.divider),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Obx(() => _ctrl.isSearching.value
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.primary),
                  )
                      : const Icon(Icons.search_rounded,
                      color: _C.text3, size: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl.searchController,
                      focusNode: _searchFocus,
                      onSubmitted: (_) {
                        if (_isOffline) return;
                        _searchFocus.unfocus();
                        _ctrl.triggerSearch();
                      },
                      textInputAction: TextInputAction.search,
                      onChanged: (val) {
                        if (_isOffline) {
                          Get.snackbar('📵 You\'re Offline',
                              'Connect to search for food.',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: Colors.orange.shade400,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 2));
                          _ctrl.clearSearch();
                          return;
                        }
                        if (val.isEmpty) _ctrl.clearSearch();
                      },
                      style: const TextStyle(
                          fontSize: 14,
                          color: _C.text1,
                          fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: _isOffline ? '📵 Offline — search unavailable' : 'Search food, e.g. "chicken breast"',
                        hintStyle:
                        TextStyle(fontSize: 13, color: _C.text3),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _ctrl.searchController,
                      builder: (_, value, __) => value.text.isNotEmpty
                      ? GestureDetector(
                    onTap: _ctrl.clearSearch,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded,
                          color: _C.text3, size: 16),
                    ),
                  )
                      : const SizedBox.shrink()),
                  ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _ctrl.searchController,
                      builder: (_, value, __) => value.text.isNotEmpty
                      ? GestureDetector(
                    onTap: () {
                      _searchFocus.unfocus();
                      _ctrl.triggerSearch();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _C.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body — search results or cart ───────────────────────────────────────────
  Widget _buildBody() {
    return Obx(() {
      // Show search results when user is typing
      if (_ctrl.searchQuery.value.isNotEmpty) {
        return _buildSearchResults();
      }
      // Show cart (added items) otherwise
      return _buildCart();
    });
  }

  // ── Search Results ──────────────────────────────────────────────────────────
  Widget _buildSearchResults() {
    return Obx(() {
      if (_ctrl.isSearching.value && _ctrl.searchResults.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: _C.primary),
        );
      }

      if (_ctrl.searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'No results for "${_ctrl.searchQuery.value}"',
                style: const TextStyle(
                    color: _C.text2,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              const Text('Try a simpler search term\ne.g. "chicken" instead of "chicken chop"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _C.text3, fontSize: 12)),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _ctrl.searchResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) =>
            _buildFoodResultTile(_ctrl.searchResults[i]),
      );
    });
  }

  Widget _buildFoodResultTile(FoodItem food) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _ctrl.addToCart(food);
        _searchFocus.unfocus();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Food emoji avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _foodEmoji(food.name),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + brand
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.text1)),
                  if (food.brand.isNotEmpty)
                    Text(food.brand,
                        style: const TextStyle(
                            fontSize: 11, color: _C.text3)),
                  const SizedBox(height: 4),
                  // Macro chips row
                  Row(
                    children: [
                      _miniChip(
                          'P: ${food.proteinPer100g.toStringAsFixed(1)}g',
                          _C.protein),
                      const SizedBox(width: 4),
                      _miniChip(
                          'C: ${food.carbsPer100g.toStringAsFixed(1)}g',
                          _C.carbs),
                      const SizedBox(width: 4),
                      _miniChip(
                          'F: ${food.fatPer100g.toStringAsFixed(1)}g',
                          _C.fat),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  food.calculatedCaloriesPer100g.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _C.text1),
                ),
                const Text('kcal/100g',
                    style: TextStyle(fontSize: 9, color: _C.text3)),
                const SizedBox(height: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Cart ────────────────────────────────────────────────────────────────────
  Widget _buildCart() {
    return Obx(() {
      if (_ctrl.cartItems.isEmpty) {
        return _buildEmptyCart();
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _ctrl.cartItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildCartItem(_ctrl.cartItems[i]),
      );
    });
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('🍽️', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 16),
          const Text(
            'No food added yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.text1),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search for food above or scan the food',
            style: TextStyle(fontSize: 13, color: _C.text2),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(MealCartItem item) {
    return Obx(() => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isEditing.value
              ? _C.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Food avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _C.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: item.imagePath != null && File(item.imagePath!).existsSync()
                      ? Image.file(
                    File(item.imagePath!),
                    fit: BoxFit.cover,
                  )
                      : Center(
                    child: Text(
                      _foodEmoji(item.food.name),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() => item.isEditing.value
                          ? TextField(
                        controller: TextEditingController(text: item.foodName.value)
                          ..selection = TextSelection.collapsed(offset: item.foodName.value.length),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _C.text1),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _C.primary.withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _C.primary),
                          ),
                        ),
                        onChanged: (val) => item.foodName.value = val,
                      )
                          : Text(
                        item.foodName.value,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _C.text1),
                      ),
                      ),
                      const SizedBox(height: 3),
                      Obx(() => Text(
                        '${item.servingGrams.toInt()}g  ·  ${item.calories.toStringAsFixed(1)} kcal',
                        style: const TextStyle(
                            fontSize: 12, color: _C.text2),
                      )),
                      const SizedBox(height: 5),
                      Obx(() => Row(
                        children: [
                          _macroMini('P',
                              item.protein.toStringAsFixed(1),
                              _C.protein),
                          const SizedBox(width: 6),
                          _macroMini('C',
                              item.carbs.toStringAsFixed(1),
                              _C.carbs),
                          const SizedBox(width: 6),
                          _macroMini(
                              'F',
                              item.fat.toStringAsFixed(1),
                              _C.fat),
                        ],
                      )),
                    ],
                  ),
                ),
                // Edit + Delete icons
                Column(
                  children: [
                    _iconBtn(
                      icon: Icons.edit_rounded,
                      color: _C.primary,
                      bg: _C.primary.withValues(alpha: 0.1),
                      onTap: () => _ctrl.toggleEditing(item.cartId),
                    ),
                    const SizedBox(height: 6),
                    _iconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: _C.errorRed,
                      bg: _C.errorRed.withValues(alpha: 0.08),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _ctrl.removeFromCart(item.cartId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Expandable serving editor
          if (item.isEditing.value) _buildServingEditor(item),
        ],
      ),
    ));
  }

  Widget _buildServingEditor(MealCartItem item) {
    _servingControllers.putIfAbsent(item.cartId, () => TextEditingController(text: item.servingGrams.value.toInt().toString()));
    _proteinControllers.putIfAbsent(item.cartId, () => TextEditingController(text: item.protein.toStringAsFixed(1)));
    _carbsControllers.putIfAbsent(item.cartId,   () => TextEditingController(text: item.carbs.toStringAsFixed(1)));
    _fatControllers.putIfAbsent(item.cartId,     () => TextEditingController(text: item.fat.toStringAsFixed(1)));
    _macroOverrideFlags.putIfAbsent(item.cartId, () => false.obs);

    final servingController = _servingControllers[item.cartId]!;
    final proteinController = _proteinControllers[item.cartId]!;
    final carbsController   = _carbsControllers[item.cartId]!;
    final fatController     = _fatControllers[item.cartId]!;
    final macroOverride     = _macroOverrideFlags[item.cartId]!;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: _C.divider, height: 16),

          // ── Serving size section ──────────────────────────────────────────
          const Text('Serving size (grams)',
              style: TextStyle(
                  fontSize: 12,
                  color: _C.text2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              // Minus
              _servingBtn(
                icon: Icons.remove_rounded,
                onTap: () {
                  if (macroOverride.value) return; // lock serving if macros overridden
                  final newVal =
                  (item.servingGrams.value - 25).clamp(25.0, 9999.0);
                  _ctrl.updateServing(item.cartId, newVal);
                  servingController.text = newVal.toInt().toString();
                  // Sync macro controllers to new calculated values
                  proteinController.text = item.protein.toStringAsFixed(1);
                  carbsController.text = item.carbs.toStringAsFixed(1);
                  fatController.text = item.fat.toStringAsFixed(1);
                },
              ),
              const SizedBox(width: 10),
              // Text input
              Expanded(
                child: Obx(() => Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: macroOverride.value ? _C.bg.withValues(alpha: 0.5) : _C.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: macroOverride.value
                        ? _C.divider.withValues(alpha: 0.4)
                        : _C.primary.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: servingController,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: TextInputType.number,
                    enabled: !macroOverride.value,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    onSubmitted: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        _ctrl.updateServing(item.cartId, parsed);
                        proteinController.text = item.protein.toStringAsFixed(1);
                        carbsController.text = item.carbs.toStringAsFixed(1);
                        fatController.text = item.fat.toStringAsFixed(1);
                      }
                    },
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: macroOverride.value ? _C.text3 : _C.text1),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                      EdgeInsets.symmetric(vertical: 7),
                      suffix: Padding(
                        padding: EdgeInsets.only(right: 15),
                        child: Text(
                          'g',
                          style: TextStyle(fontSize: 13, color: _C.text3),
                        ),
                      ),
                    ),
                  ),
                )),
              ),
              const SizedBox(width: 10),
              // Plus
              _servingBtn(
                icon: Icons.add_rounded,
                onTap: () {
                  if (macroOverride.value) return;
                  final newVal = (item.servingGrams.value + 25).toDouble();
                  _ctrl.updateServing(item.cartId, newVal);
                  servingController.text = newVal.toInt().toString();
                  proteinController.text = item.protein.toStringAsFixed(1);
                  carbsController.text = item.carbs.toStringAsFixed(1);
                  fatController.text = item.fat.toStringAsFixed(1);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick presets
          Obx(() => Row(
            children: [50, 100, 150, 200, 250]
                .map((g) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: macroOverride.value ? null : () {
                    _ctrl.updateServing(item.cartId, g.toDouble());
                    servingController.text = g.toString();
                    proteinController.text = item.protein.toStringAsFixed(1);
                    carbsController.text = item.carbs.toStringAsFixed(1);
                    fatController.text = item.fat.toStringAsFixed(1);
                  },
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: (!macroOverride.value && item.servingGrams.value.toInt() == g)
                          ? _C.primary
                          : macroOverride.value ? _C.bg.withValues(alpha: 0.5) : _C.bg,
                      borderRadius:
                      BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${g}g',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (!macroOverride.value && item.servingGrams.value.toInt() == g)
                              ? Colors.white
                              : macroOverride.value ? _C.text3 : _C.text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ))
                .toList(),
          )),

          const SizedBox(height: 16),

          // ── Macro override section ────────────────────────────────────────
          Obx(() => Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nutrition values',
                        style: TextStyle(
                            fontSize: 12,
                            color: _C.text2,
                            fontWeight: FontWeight.w600)),
                    Text(
                      macroOverride.value
                          ? 'Editing manually — serving size locked'
                          : 'Auto-calculated from serving size',
                      style: TextStyle(
                          fontSize: 10,
                          color: macroOverride.value ? _C.primary : _C.text3),
                    ),
                  ],
                ),
              ),
              // Toggle switch
              GestureDetector(
                onTap: () {
                  macroOverride.value = !macroOverride.value;
                  if (!macroOverride.value) {
                    // Switching back to serving mode: clear override so
                    // macros go back to being calculated from servingGrams
                    _ctrl.clearMacroOverride(item.cartId);
                    proteinController.text = item.protein.toStringAsFixed(1);
                    carbsController.text = item.carbs.toStringAsFixed(1);
                    fatController.text = item.fat.toStringAsFixed(1);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: macroOverride.value
                        ? _C.primary.withValues(alpha: 0.12)
                        : _C.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: macroOverride.value
                          ? _C.primary.withValues(alpha: 0.4)
                          : _C.divider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        macroOverride.value
                            ? Icons.edit_rounded
                            : Icons.lock_outline_rounded,
                        size: 12,
                        color: macroOverride.value ? _C.primary : _C.text3,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        macroOverride.value ? 'Manual' : 'Override',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: macroOverride.value ? _C.primary : _C.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )),
          const SizedBox(height: 10),

          // P / C / F input row
          Obx(() => Row(
            children: [
              // Protein
              Expanded(
                child: _macroInputField(
                  label: 'Protein',
                  unit: 'g',
                  color: _C.protein,
                  controller: proteinController,
                  enabled: macroOverride.value,
                  onChanged: (val) {
                    if (!macroOverride.value) return;
                    final p = double.tryParse(val) ?? item.protein;
                    final c = double.tryParse(carbsController.text) ?? item.carbs;
                    final f = double.tryParse(fatController.text) ?? item.fat;
                    _ctrl.updateMacros(item.cartId, p, c, f);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Carbs
              Expanded(
                child: _macroInputField(
                  label: 'Carbs',
                  unit: 'g',
                  color: _C.carbs,
                  controller: carbsController,
                  enabled: macroOverride.value,
                  onChanged: (val) {
                    if (!macroOverride.value) return;
                    final p = double.tryParse(proteinController.text) ?? item.protein;
                    final c = double.tryParse(val) ?? item.carbs;
                    final f = double.tryParse(fatController.text) ?? item.fat;
                    _ctrl.updateMacros(item.cartId, p, c, f);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Fat
              Expanded(
                child: _macroInputField(
                  label: 'Fat',
                  unit: 'g',
                  color: _C.fat,
                  controller: fatController,
                  enabled: macroOverride.value,
                  onChanged: (val) {
                    if (!macroOverride.value) return;
                    final p = double.tryParse(proteinController.text) ?? item.protein;
                    final c = double.tryParse(carbsController.text) ?? item.carbs;
                    final f = double.tryParse(val) ?? item.fat;
                    _ctrl.updateMacros(item.cartId, p, c, f);
                  },
                ),
              ),
            ],
          )),

          const SizedBox(height: 10),

          // Live nutrition preview
          Obx(() => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceAround,
              children: [
                _liveNutrient('Calories',
                    '${item.calories.toStringAsFixed(1)} kcal', _C.text1),
                _liveNutrient('Protein',
                    '${item.protein.toStringAsFixed(1)}g', _C.protein),
                _liveNutrient('Carbs',
                    '${item.carbs.toStringAsFixed(1)}g', _C.carbs),
                _liveNutrient('Fat',
                    '${item.fat.toStringAsFixed(1)}g', _C.fat),
              ],
            ),
          )),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _ctrl.toggleEditing(item.cartId),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Macro Input Field Helper ─────────────────────────────────────────────────
  Widget _macroInputField({
    required String label,
    required String unit,
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
              suffix: Text(unit,
                  style: TextStyle(
                      fontSize: 11,
                      color: enabled ? color : _C.text3)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom Summary Bar ──────────────────────────────────────────────────────
  Widget _buildBottomSummary() {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          )
        ],
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Totals row
          Obx(() => Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _totalStat('Total Cal',
                  '${_ctrl.totalCalories.toStringAsFixed(1)} kcal',
                  _C.text1,
                  isBold: true),
              _totalStat(
                  'Protein',
                  '${_ctrl.totalProtein.toStringAsFixed(1)}g',
                  _C.protein),
              _totalStat('Carbs',
                  '${_ctrl.totalCarbs.toStringAsFixed(1)}g', _C.carbs),
              _totalStat('Fat',
                  '${_ctrl.totalFat.toStringAsFixed(1)}g', _C.fat),
            ],
          )),
          const SizedBox(height: 12),
          // Save Button
          Obx(() => GestureDetector(
            onTap: _ctrl.isSaving.value ? null : () {
              if (_isOffline) {
                Get.snackbar('📵 You\'re Offline',
                    'Connect to save your meal.',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.orange.shade400,
                    colorText: Colors.white);
                return;
              }
              _ctrl.saveMeal();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: (_ctrl.isSaving.value || _isOffline)
                      ? [_C.primary.withValues(alpha: 0.5), _C.dark.withValues(alpha: 0.5)]
                      : [_C.primary, _C.dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _ctrl.isSaving.value
                    ? null
                    : [
                  BoxShadow(
                    color: _C.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Center(
                child: _ctrl.isSaving.value
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isEditMode
                          ? 'Update Meal'
                          : 'Save ${_ctrl.cartItems.length} Item${_ctrl.cartItems.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ── Widget Helpers ──────────────────────────────────────────────────────────
  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _macroMini(String label, String value, Color color) {
    return Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration:
          BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 3),
      Text('$label: $value g',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _servingBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _C.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _C.primary, size: 20),
      ),
    );
  }

  Widget _liveNutrient(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: _C.text3)),
    ]);
  }

  Widget _totalStat(String label, String value, Color color,
      {bool isBold = false}) {
    return Column(children: [
      Text(
        value,
        style: TextStyle(
          fontSize: isBold ? 15 : 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      Text(label,
          style: const TextStyle(fontSize: 10, color: _C.text3)),
    ]);
  }

  String _foodEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('chicken')) return '🍗';
    if (n.contains('rice'))    return '🍚';
    if (n.contains('oat'))     return '🥣';
    if (n.contains('yogurt') || n.contains('yoghurt')) return '🥛';
    if (n.contains('banana')) return '🍌';
    if (n.contains('salmon') || n.contains('fish')) return '🐟';
    if (n.contains('egg'))    return '🥚';
    if (n.contains('avocado')) return '🥑';
    if (n.contains('sweet potato') || n.contains('potato')) return '🍠';
    if (n.contains('almond') || n.contains('nut')) return '🥜';
    if (n.contains('protein') || n.contains('shake')) return '💪';
    if (n.contains('broccoli') || n.contains('vegetable')) return '🥦';
    if (n.contains('peanut') || n.contains('butter')) return '🥜';
    if (n.contains('milk')) return '🥛';
    if (n.contains('apple')) return '🍎';
    if (n.contains('bread')) return '🍞';
    if (n.contains('pasta')) return '🍝';
    if (n.contains('pizza')) return '🍕';
    if (n.contains('salad')) return '🥗';
    if (n.contains('steak') || n.contains('beef')) return '🥩';
    if (n.contains('coffee')) return '☕';
    return '🍴';
  }
}