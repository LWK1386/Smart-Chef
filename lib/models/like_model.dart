import 'post_model.dart';
import 'user_model.dart';

class LikeModel {
  final String id;
  final String postId;
  final UserModel user;
  final PostModel? post;

  LikeModel({
    required this.id,
    required this.postId,
    required this.user,
    this.post,
  });

  factory LikeModel.fromMap(Map<String, dynamic> map) {
    return LikeModel(
      id: map['id'].toString(),
      postId: map['post_id'].toString(),
      user: UserModel.fromMap(map['profiles'] ?? {}),
      post: map['posts'] != null ? PostModel.fromMap(map['posts']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': user.id,
    };
  }
}
