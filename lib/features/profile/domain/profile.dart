class Profile {
  const Profile({
    required this.id,
    required this.phone,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    required this.lastSeenAt,
  });

  final String id;
  final String phone;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final DateTime lastSeenAt;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    phone: json['phone'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
  );
}
