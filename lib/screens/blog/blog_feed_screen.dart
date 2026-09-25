import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '/controllers/post_controller.dart';
import '/models/post_model.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';

class BlogFeedScreen extends StatelessWidget {
  BlogFeedScreen({super.key});

  final PostController postController = Get.put(PostController());
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    postController.startShakeListener();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Added a Refresh Button to the leading or actions
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00A676)),
            onPressed: () {
              // Trigger haptic feedback for better feel
              HapticFeedback.lightImpact();
              postController.fetchPosts();
            },
          ),
        ],
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => postController.searchQuery.value = value,
                  decoration: InputDecoration(
                    hintText: "Search recipes...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Get.snackbar(
                "Quick Tip",
                "Shake your phone for a surprise recipe! 🎲",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF00A676).withOpacity(0.1),
                colorText: const Color(0xFF00A676),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A676).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vibration, color: Color(0xFF00A676), size: 20),
              ),
            ),
          ],
        ),
      ),
      // --- WRAP BODY WITH REFRESH INDICATOR ---
      body: RefreshIndicator(
        color: const Color(0xFF00A676),
        onRefresh: () => postController.fetchPosts(),
        child: Obx(() {
          if (postController.isLoading.value) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00A676)));
          }

          final posts = postController.filteredPosts;

          if (posts.isEmpty) {
            // ListView needed here so the RefreshIndicator can detect a scroll/pull
            return ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No results for '${postController.searchQuery.value}'",
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            padding: const EdgeInsets.all(10),
            itemCount: posts.length,
            // Allow the MasonryGrid to be scrollable for the RefreshIndicator
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return _buildRedNoteCard(context, posts[index]);
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A676),
        onPressed: () {
          // Turn Off sensor while writing a new post
          postController.canShake = false;
          Get.to(() => const CreatePostScreen())?.then((_) {
            // Fetch new posts AND turn sensor back ON
            postController.fetchPosts();
            postController.canShake = true;
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRedNoteCard(BuildContext context, PostModel post) {
    return GestureDetector(
      onTap: () {
        // Turn Off the sensor
        postController.canShake = false;
        Get.to(() => PostDetailScreen(post: post))?.then((_) {
          // Turn the sensor back ON when the user presses the 'back' button
          postController.canShake = true;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Post Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: post.imageUrl != null
                  ? Hero(
                tag: post.id, // Added Hero tag for smooth transition
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(), // Shows a spinner while downloading the first time
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.image_not_supported), // Fallback if it fails
                ),
              )
                  : Container(height: 100, color: Colors.grey[200], child: const Icon(Icons.image)),
            ),

            // 2. Title and Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // User Avatar
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: post.user.avatarUrl != null
                            ? NetworkImage(post.user.avatarUrl!)
                            : null,
                        child: post.user.avatarUrl == null ? const Icon(Icons.person, size: 12) : null,
                      ),
                      const SizedBox(width: 6),
                      // Username
                      Expanded(
                        child: Text(
                          post.user.username,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // --- MODIFIED LIKE SECTION ---
                      Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: post.isLiked ? Colors.red : Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                          "${post.likeCount}",
                          style: TextStyle(
                            fontSize: 12,
                            color: post.isLiked ? Colors.red : Colors.black,
                            fontWeight: post.isLiked ? FontWeight.bold : FontWeight.normal,
                          )
                      ),
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
}