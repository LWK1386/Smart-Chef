import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_chef/controllers/profile_controller.dart';
import '../models/post_model.dart';
import '../screens/blog/post_detail_screen.dart';
import '../services/local_db_service.dart'; // Ensure this is imported
import '../services/supabase_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class PostController extends GetxController {
  final SupabaseService _service = SupabaseService();
  final LocalDbService _localDb = LocalDbService(); // 1. Added Local Database

  final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: 'hidden',
  );

  // Text Controllers
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  // Image
  Rx<File?> selectedImage = Rx<File?>(null);

  // Posts state
  var posts = <PostModel>[].obs;
  var isLoading = false.obs;

  //Search variable
  var searchQuery = "".obs; // Holds the current search text

  // Use a computed property (getter) to filter posts automatically
  List<PostModel> get filteredPosts {
    if (searchQuery.value.isEmpty) {
      return posts;
    }
    return posts.where((post) {
      final title = post.title.toLowerCase();
      final content = post.content.toLowerCase();
      final query = searchQuery.value.toLowerCase();
      return title.contains(query) || content.contains(query);
    }).toList();
  }

  // Init
  @override
  void onInit() {
    super.onInit();
    fetchPosts();
    // Start listening for shakes as soon as the app starts
    startShakeListener();
  }

  // HYBRID FETCH: SQLite + Supabase
  Future<void> fetchPosts({bool showError = true}) async {
    try {
      isLoading.value = true;
      final currentUid = _service.currentUser?.id;

      // 1. LOAD LOCAL (SQLite) - Instant UI load
      try {
        final localData = await _localDb.getLocalPosts();
        if (localData.isNotEmpty) {
          posts.value = localData.map((e) => PostModel.fromLocalSql(e)).toList();
          debugPrint("Blog loaded from SQLite cache instantly");
        }
      } catch (dbError) {
        debugPrint("Local DB Error: $dbError");
      }

      // 2. FETCH REMOTE (Supabase) - Background Sync
      final data = await _service.fetchPosts();

      if (data.isNotEmpty) {
        // 3. PERSISTENCE: Save fresh remote data to SQLite for next time
        await _localDb.savePostsLocally(data);

        // 4. UPDATE UI: Show the most up-to-date data
        posts.value = data.map((e) {
          final model = PostModel.fromMap(e as Map<String, dynamic>, currentUserId: currentUid);
          return model;
        }).toList();
      }

    } catch (e) {
      debugPrint("Offline mode or Fetch Error: $e");

      // prove offline mode
      if (showError) {
        Get.snackbar(
          "Offline Mode",
          "You are browsing cached recipes. Please connect to the internet to see new posts.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orangeAccent,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<PostModel>> getPosts() async {
    if (posts.isEmpty) await fetchPosts(showError: false);
    return posts;
  }

  List<PostModel> get myPosts {
    final currentUid = _service.currentUser?.id;
    if (currentUid == null) return [];
    // to filter posts belonging to the logged-in user
    return posts.where((p) => p.user.id == currentUid).toList();
  }

  //Update post
  Future<void> updatePost(String postId) async {
    try {
      isLoading.value = true;

      await _service.updatePost(
        postId: postId,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
      );

      //  triggers hybrid fetch (updates Remote, then saves to Local)
      await fetchPosts();

      // Clear inputs for the next time the user opens the screen
      titleController.clear();
      contentController.clear();
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // Pick image
  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      selectedImage.value = File(image.path);
    }
  }

  // Submit post
  Future<void> submitPost() async {
    if (titleController.text.isEmpty || contentController.text.isEmpty) {
      Get.snackbar("Error", "Please fill all fields", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      isLoading.value = true;

      // 1. AI Review & Enhancement Phase
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: 'AIzaSyB5z8_MWyKlNxItApAAZRrARylVLOZDmhc');

      final prompt = """
    You are the SmartChef AI Moderator. 
    Analyze the following title and content.
    Title: ${titleController.text}
    Content: ${contentController.text}

    Rules:
    1. If the content is NOT about food, cooking, or recipes, respond ONLY with "REJECT".
    2. If it IS about food, rewrite the content to be more engaging and appetizing, but keep all original steps/ingredients.
    3. Respond in this EXACT format:
    STATUS: [APPROVE or REJECT]
    ENHANCED_CONTENT: [Your rewritten version here]
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      final result = response.text ?? "";

      // Check if the Chef AI rejected the content
      if (result.contains("REJECT")) {
        Get.snackbar(
          "Invalid Content",
          "SmartChef only accepts food-related posts. Please share a recipe!",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return;
      }

      // Extract the enhanced content
      String finalContent = contentController.text.trim();
      if (result.contains("ENHANCED_CONTENT:")) {
        finalContent = result.split("ENHANCED_CONTENT:").last.trim();
      }

      // 2. Image Upload Phase (Only if AI approves)
      String? imageUrl;
      if (selectedImage.value != null) {
        imageUrl = await _service.uploadImage(
          selectedImage.value!,
          'posts/${DateTime.now().millisecondsSinceEpoch}_${_service.currentUser?.id ?? 'anon'}.png',
        );

        if (imageUrl == null) {
          Get.snackbar("Error", "Failed to upload image", snackPosition: SnackPosition.BOTTOM);
          return;
        }
      }

      // 3. Database Save Phase
      await _service.createPost(
        title: titleController.text.trim(),
        content: finalContent, // We use the AI-enhanced content here!
        imageFile: selectedImage.value,
      );

      // 4. Cleanup, Refresh & Navigation
      titleController.clear();
      contentController.clear();
      selectedImage.value = null;

      // This will pull the new post and cache it to SQLite immediately
      await fetchPosts();

      Get.back();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar("Success", "Recipe published with SmartChef AI!", snackPosition: SnackPosition.BOTTOM);
      });

    } catch (e) {
      Get.snackbar("Error", "AI verification error: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> enhanceWithAI() async {
    if (contentController.text.isEmpty) {
      Get.snackbar("Tip", "Write something first so the AI can polish it!");
      return;
    }

    try {
      isLoading.value = true;

      // Initialize Gemini
      final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: 'AIzaSyB5z8_MWyKlNxItApAAZRrARylVLOZDmhc'
      );

      // formating rules
      final prompt = """
    You are a professional food blogger and chef. 
    Rewrite the following recipe content to be more engaging, appetizing, and well-structured for a social media app called SmartChef.
    Keep the original ingredients and steps accurate, but use a friendly and exciting tone.
    
    CRITICAL FORMATTING RULES:
    - DO NOT use any Markdown formatting (absolutely NO asterisks **, hashes ##, underscores _, or dividers ---).
    - Output purely plain text.
    - No asterisks '*' in the text!
    - Use a simple dash (-) for bullet points and ingredient lists.
    - Use standard numbering (1., 2., 3.) for the cooking steps.
    
    Original Content: ${contentController.text}
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      final enhancedText = response.text;

      if (enhancedText != null && enhancedText.isNotEmpty) {
        // Update the text field with the new AI version
        contentController.text = enhancedText.trim();
        Get.snackbar("AI Magic", "Recipe polished by SmartChef AI!",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFE0F7F1),
            colorText: const Color(0xFF00A676)
        );
      }
    } catch (e) {
      Get.snackbar("Error", "AI couldn't polish the text: $e");
    } finally {
      isLoading.value = false;
    }
  }

  //Like or Unliked
  var isLiked = false.obs;
  var currentLikeCount = 0.obs;

  Future<void> checkIfLiked(String postId) async {
    isLiked.value = false; // Reset before checking
    try {
      final bool status = await _service.isPostLiked(postId);
      isLiked.value = status;
      print("Like status for $postId: $status"); // Debugging line
    } catch (e) {
      print("Error checking like: $e");
    }
  }

  Future<void> toggleLike(String postId) async {
    if (isLoading.value) return;

    final profileController = Get.find<ProfileController>();
    bool originalLiked = isLiked.value;
    int originalCount = currentLikeCount.value;

    try {
      // 1. Optimistic UI Toggle
      if (isLiked.value) {
        isLiked.value = false;
        currentLikeCount.value--;

        // Remove from profile list
        profileController.likedPosts.removeWhere((p) => p.id == postId);
      } else {
        isLiked.value = true;
        currentLikeCount.value++;

        // Add to profile list
        // Find the post object from main list
        final likedPost = posts.firstWhereOrNull((p) => p.id == postId);
        if (likedPost != null) {
          // Create a copy with the liked status set to true
          final updatedLikedPost = PostModel(
            id: likedPost.id,
            title: likedPost.title,
            content: likedPost.content,
            imageUrl: likedPost.imageUrl,
            user: likedPost.user,
            likeCount: currentLikeCount.value,
            isLiked: true,
          );

          // Add to the beginning of the liked list
          profileController.likedPosts.insert(0, updatedLikedPost);
        }
      }

      // 2. Update the main feed list
      int index = posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        posts[index] = PostModel(
          id: posts[index].id,
          title: posts[index].title,
          content: posts[index].content,
          imageUrl: posts[index].imageUrl,
          user: posts[index].user,
          likeCount: currentLikeCount.value,
          isLiked: isLiked.value,
        );
        posts.refresh();
      }

      // 3. Call Database
      if (originalLiked) {
        await _service.unlikePost(postId);
      } else {
        await _service.likePost(postId);
      }
    } catch (e) {
      // Revert UI on failure
      isLiked.value = originalLiked;
      currentLikeCount.value = originalCount;
      await profileController.fetchLikedPosts(); // Refresh from DB to be sure
    }
  }

  // Shake to Shuffle State
  StreamSubscription? _shakeSubscription;
  DateTime _lastShake = DateTime.now();
  // prevent shakes on other screens
  bool canShake = true;

  // Shake Logic
  void startShakeListener() {
    // If already have a subscription, don't create another one
    if (_shakeSubscription != null) return;

    // Listen to accelerometer events
    _shakeSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Calculate G-force magnitude (sum of absolute values of x, y, and z)
      double acceleration = event.x.abs() + event.y.abs() + event.z.abs();

      // Threshold 30 is a firm shake.
      // Cooldown of 2 seconds prevents multiple popups.
      if (acceleration > 30 && DateTime.now().difference(_lastShake).inSeconds > 2) {
        _lastShake = DateTime.now();
        _showRandomRecipe();
      }
    });
  }

  void _showRandomRecipe() {
    //If not on the main feed, ignore shake
    if (!canShake) return;

    // If a dialog is already open, don't open another one
    if (Get.isDialogOpen == true) return;

    // Only show if actually have posts to shuffle
    if (posts.isEmpty) return;

    // 1. Give the user tactile feedback (Mobile Unique Feature!)
    HapticFeedback.heavyImpact();

    // 2. Select a random post from the list
    final randomPost = (List<PostModel>.from(posts)..shuffle()).first;

    // 3. Show the Surprise Dialog
    Get.defaultDialog(
      title: "Chef's Surprise! 🎲",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: "Feeling lucky? How about cooking: \n\n ${randomPost.title}",
      backgroundColor: Colors.white,
      radius: 15,
      textConfirm: "View Recipe",
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFF00A676),
      onConfirm: () {
        Get.back();
        // Turn off shake while reading the recipe
        canShake = false;
        Get.to(() => PostDetailScreen(post: randomPost))?.then((value) {
          // Turn it back on when return to the feed
          canShake = true;
        });
      },
      textCancel: "Try Again",
      cancelTextColor: Colors.grey,
    );
  }

  @override
  void onClose() {
    titleController.dispose();
    contentController.dispose();
    // Cancel the sensor stream to save battery and prevent memory leaks
    _shakeSubscription?.cancel();
    super.onClose();
  }
}
