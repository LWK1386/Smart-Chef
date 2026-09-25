import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gemini_service.dart';
import '../../theme/colors.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

typedef _C = C;

class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({super.key});

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

class _FoodCameraScreenState extends State<FoodCameraScreen> {
  bool _isAnalyzing = false;
  String _statusText = 'Take a photo of your food';

  Future<Map<String, String?>> _saveImageBoth(Uint8List bytes) async {
    String? localPath;
    String? remoteUrl;

    // 1 — Save locally
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'food_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      localPath = file.path;
      print('=== IMAGE SAVED LOCALLY: $localPath ===');
    } catch (e) {
      print('=== LOCAL SAVE ERROR: $e ===');
    }

    // 2 — Upload to Supabase Storage
    try {
      final client = Supabase.instance.client;
      final fileName = 'food_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'uploads/$fileName';

      await client.storage
          .from('food-images')
          .uploadBinary(storagePath, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));

      remoteUrl = client.storage
          .from('food-images')
          .getPublicUrl(storagePath);

      print('=== IMAGE UPLOADED TO SUPABASE: $remoteUrl ===');
    } catch (e) {
      print('=== SUPABASE UPLOAD ERROR: $e ===');
    }

    return {'localPath': localPath, 'remoteUrl': remoteUrl};
  }

  Future<void> _captureAndAnalyze() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Analyzing food with AI...';
    });

    try {
      final Uint8List bytes = await photo.readAsBytes();
      final paths = await _saveImageBoth(bytes);
      final String? savedPath = paths['localPath'];
      final String? savedUrl = paths['remoteUrl'];
      final Map<String, dynamic>? result =
      await GeminiService.analyzeFoodImage(bytes);

      // Check for error responses from Gemini
      if (result == null) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not analyze image. Try again.';
        });
        Get.snackbar(
          '❌ Analysis Failed',
          'Something went wrong. Please try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.black,
        );
        return;
      }

      // Gemini said it's not food
      if (result['error'] == 'not_food') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'No food detected. Try again.';
        });
        Get.snackbar(
          '🚫 Not Food',
          'No food detected in the photo. Please take a photo of food.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.black,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Gemini said image is unclear
      if (result['error'] == 'unclear') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Image too unclear. Try again.';
        });
        Get.snackbar(
          '📷 Unclear Photo',
          'Image is too blurry or dark. Try better lighting.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          colorText: Colors.black,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Success — return food data to add_meal_controller
      if (result.containsKey('food_name')) {
        result['image_path'] = savedPath;
        result['image_url'] = savedUrl;
        Get.back(result: result);
      } else {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not identify food. Try again.';
        });
        Get.snackbar(
          '❌ Unknown Food',
          'Could not identify the food. Try a clearer photo.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.black,
        );
      }

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusText = 'Something went wrong. Try again.';
      });
      Get.snackbar(
        '❌ Error',
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.black,
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (photo == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Analyzing food with AI...';
    });

    try {
      final Uint8List bytes = await photo.readAsBytes();
      final paths = await _saveImageBoth(bytes);
      final String? savedPath = paths['localPath'];
      final String? savedUrl = paths['remoteUrl'];
      final Map<String, dynamic>? result =
      await GeminiService.analyzeFoodImage(bytes);

      if (result == null) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not analyze image. Try again.';
        });
        Get.snackbar('❌ Analysis Failed', 'Something went wrong. Please try again.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            colorText: Colors.black);
        return;
      }

      if (result['error'] == 'not_food') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'No food detected. Try again.';
        });
        Get.snackbar('🚫 Not Food', 'No food detected. Please select a food photo.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.withValues(alpha: 0.8),
            colorText: Colors.black,
            duration: const Duration(seconds: 3));
        return;
      }

      if (result['error'] == 'unclear') {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Image too unclear. Try again.';
        });
        Get.snackbar('📷 Unclear Photo', 'Image is too blurry or dark.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.withValues(alpha: 0.8),
            colorText: Colors.black,
            duration: const Duration(seconds: 3));
        return;
      }

      if (result.containsKey('food_name')) {
        result['image_path'] = savedPath;
        result['image_url'] = savedUrl;
        Get.back(result: result);
      } else {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Could not identify food. Try again.';
        });
        Get.snackbar('❌ Unknown Food', 'Could not identify the food.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            colorText: Colors.black);
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusText = 'Something went wrong. Try again.';
      });
      Get.snackbar('❌ Error', e.toString(), snackPosition: SnackPosition.TOP);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Get.back(),
                  ),
                  const Text(
                    'AI Food Scanner',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 40), // balance the row
                ],
              ),
            ),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon / loading indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isAnalyzing
                      ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      color: _C.primary,
                      strokeWidth: 3,
                    ),
                  )
                      : Container(
                    key: const ValueKey('icon'),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _C.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _C.primary.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: _C.primary,
                      size: 52,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Status text
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Smart Chef AI will identify the food\nand estimate its calories & macros',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black, fontSize: 13),
                ),

                const SizedBox(height: 48),

                // Main capture button
                if (!_isAnalyzing)
                  GestureDetector(
                    onTap: _captureAndAnalyze,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: _C.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _C.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.black, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Take Photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_isAnalyzing) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.primary),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_rounded, color: Colors.black, size: 20),
                          SizedBox(width: 10),
                          Text('Choose from Gallery',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom manual entry button
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.edit_rounded, color: Colors.black, size: 16),
                label: const Text(
                  'Enter manually instead',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}