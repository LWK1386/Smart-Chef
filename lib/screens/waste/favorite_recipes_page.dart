import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/local_db_service.dart';
import 'recipe_result.dart';
import '../../services/supabase_service.dart';

const Color kPrimaryGreen = Color(0xFF00A676);
const Color kBgColor = Color(0xFFF9FBF9);

class FavoriteRecipesPage extends StatefulWidget {
  const FavoriteRecipesPage({Key? key}) : super(key: key);

  @override
  State<FavoriteRecipesPage> createState() => _FavoriteRecipesPageState();
}

class _FavoriteRecipesPageState extends State<FavoriteRecipesPage> {
  final SupabaseService supabaseService = SupabaseService();

  Future<bool?> _showDeleteConfirmation(
      BuildContext context,
      String recipeId,
      String title,
      ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Remove Favorite?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text("Delete '$title' from your collection?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              await supabaseService.removeFavorite(recipeId);

              final localDb = LocalDbService();
              await localDb.removeFavorite(recipeId);

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text(
              "Remove",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Saved Delights",
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabaseService.favoritesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryGreen));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final favorites = snapshot.data!;


          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.75, // Adjusts height of the cards
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final recipe = favorites[index];
              return _buildModernRecipeCard(recipe);
            },
          );
        },
      ),
    );
  }

  Widget _buildModernRecipeCard(Map<String, dynamic> recipe) {
    final String title = recipe['title'] ?? "Unknown";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeResultPage(
              initialRecipes: [Map<String, String>.from(recipe)],
              ingredients: [],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      image: DecorationImage(
                        image: NetworkImage(recipe["image"] ?? ""),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // OVERLAY HEART
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        final confirmed = await _showDeleteConfirmation(
                          context,
                          recipe['recipe_id'],
                          title,
                        );
                        if (confirmed == true) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // INFO SECTION
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),

                        Expanded(
                          child: Text(
                            recipe["duration"] ?? "--",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),

                        const SizedBox(width: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kPrimaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (recipe["kcal"] ?? "--").split(' ').first,
                                style: const TextStyle(
                                  color: kPrimaryGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                "kcal",
                                style: TextStyle(
                                  color: kPrimaryGreen,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            "Your cookbook is empty",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            "Save your favorite eco-recipes\nto see them here!",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}