import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_chef/screens/waste/recipe_result.dart';
import 'package:smart_chef/services/waste_recipe_service.dart';
import '/services/gemini_service.dart';
import 'package:lottie/lottie.dart';

enum IngredientMode { manual, scan, ai }

// --- Design System Constants ---
const Color kPrimaryGreen = Color(0xFF00A676);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kBgColor = Color(0xFFF9FBF9);
const double kRadius = 16.0;

class FoodWastePage extends StatefulWidget {
  final IngredientMode mode;
  const FoodWastePage({Key? key, required this.mode}) : super(key: key);

  @override
  _FoodWastePageState createState() => _FoodWastePageState();
}

class _FoodWastePageState extends State<FoodWastePage> {
  List<String> leftoverIngredients = [];
  List<File> scannedImages = [];
  bool isProcessing = false;
  final picker = ImagePicker();
  final TextEditingController ingredientController = TextEditingController();

  // --- Logic Methods ---
  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final file = File(pickedFile.path);

      setState(() {
        scannedImages.add(file);
        isProcessing = true;
      });

      await detectIngredients(file);
    }
  }

  Future<void> detectIngredients(File image) async {
    try {
      final List<String> detected =
      await GeminiService.detectIngredients(image);

      if (detected.isEmpty) {
        _showError("No ingredients detected. Try again.");
        return;
      }

      setState(() {
        for (String ingredient in detected) {
          if (!leftoverIngredients.contains(ingredient)) {
            leftoverIngredients.add(ingredient);
          }
        }
      });

    } catch (e) {
      _showError("Failed to detect ingredients");
      print(e);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void addIngredient(String ingredient) {
    if (ingredient.trim().isEmpty) return;
    setState(() {
      leftoverIngredients.insert(0, ingredient.trim());
      ingredientController.clear();
    });
  }

  void removeIngredient(String ingredient) {
    setState(() => leftoverIngredients.remove(ingredient));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void generateRecipes() async {
    if (widget.mode != IngredientMode.ai && leftoverIngredients.isEmpty) {
      _showError("Please add ingredients first");
      return;
    }
    setState(() => isProcessing = true);
    try {
      List<Map<String, String>> recipes = [];

      if (widget.mode == IngredientMode.ai) {
        final fixedIngredients = await GeminiService.fixIngredients(leftoverIngredients);

        recipes = await GeminiService.generateRecipes(fixedIngredients);
      } else {
        // Fetch from Spoonacular
        final spoonacularRecipes =
        await RecipeService.fetchRecipesByIngredients(leftoverIngredients);

        recipes = spoonacularRecipes.map((r) => {
          "title": r.title,
          "ingredients": r.ingredients.join(", "),
          "steps": r.steps.join("\n"),
          "image": r.image,
          "kcal": r.kcal,
          "duration": r.duration,
        }).toList();
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeResultPage(
            initialRecipes: recipes,
            ingredients: leftoverIngredients,
          ),
        ),
      );
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  void dispose() {
    ingredientController.dispose();
    super.dispose();
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: kBgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Food Waste Manager',
            style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildInputArea(),
                        const SizedBox(height: 24),
                        _buildIngredientGrid(),
                        if (scannedImages.isNotEmpty) _buildImagePreview(),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),

            if (isProcessing)
              AbsorbPointer(
                child: Container(
                  color: Colors.white.withOpacity(0.8), // Semi-transparent white
                  child: Center(
                    child: _buildFancyLoading(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = "Let's save food!";
    if (widget.mode == IngredientMode.scan) title = "Scan your fridge";
    if (widget.mode == IngredientMode.ai) title = "AI Recipe Assistant";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black)),
        const SizedBox(height: 4),
        Text("Tell us what you have left, we'll do the rest.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ],
    );
  }

  Widget _buildInputArea() {
    bool isScan = widget.mode == IngredientMode.scan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          if (isScan) _buildScanButton(),
          if (!isScan) _buildManualField(),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return InkWell(
      onTap: isProcessing ? null : pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          border: Border.all(
            color: kPrimaryGreen.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            isProcessing
                ? const CircularProgressIndicator()
                : const Icon(Icons.camera_alt_outlined,
                size: 48, color: kPrimaryGreen),
            const SizedBox(height: 12),
            Text(
              isProcessing ? "Detecting ingredients..." : "Tap to scan ingredients",
              style: GoogleFonts.poppins(
                color: kPrimaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ingredientController,
            onSubmitted: (val) => addIngredient(val),
            decoration: InputDecoration(
              hintText: 'Add an ingredient...',
              filled: true,
              fillColor: kBgColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => addIngredient(ingredientController.text),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientGrid() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: leftoverIngredients.isEmpty
          ? const SizedBox.shrink()
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your Ingredients", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: leftoverIngredients.map((ingredient) => _buildChip(ingredient)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: Colors.white,
      elevation: 0,
      side: BorderSide(color: Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
      onDeleted: () => removeIngredient(label),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: scannedImages.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kRadius),
                    child: Image.file(
                      scannedImages[index],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // ❌ Delete Button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          scannedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isProcessing)
            const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator(color: kPrimaryGreen, backgroundColor: kBgColor)),
          ElevatedButton(
            onPressed: (isProcessing || (widget.mode != IngredientMode.ai && leftoverIngredients.isEmpty))
                ? null
                : generateRecipes,
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
              elevation: 0,
            ),
            child: Text(
              widget.mode == IngredientMode.ai ? '✨ Generate AI Recipes' : 'Generate Recipes',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFancyLoading() {
    return Container(
      color: kBgColor.withOpacity(0.95),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🌟 THE MAGIC: Fancy Lottie Animation
          Lottie.network(
            'https://assets5.lottiefiles.com/packages/lf20_tll0j4bb.json',
            height: 200,
            repeat: true,
          ),

          const SizedBox(height: 20),

          Text(
            "Chef is thinking...",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Rotating Cooking Facts/Tips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 3), (i) => i),
              builder: (context, snapshot) {
                List<String> tips = [
                  "Did you know? Broccoli stems are edible!",
                  "AI is searching for the best eco-friendly recipes...",
                  "Reducing food waste saves money and the planet.",
                  "Adding a bit of acid brightens old veggies.",
                  "Stale bread is perfect for homemade croutons!",
                ];
                String currentTip = tips[(snapshot.data ?? 0) % tips.length];

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    currentTip,
                    key: ValueKey(currentTip),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          const SizedBox(
            width: 150,
            child: LinearProgressIndicator(
              color: kPrimaryGreen,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}