import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // AUTH SECTION
  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> googleSignIn() async {
    const webClientId =
        '222115080204-3t6fvq4d5ahth5eua6les249d5vomhfa.apps.googleusercontent.com';

    final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: webClientId);

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      throw 'Sign in aborted by user';
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw 'No ID Token found.';
    }

    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // PROFILE SECTION
  Future<void> createProfileIfNotExists() async {
    final user = currentUser;
    if (user == null) return;

    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from('profiles').insert({
        'id': user.id,
        'username': user.userMetadata?['full_name'],
        'avatar_url': user.userMetadata?['avatar_url'],
      });
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    return await _client.from('profiles').select().eq('id', user.id).single();
  }

  /// Updated: allows uploading an avatar file
  Future<void> updateProfile({
    required String username,
    File? avatarFile,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final data = {'username': username};

    if (avatarFile != null) {
      // This path matches your screenshot folder
      final fileName = 'profiles/${user.id}.png';

      final avatarUrl = await uploadImage(
        avatarFile,
        fileName,
      );

      if (avatarUrl != null) {
        // Add a timestamp here to force the UI to refresh immediately
        data['avatar_url'] = "$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      }
    }

    await _client.from('profiles').update(data).eq('id', user.id);
  }

  // POSTS SECTION
  // Create post with optional image
  Future<void> createPost({
    required String title,
    required String content,
    File? imageFile,
  }) async {
    String? imageUrl;

    if (imageFile != null) {
      imageUrl = await uploadImage(
        imageFile,
        'posts/${DateTime.now().millisecondsSinceEpoch}_${currentUser?.id ?? 'anon'}.png',
      );
    }

    await _client.from('posts').insert({
      'user_id': currentUser!.id,
      'title': title,
      'content': content,
      'image_url': imageUrl,
    });
  }

  //Update Post
  Future<void> updatePost({
    required String postId,
    required String title,
    required String content,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    await _client
        .from('posts')
        .update({
      'title': title,
      'content': content,
    })
        .eq('id', postId)
        .eq('user_id', user.id); // Security: ensure user owns the post
  }

  // Fetch posts
  Future<List<dynamic>> fetchPosts() async {
    return await _client
        .from('posts')
        .select('''
        *, 
        profiles!posts_user_id_fkey(username, avatar_url),
        likes(user_id) 
      ''') // Changed from 'count' to 'user_id' so we can check 'isLiked'
        .order('created_at', ascending: false);
  }

  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  // Upload image to Supabase Storage
  Future<String?> uploadImage(File file, String path) async {
    try {
      final response = await _client.storage.from('posts_images').upload(
        path,
        file,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'image/png',
          metadata: {
            'user_id': _client.auth.currentUser!.id, // store owner ID
          },
        ),
      );

      // Get public URL
      final url = _client.storage.from('posts_images').getPublicUrl(path);
      return url;
    } catch (e) {
      print("Upload Image Error: $e");
      return null;
    }
  }

  // COMMENTS SECTION
  Future<List<dynamic>> fetchComments(String postId) async {
    return await _client
        .from('comments')
        .select('*, profiles(username, avatar_url)') // Make sure this join is here!
        .eq('post_id', postId)
        .order('created_at', ascending: false);
  }

  Future<void> addComment(String postId, String content) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }

  // LIKE SECTION
  Future<bool> isPostLiked(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final response = await _client
        .from('likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response != null;
  }

// Add a like
  Future<void> likePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('likes').insert({
      'post_id': postId,
      'user_id': user.id,
    });
  }

// Remove a like
  Future<void> unlikePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', user.id);
  }

  Future<int> getLikeCount(String postId) async {
    final result = await _client.from('likes').select().eq('post_id', postId);
    return result.length;
  }

  Future<List<dynamic>> fetchLikedPosts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    // select from 'likes', then reach into 'posts',
    // then reach into 'profiles' (the owner) and 'likes' (the count)
    final response = await _client
        .from('likes')
        .select('''
        posts (
          id,
          title,
          content,
          image_url,
          user_id,
          created_at,
          profiles:user_id (id, username, avatar_url),
          likes (user_id)
        )
      ''')
        .eq('user_id', user.id);

    return response as List<dynamic>;
  }

  // ==========================
  // FAVORITE RECIPES SECTION
  // ==========================
  Stream<List<Map<String, dynamic>>> favoritesStream() {

    final user = currentUser;

    return _client
        .from('favorite_recipes')
        .stream(primaryKey: ['id'])
        .eq('user_id', user!.id)
        .order('created_at');
  }

  Future<bool> isFavorite(String recipeId) async {

    final user = currentUser;
    if (user == null) return false;

    final response = await _client
        .from('favorite_recipes')
        .select()
        .eq('recipe_id', recipeId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response != null;
  }

  Future<void> addFavorite({
    required String recipeId,
    required String title,
    required String image,
    required String kcal,
    required String duration,
    required String ingredients,
    required String steps,
  }) async {

    final user = currentUser;
    if (user == null) return;

    await _client.from('favorite_recipes').insert({
      'user_id': user.id,
      'recipe_id': recipeId,
      'title': title,
      'image': image,
      'kcal': kcal,
      'duration': duration,
      'ingredients': ingredients,
      'steps': steps,
    });
  }

  Future<void> removeFavorite(String recipeId) async {

    final user = currentUser;
    if (user == null) return;

    await _client
        .from('favorite_recipes')
        .delete()
        .eq('recipe_id', recipeId)
        .eq('user_id', user.id);
  }

  Future<List<dynamic>> fetchFavorites() async {

    final user = currentUser;
    if (user == null) return [];

    return await _client
        .from('favorite_recipes')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }

// Saved Meal Section
  Future<void> saveMealToCloud({
    required String recipeId,
    required String title,
    required String kcal,
    required String imageUrl,
    required String ingredients,
    required String steps,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _client.from('saved_planner_meals').upsert({
      'user_id': user.id,
      'recipe_id': recipeId,
      'title': title,
      'kcal': kcal,
      'image_url': imageUrl,
      'ingredients': ingredients,
      'steps': steps,
    }, onConflict: 'recipe_id, user_id'); // This ensures it updates the specific meal for this user
  }

  // --- MEAL PLANNER CLOUD SYNC ---

  // Check if this specific meal ID is already in your Cloud Planner
  Future<bool> isMealSavedInCloud(String recipeId) async {
    final user = currentUser;
    if (user == null) return false;

    final response = await _client
        .from('saved_planner_meals')
        .select('id')
        .eq('recipe_id', recipeId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response != null;
  }

  // Remove the meal from the Cloud Planner
  Future<void> removeMealFromCloud(String recipeId) async {
    final user = currentUser;
    if (user == null) return;

    await _client
        .from('saved_planner_meals')
        .delete()
        .eq('recipe_id', recipeId)
        .eq('user_id', user.id);
  }

  Future<List<Map<String, dynamic>>> fetchSavedMeals() async {
    final user = currentUser;
    if (user == null) return [];

    // This matches the 'saved_planner_meals' table created earlier
    return await _client
        .from('saved_planner_meals')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }
}
