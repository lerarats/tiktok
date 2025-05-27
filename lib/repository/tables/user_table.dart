class CustomUser {
  final String id;
  final String userName;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profileImageUrl;

  CustomUser({
    required this.id,
    required this.userName,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.profileImageUrl,
  });

  factory CustomUser.fromJson(Map<String, dynamic> json) {
    return CustomUser(
      id: json['id'],
      userName: json['user_name'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      profileImageUrl: json['profile_image_url'],
    );
  }
}