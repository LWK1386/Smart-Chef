import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'waste_screen.dart';
import '../waste/favorite_recipes_page.dart';

// --- Design System Constants ---
const Color kPrimaryGreen = Color(0xFF00A676);
const Color kAccentOrange = Color(0xFFFF9800);
const Color kBgColor = Color(0xFFF9FBF9);

class IngredientChoicePage extends StatelessWidget {
  const IngredientChoicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevents accidental back button
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0, top: 12.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoriteRecipesPage()),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "My Favorites",
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
        body: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.portrait) {
                return _buildPortraitLayout(context);
              } else {
                return _buildLandscapeLayout(context);
              }
            },
          ),
        ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "Reduce Waste,",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            "Cook Deliciously.",
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: kPrimaryGreen,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "What's in your kitchen today?",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 40),

          Expanded(child: _buildChoiceList(context)),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Reduce Waste,",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  "Cook Deliciously.",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kPrimaryGreen,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "What's in your kitchen today?",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 30),

          Expanded(
            flex: 3,
            child: _buildChoiceList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceList(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _buildChoiceCard(
          context,
          title: "Smart Scan",
          subtitle: "Take a photo of your fridge",
          icon: Icons.camera_alt_rounded,
          color: kPrimaryGreen,
          mode: IngredientMode.scan,
        ),
        _buildChoiceCard(
          context,
          title: "Manual Entry",
          subtitle: "Type in what you have left",
          icon: Icons.edit_note_rounded,
          color: Colors.blueGrey,
          mode: IngredientMode.manual,
        ),
        _buildChoiceCard(
          context,
          title: "AI Creative Mode",
          subtitle: "Surprise me with AI magic",
          icon: Icons.auto_awesome_rounded,
          color: kAccentOrange,
          mode: IngredientMode.ai,
        ),
      ],
    );
  }

  Widget _buildChoiceCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required IngredientMode mode,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FoodWastePage(mode: mode)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}