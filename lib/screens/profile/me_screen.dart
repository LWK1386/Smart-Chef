import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '/controllers/profile_controller.dart';
import '/controllers/post_controller.dart';
import '/screens/blog/post_detail_screen.dart';
import 'engagement_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final ProfileController profileController = Get.put(ProfileController());
  final PostController postController = Get.find<PostController>();
  late TabController _tabController;

  final Color primaryGreen = const Color(0xFF00A676);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Use a sequence to ensure IDs are loaded before posts are filtered
    profileController.loadProfile().then((_) {
      postController.fetchPosts();
      profileController.fetchLikedPosts();
    });
  }

  Future<void> _refreshData() async {
    try {
      // 1. Trigger haptic feedback for a premium feel
      HapticFeedback.mediumImpact();

      // 2. Run all fetch commands in parallel to save time
      await Future.wait([
        profileController.loadProfile(),
        postController.fetchPosts(),
        profileController.fetchLikedPosts(),
      ]);
    } catch (e) {
      debugPrint("Refresh Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "My Kitchen",
            style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          actions: [
      IconButton(
      // Use a bold icon color to ensure it's not blending in
      icon: const Icon(Icons.settings_outlined, color: Color(0xFF00A676)),
      onPressed: () {
        HapticFeedback.lightImpact();
        _showSettingsSheet();
      },
    )]
    ),
      body: Obx(() => NestedScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: _buildProfileHeader()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: primaryGreen,
                  unselectedLabelColor: Colors.grey[400],
                  indicatorColor: primaryGreen,
                  tabs: const [
                    Tab(text: "My Recipes"),
                    Tab(text: "Liked"),
                  ],
                ),
              ),
            ),
          ];
        },
        // MOVE REFRESH INDICATOR HERE
        body: RefreshIndicator(
          key: _refreshIndicatorKey,
          color: primaryGreen,
          onRefresh: _refreshData,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildScrollableTab(isLiked: false),
              _buildScrollableTab(isLiked: true),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // ... Avatar and Username stay exactly the same ...
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showPickerOptions(); // Show the camera/gallery choice
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Obx(() => CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[100],
                  // THIS IS THE MAGIC LINE FOR OFFLINE AVATARS
                  backgroundImage: profileController.avatarUrl.value.isNotEmpty
                      ? CachedNetworkImageProvider(profileController.avatarUrl.value)
                      : null,
                  child: profileController.avatarUrl.value.isEmpty || profileController.isUploading.value
                      ? profileController.isUploading.value
                      ? const CircularProgressIndicator()
                      : Icon(Icons.person, size: 40, color: Colors.grey[400])
                      : null,
                )),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryGreen,
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profileController.username.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatItem("Recipes", postController.myPosts.length.toString())),
              Container(height: 30, width: 1, color: Colors.grey[200]),
              Expanded(child: _buildStatItem("Liked", profileController.likedPosts.length.toString())),
            ],
          ),
          const SizedBox(height: 24),

          // --- NEW FULL-WIDTH BUTTON HERE ---
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                // Navigate to the new Engagement Screen
                Get.to(() => const EngagementScreen());
              },
              icon: const Icon(Icons.pie_chart_outline, color: Colors.white),
              label: const Text(
                  "View Engagement Stats",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildScrollableTab({required bool isLiked}) {
    final posts = isLiked ? profileController.likedPosts : postController.myPosts;
    final bool loading = isLiked ? profileController.isLoading.value : postController.isLoading.value;

    if (loading) return _buildShimmerGrid();

    // If empty, we MUST use a scrollable view or pull-to-refresh fails
    if (posts.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: 400, // Enough height to allow a "pull"
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[200]),
              Text("Nothing here yet", style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      // CRITICAL: This allows the scroll to bubble up to the RefreshIndicator
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => Get.to(() => PostDetailScreen(post: post)),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[100]),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: post.imageUrl ?? "",
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(), // Shows a spinner while downloading the first time
              ),
              errorWidget: (context, url, error) => const Icon(Icons.image_not_supported), // Fallback if it fails
            ),
          ),
        );
      },
    );
  }

  void _showSettingsSheet() {
    Get.bottomSheet(
      // Container provides the white background and rounded corners
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        // SafeArea ensures it doesn't get cut off by the "home bar" on iPhones
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Takes up only needed space
            children: [
              // The "Grabber" handle at the top
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "Settings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(Icons.person_outline, color: primaryGreen),
                title: const Text("Edit Profile Name"),
                onTap: () {
                  Get.back();
                  _showEditNameDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
                onTap: () => profileController.logout(),
              ),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
      isScrollControlled: true, // Allows the sheet to resize properly
      backgroundColor: Colors.transparent, // Ensures the rounded corners look right
    );
  }

  void _showEditNameDialog() {
    // 1. Pre-fill the controller with the current name
    profileController.nameController.text = profileController.username.value;

    Get.defaultDialog(
      title: "Change Name",
      titleStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: TextField(
          controller: profileController.nameController,
          decoration: InputDecoration(
            hintText: "Enter username",
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryGreen)),
          ),
        ),
      ),
      textConfirm: "Save",
      confirmTextColor: Colors.white,
      buttonColor: primaryGreen,
      onConfirm: () async {
        await profileController.updateProfile();
        Get.back(); // Closes dialog
      },
    );
  }

  void _showPickerOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Profile Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF00A676)),
              title: const Text("Take a Photo"),
              onTap: () {
                Get.back();
                // Trigger the Camera hardware
                profileController.updateAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF00A676)),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Get.back();
                // Trigger the Gallery picker
                profileController.updateAvatar(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

Widget _buildShimmerGrid() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[200]!,
    highlightColor: Colors.grey[50]!,
    child: GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: 6, // Show 6 skeleton boxes
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

// Delegate for the Sticky TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white, // This ensures the tabs aren't transparent
      child: _tabBar,
    );
  }

  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}