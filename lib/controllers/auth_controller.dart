import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthController extends GetxController {
  final SupabaseService _service = SupabaseService();

  var isLoading = false.obs;
  var isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkUser();
  }

  void checkUser() {
    isLoggedIn.value = _service.currentUser != null;
  }

  Future<void> loginWithGoogle() async {
    try {
      isLoading.value = true;
      await _service.googleSignIn();
      await _service.createProfileIfNotExists();
      checkUser();
    } catch (e) {
      Get.snackbar("Login Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _service.signOut();
    isLoggedIn.value = false;
  }
}
