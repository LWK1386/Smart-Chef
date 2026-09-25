import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '/controllers/post_controller.dart';
import '/models/post_model.dart'; // Ensure this is imported

class CreatePostScreen extends StatefulWidget {
  final PostModel? editPost; // Null = Create Mode, Not Null = Edit Mode
  const CreatePostScreen({super.key, this.editPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PostController controller = Get.find<PostController>();

  // Helper to check mode
  bool get isEditing => widget.editPost != null;

  @override
  void initState() {
    super.initState();
    // 1. If we are editing, pre-fill the controller
    if (isEditing) {
      controller.titleController.text = widget.editPost!.title;
      controller.contentController.text = widget.editPost!.content;
      // Note: We don't set selectedImage here because that's for local files
    } else {
      // 2. Clear controller for a fresh new post
      controller.titleController.clear();
      controller.contentController.clear();
      controller.selectedImage.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Recipe" : "Share Recipe",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            // Clear data before leaving so it doesn't leak into the next session
            controller.selectedImage.value = null;
            Get.back();
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (isEditing) {
                await controller.updatePost(widget.editPost!.id);
                Get.back(); // Close Edit Screen
                Get.back(); // Close Detail Screen
                Get.snackbar("Success", "Recipe updated!");
              } else {
                // This will now trigger Gemini review inside the controller
                await controller.submitPost();
                // Note: We don't call Get.back() here because submitPost
                // handles it after a successful AI review.
              }
            },
            child: Text(
              isEditing ? "Save" : "Publish",
              style: const TextStyle(
                color: Color(0xFF00A676),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Obx(
            () => controller.isLoading.value
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00A676)),
              const SizedBox(height: 20),
              // Dynamic loading text
              Text(
                isEditing ? "Updating recipe..." : "SmartChef AI is reviewing your recipe...",
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- IMAGE AREA ---
                    Obx(() {
                      // Case 1: A new local image was picked (Only happens during Create Mode)
                      if (controller.selectedImage.value != null) {
                        return _buildImageWrapper(
                          Image.file(
                            controller.selectedImage.value!,
                            fit: BoxFit.cover,
                          ),
                          onClose: () => controller.selectedImage.value = null,
                          showControls:
                              !isEditing, // Hide controls if we are editing
                        );
                      }
                      // Case 2: We are editing an existing post - Show static Network Image
                      else if (isEditing && widget.editPost!.imageUrl != null) {
                        return _buildImageWrapper(
                          Image.network(
                            widget.editPost!.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                          showControls:
                              false, // Absolutely no edit/close buttons
                        );
                      }
                      // Case 3: Create Mode Placeholder
                      else {
                        return GestureDetector(
                          onTap: () => _showPickerOptions(context, controller),
                          child: _buildPlaceholder(),
                        );
                      }
                    }),
                    const SizedBox(height: 24),

                    // --- TITLE ---
                    TextField(
                      controller: controller.titleController,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Recipe title...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const Divider(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => controller.enhanceWithAI(),
                          icon: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF00A676)),
                          label: const Text(
                              "AI Polish",
                              style: TextStyle(color: Color(0xFF00A676), fontWeight: FontWeight.bold)
                          ),
                        ),
                      ],
                    ),

                    // --- CONTENT ---
                    TextField(
                      controller: controller.contentController,
                      maxLines: 10,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Ingredients and steps...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildImageWrapper(
    Widget imageWidget, {
    VoidCallback? onClose,
    bool showControls = true,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 250,
            width: double.infinity,
            child: imageWidget,
          ),
        ),
        // Only show the close/edit buttons if showControls is true
        if (showControls)
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                _buildCircleIcon(
                  Icons.edit,
                  () => _showPickerOptions(context, controller),
                ),
                const SizedBox(width: 8),
                if (onClose != null) _buildCircleIcon(Icons.close, onClose),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7F1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF00A676).withOpacity(0.3)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_rounded,
            size: 50,
            color: Color(0xFF00A676),
          ),
          SizedBox(height: 10),
          Text(
            "Add a photo of your dish",
            style: TextStyle(color: Color(0xFF00A676)),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.black.withOpacity(0.5),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  void _showPickerOptions(BuildContext context, PostController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00A676)),
              title: const Text('Take a Photo'),
              onTap: () {
                Get.back();
                controller.pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF00A676),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Get.back();
                controller.pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
