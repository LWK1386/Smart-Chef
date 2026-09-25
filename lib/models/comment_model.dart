import 'user_model.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId; // Added this to identify the author
  final String content;
  final UserModel user;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId, // Added
    required this.content,
    required this.user,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    // 1. Grab the profile data
    final profileData = map['profiles'] as Map<String, dynamic>?;

    return CommentModel(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '', // Important for delete logic
      content: map['content'] ?? '',
      // 2. Handle cases where profile might be missing or deleted
      user: profileData != null
          ? UserModel.fromMap(profileData)
          : UserModel(id: '', username: 'Deleted User', avatarUrl: null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
    };
  }
}