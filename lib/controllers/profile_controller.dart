import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';
import '../models/post_model.dart';
import 'post_controller.dart';

class ProfileController extends GetxController {
  final SupabaseService _service = SupabaseService();
  final LocalDbService _localDb = LocalDbService();
  final ImagePicker _picker = ImagePicker();

  // Controllers & State
  final nameController = TextEditingController();
  var isUploading = false.obs;
  var isLoading = false.obs;

  // Profile Data
  var username = "Guest".obs;
  var avatarUrl = "".obs;
  var userId = "".obs;
  var likedPosts = <PostModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    initialLoad();
  }

  String get currentUid => _service.currentUser?.id ?? "";

  // Data Loading
  Future<void> initialLoad() async {
    await loadProfile();
    await fetchLikedPosts();
  }

  Future<void> loadProfile() async {
    try {
      isLoading.value = true;

      // 1. LOCAL DATA (SQLite) - Instant feedback
      if (currentUid.isNotEmpty) {
        final localData = await _localDb.getLocalProfile(currentUid);
        if (localData != null) {
          _updateUIState(localData);
          debugPrint("Profile loaded from SQLite");
        }
      }

      // 2. REMOTE DATA (Supabase) - Sync with cloud
      final remoteData = await _service.getProfile();
      if (remoteData != null) {
        // 3. PERSISTENCE - Save remote data to SQLite for next time
        await _localDb.saveLocalProfile({
          'id': remoteData['id'],
          'username': remoteData['username'],
          'avatar_url': remoteData['avatar_url'],
        });

        // 4. UPDATE UI - Final fresh data
        _updateUIState(remoteData);
        debugPrint("Profile synced from Supabase and saved to SQLite");
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Helper to keep code clean
  void _updateUIState(Map<String, dynamic> data) {
    userId.value = data['id']?.toString() ?? "";
    username.value = data['username'] ?? "Unknown";

    if (data['avatar_url'] != null && data['avatar_url'].isNotEmpty) {
      // Keep the cache-buster to ensure images refresh
      avatarUrl.value = "${data['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}";
    } else {
      avatarUrl.value = "";
    }
    nameController.text = username.value;
  }

  Future<void> fetchLikedPosts() async {
    try {
      // 1. OFFLINE FIRST: Instantly load cached likes from SQLite
      final localLikes = await _localDb.getLocalLikedPosts();
      if (localLikes.isNotEmpty) {
        likedPosts.value = localLikes.map((item) {
          // Reconstruct the map exactly how PostModel expects it
          return PostModel.fromMap({
            'id': item['id'],
            'user_id': item['user_id'],
            'title': item['title'],
            'content': item['content'],
            'image_url': item['image_url'],
            'created_at': item['created_at'],
            'profiles': {
              'username': item['author_name'],
              'avatar_url': item['author_avatar'],
            }
          }, currentUserId: currentUid);
        }).toList();
        debugPrint("Loaded ${localLikes.length} liked posts from local SQLite");
      }

      // 2. CLOUD SYNC: Fetch fresh data from Supabase
      final List<dynamic> data = await _service.fetchLikedPosts();

      // 3. PERSISTENCE: Save the fresh data to SQLite for next time
      await _localDb.saveLikedPostsLocally(data);

      // 4. UPDATE UI: Show the absolute latest data
      likedPosts.value = data.map((item) {
        return PostModel.fromMap(
            item['posts'] as Map<String, dynamic>,
            currentUserId: currentUid
        );
      }).toList();

    } catch (e) {
      debugPrint("Error fetching liked posts: $e");
    }
  }

  // Profile Actions
  Future<void> updateProfile() async {
    String newName = nameController.text.trim();
    if (newName.isEmpty) {
      Get.snackbar("Error", "Name cannot be empty",
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    try {
      isLoading.value = true;

      // Update Remote
      await _service.updateProfile(username: newName);

      // Update Local SQLite immediately
      await _localDb.saveLocalProfile({
        'id': currentUid,
        'username': newName,
        'avatar_url': avatarUrl.value.split('?').first, // Remove cache buster for DB
      });

      username.value = newName;

      // Sync feed
      try {
        Get.find<PostController>().fetchPosts();
      } catch (_) {}

      Get.snackbar("Success", "Profile updated and cached!",
          backgroundColor: const Color(0xFF00A676), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Update failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // HARDWARE INTEGRATION (Camera/Gallery)
  Future<void> updateAvatar(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 50, maxWidth: 400);
      if (image == null) return;

      isLoading.value = true;

      // 1. Upload to Supabase
      await _service.updateProfile(
        username: username.value,
        avatarFile: File(image.path),
      );

      // 2. Refresh (This will automatically update SQLite via loadProfile)
      await loadProfile();

      // 3. Sync other controllers
      await fetchLikedPosts();
      try {
        Get.find<PostController>().fetchPosts();
      } catch (_) {}

      Get.snackbar("Success", "Avatar updated everywhere!");
    } catch (e) {
      Get.snackbar("Error", "Upload failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Authentication
  Future<void> logout() async {
    try {
      await _service.signOut();
      await _localDb.clearLocalProfile(); // Clear SQLite on logout for security

      userId.value = "";
      username.value = "Guest";
      avatarUrl.value = "";
      likedPosts.clear();

      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar("Error", "Logout failed: $e");
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }
}