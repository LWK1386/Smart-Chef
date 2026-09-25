import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/post_controller.dart';
import '/controllers/comment_controller.dart';
import '/models/post_model.dart';
import '/services/supabase_service.dart';
import 'create_post_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> with SingleTickerProviderStateMixin {
  final CommentController commentController = Get.put(CommentController());
  final SupabaseService _supabaseService = SupabaseService();
  late PostController postController;

  // Animation variables for the double-tap heart
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  bool _showHeartOverlay = false;

  @override
  void initState() {
    super.initState();
    postController = Get.find<PostController>();

    // 1. Zero-flicker initialization
    postController.isLiked.value = widget.post.isLiked;
    postController.currentLikeCount.value = widget.post.likeCount;

    // 2. Animation Setup
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeInOut));

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeartOverlay = false);
        _heartAnimationController.reset();
      }
    });

    postController.checkIfLiked(widget.post.id);
    commentController.fetchComments(widget.post.id);
  }

  void _handleDoubleTap() {
    setState(() => _showHeartOverlay = true);
    _heartAnimationController.forward();

    if (!postController.isLiked.value) {
      postController.toggleLike(widget.post.id);
    }
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // This ensures the status bar icons (clock/battery) stay visible on top of images
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.4),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Get.back(),
            ),
          ),
        ),
        actions: [
          // --- DEBUG TIP: Print IDs to console to see if they actually match ---
          // print("Post User: ${widget.post.user.id} | Current User: ${_supabaseService.currentUser?.id}");

          if (widget.post.user.id == _supabaseService.currentUser?.id)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: PopupMenuButton<String>(
                  // Use a specific icon color to ensure it pierces the background
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _handleEditPost();
                    } else if (value == 'delete') {
                      _confirmDeletePost();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [Icon(Icons.edit_outlined, color: Colors.black, size: 20), SizedBox(width: 8), Text("Edit Post")],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IMAGE SECTION
                  if (widget.post.imageUrl != null)
                    GestureDetector(
                      onDoubleTap: _handleDoubleTap,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Hero(
                            tag: widget.post.id,
                            child: CachedNetworkImage(
                              imageUrl: widget.post.imageUrl!,
                              width: double.infinity,
                              height: 450,
                              fit: BoxFit.cover,
                              // A nice green spinner while the big image loads the first time
                              placeholder: (context, url) => const SizedBox(
                                height: 450,
                                child: Center(
                                  child: CircularProgressIndicator(color: Color(0xFF00A676)),
                                ),
                              ),
                              errorWidget: (context, url, error) => const SizedBox(
                                height: 450,
                                child: Center(child: Icon(Icons.image_not_supported, size: 50)),
                              ),
                            ),
                          ),
                          if (_showHeartOverlay)
                            ScaleTransition(
                              scale: _heartScaleAnimation,
                              child: Icon(
                                Icons.favorite,
                                color: Colors.white.withOpacity(0.9),
                                size: 100,
                              ),
                            ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: widget.post.user.avatarUrl != null
                                  ? CachedNetworkImageProvider(widget.post.user.avatarUrl!)
                                  : null,
                              child: widget.post.user.avatarUrl == null ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 10),
                            Text(widget.post.user.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => postController.toggleLike(widget.post.id),
                              child: Obx(() => Row(
                                children: [
                                  Icon(
                                    postController.isLiked.value ? Icons.favorite : Icons.favorite_border,
                                    color: postController.isLiked.value ? Colors.red : Colors.grey,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 5),
                                  Text("${postController.currentLikeCount.value}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(thickness: 0.5),
                        const SizedBox(height: 10),
                        Text(widget.post.content, style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[800])),
                        const SizedBox(height: 30),
                        const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildCommentSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildCommentInputBar(),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Obx(() {
      if (commentController.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF00A676)));
      }
      if (commentController.comments.isEmpty) {
        return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No comments yet.", style: TextStyle(color: Colors.grey))));
      }
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: commentController.comments.length,
        itemBuilder: (context, index) {
          final comment = commentController.comments[index];
          final bool isMyComment = comment.userId == _supabaseService.currentUser?.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 15, backgroundImage: comment.user.avatarUrl != null ? NetworkImage(comment.user.avatarUrl!) : null),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(comment.content),
                    ],
                  ),
                ),
                // Visible Delete Button for your own comments
                if (isMyComment)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => _confirmDelete(comment.id),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildCommentInputBar() {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(30)),
              child: TextField(
                controller: commentController.commentController,
                decoration: const InputDecoration(hintText: "Say something nice...", border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => postController.toggleLike(widget.post.id),
            child: Obx(() => Icon(
              postController.isLiked.value ? Icons.favorite : Icons.favorite_border,
              color: postController.isLiked.value ? Colors.red : Colors.grey[600],
              size: 26,
            )),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => commentController.submitComment(widget.post.id),
            child: const CircleAvatar(backgroundColor: Color(0xFF00A676), radius: 20, child: Icon(Icons.send, color: Colors.white, size: 18)),
          ),
        ],
      ),
    );
  }

  // UPDATED: Dialog with both Delete and Cancel buttons
  void _confirmDelete(String commentId) {
    Get.defaultDialog(
      title: "Delete Comment",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: "This action cannot be undone.",
      backgroundColor: Colors.white,
      radius: 15,
      // The Cancel Button
      textCancel: "Cancel",
      cancelTextColor: Colors.grey[600],
      onCancel: () => Get.back(),
      // The Delete Button
      textConfirm: "Delete",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        commentController.removeComment(commentId, widget.post.id);
        Get.back(); // Closes the dialog after deletion
      },
    );
  }

  void _confirmDeletePost() {
    Get.defaultDialog(
      title: "Delete Post",
      middleText: "Are you sure you want to delete this recipe? This cannot be undone.",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () async {
        await _supabaseService.deletePost(widget.post.id);
        postController.fetchPosts(); // Refresh the feed
        Get.back(); // Close dialog
        Get.back(); // Return to feed screen
        Get.snackbar("Deleted", "Your recipe has been removed.");
      },
    );
  }

  void _handleEditPost() {
    print("Opening Edit Screen for Post: ${widget.post.id}");
    // Use a slight delay or ensure the context is ready
    Get.to(() => CreatePostScreen(editPost: widget.post), transition: Transition.rightToLeft);
  }

}



