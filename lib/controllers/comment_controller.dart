import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/comment_model.dart';
import '../services/supabase_service.dart';

class CommentController extends GetxController {
  final SupabaseService _service = SupabaseService();
  final commentController = TextEditingController();

  // Use <CommentModel> to ensure type safety in UI
  var comments = <CommentModel>[].obs;
  var isLoading = false.obs;

  Future<void> fetchComments(String postId) async {
    try {
      isLoading.value = true;
      final List<dynamic> data = await _service.fetchComments(postId);

      // Correctly map the raw database data to your CommentModel
      comments.value = data.map((e) => CommentModel.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("FetchComments error: $e");
      // Use the post-frame callback we used before to prevent the snackbar crash
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar("Error", "Could not load comments");
      });
    } finally {
      isLoading.value = false;
    }
  }

  // Simplified getter for UI
  List<CommentModel> get commentsList => comments;

  Future<void> submitComment(String postId) async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await _service.addComment(postId, text);
      commentController.clear();

      // Refresh the list immediately so the user sees their comment
      await fetchComments(postId);
    } catch (e) {
      Get.snackbar("Error", "Failed to post comment");
    }
  }

  Future<void> removeComment(String commentId, String postId) async {
    try {
      await _service.deleteComment(commentId);
      // Refresh the list after deleting
      fetchComments(postId);
      Get.snackbar("Success", "Comment deleted", snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar("Error", "Could not delete comment");
    }
  }

  @override
  void onClose() {
    commentController.dispose();
    super.onClose();
  }
}