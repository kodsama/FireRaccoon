class FireflyUser {
  final String id;
  final String email;

  const FireflyUser({required this.id, required this.email});

  String get displayName {
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  factory FireflyUser.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>;
    return FireflyUser(
      id: json['id'] as String,
      email: attrs['email'] as String? ?? '',
    );
  }
}
