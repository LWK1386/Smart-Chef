// lib/models/ai_caption_model.dart
class AICaptionModel {
  final String postId;
  final String caption;
  final List<String>? tags;

  AICaptionModel({
    required this.postId,
    required this.caption,
    this.tags,
  });

  factory AICaptionModel.fromJson(Map<String, dynamic> json) => AICaptionModel(
    postId: json['postId'],
    caption: json['caption'],
    tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
  );

  Map<String, dynamic> toJson() => {
    'postId': postId,
    'caption': caption,
    'tags': tags,
  };
}
