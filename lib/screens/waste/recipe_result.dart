import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../services/gemini_service.dart';
import '../../services/local_db_service.dart';
import '../../services/supabase_service.dart';
import 'package:uuid/uuid.dart';

const Color kPrimaryGreen = Color(0xFF00A676);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kBgColor = Color(0xFFF9FBF9);
const double kRadius = 16.0;

class RecipeResultPage extends StatefulWidget {
  final List<Map<String, String>> initialRecipes;
  final List<String> ingredients;

  const RecipeResultPage({
    Key? key,
    required this.initialRecipes,
    required this.ingredients,
  }) : super(key: key);

  @override
  State<RecipeResultPage> createState() => _RecipeResultPageState();
}

class _RecipeResultPageState extends State<RecipeResultPage> {
  List<Map<String, String>> recipes = [];
  bool isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    recipes = List.from(widget.initialRecipes);
  }

  Future<void> loadMoreRecipes() async {
    setState(() => isLoadingMore = true);
    try {
      final newRecipes = await GeminiService.generateRecipes(widget.ingredients);
      setState(() => recipes.addAll(newRecipes));
    } finally {
      setState(() => isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildRecipeCard(recipes[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildLoadMoreButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: const BackButton(color: Colors.black),
      title: Text("Your Eco-Recipes",
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _buildRecipeCard(Map<String, String> recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe)),
        ),
        borderRadius: BorderRadius.circular(kRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
                  child: recipe["image"] != null && recipe["image"]!.isNotEmpty
                      ? Image.network(recipe["image"]!, height: 200, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 150, width: double.infinity, color: kPrimaryGreen.withOpacity(0.1), child: const Icon(Icons.restaurant, color: kPrimaryGreen, size: 40)),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedHeart(recipe: recipe),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe["title"] ?? "Sustainable Surprise",
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(height: 8),

                  // 🔹 ADDED: Kcal and Duration Row
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          recipe["duration"] ?? "--",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.local_fire_department_outlined, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          recipe["kcal"] ?? "--",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text("View Details", style: GoogleFonts.poppins(color: kPrimaryGreen, fontWeight: FontWeight.w600, fontSize: 14)),
                      const Icon(Icons.arrow_forward_rounded, color: kPrimaryGreen, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: ElevatedButton(
        onPressed: isLoadingMore ? null : loadMoreRecipes,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: kPrimaryGreen,
          side: const BorderSide(color: kPrimaryGreen),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoadingMore
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text("Show More Ideas"),
      ),
    );
  }
}

class RecipeDetailPage extends StatelessWidget {
  final Map<String, String> recipe;
  const RecipeDetailPage({Key? key, required this.recipe}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: recipe["image"] != null && recipe["image"]!.isNotEmpty
                  ? Image.network(recipe["image"]!, fit: BoxFit.cover)
                  : Container(color: kPrimaryGreen),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 ADDED: Info Chips Row
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildInfoChip(Icons.timer, recipe["duration"] ?? "20m", Colors.blueGrey),
                      _buildInfoChip(Icons.local_fire_department, recipe["kcal"] ?? "---", Colors.orange),
                      const Text(
                        "Eco-Friendly",
                        style: TextStyle(
                          color: kPrimaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(recipe["title"] ?? "", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Ingredients"),
                  // Use a different style for multi-line text
                  Text(recipe["ingredients"] ?? "", style: GoogleFonts.poppins(height: 1.8, fontSize: 15, color: Colors.grey.shade800)),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Cooking Steps"),
                  Text(recipe["steps"] ?? "", style: GoogleFonts.poppins(height: 1.8, fontSize: 15, color: Colors.grey.shade800)),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Helper for the Info Chips
  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Tooltip(
      message: label, // Full text shows on hover or long press
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: kPrimaryGreen)),
    );
  }
}

class AnimatedHeart extends StatefulWidget {
  final Map<String, String> recipe;

  const AnimatedHeart({Key? key, required this.recipe}) : super(key: key);

  @override
  State<AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<AnimatedHeart> with SingleTickerProviderStateMixin {
  final SupabaseService supabase = SupabaseService();
  final LocalDbService db = LocalDbService();
  bool isFavorite = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  void loadFavorite() async {

    bool fav = false;

    try {
      //Check Supabase first
      fav = await supabase.isFavorite(widget.recipe["id"] ?? widget.recipe["title"]!);
    } catch (e) {
      // If internet fails, check SQLite
      fav = await db.isFavorite(widget.recipe["id"] ?? widget.recipe["title"]!);
    }

    setState(() {
      isFavorite = fav;
    });
  }

  @override
  void initState() {
    super.initState();
    loadFavorite();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence(<TweenSequenceItem<double>>[
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFavorite() async {

    setState(() {
      isFavorite = !isFavorite;
    });

    if (isFavorite) {

      _controller.forward(from: 0);

      try {

        //Save to Supabase first
        final recipeId = widget.recipe["id"] ?? const Uuid().v4();
        widget.recipe["id"] = recipeId;

        await supabase.addFavorite(
          recipeId: recipeId,
          title: widget.recipe["title"] ?? "",
          image: widget.recipe["image"] ?? "",
          kcal: widget.recipe["kcal"] ?? "",
          duration: widget.recipe["duration"] ?? "",
          ingredients: widget.recipe["ingredients"] ?? "",
          steps: widget.recipe["steps"] ?? "",
        );

        //Also cache locally
        await db.saveFavorite(widget.recipe);

      } catch (e) {

        // If Supabase fails, fallback to local
        await db.saveFavorite(widget.recipe);

      }

    } else {

      try {

        await supabase.removeFavorite(widget.recipe["id"]!);
        await db.removeFavorite(widget.recipe["id"]!);

      } catch (e) {

        await db.removeFavorite(widget.recipe["id"]!);

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? Colors.redAccent : Colors.white,
          size: 28,
        ),
        onPressed: _toggleFavorite,
      ),
    );
  }
}