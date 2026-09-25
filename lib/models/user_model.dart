class UserModel {
  final String id;
  final String username;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      username: map['username'] ?? 'Anonymous',
      avatarUrl: map['avatar_url'],
    );
  }
}