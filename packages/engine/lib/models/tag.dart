class Tag {
  final String id;
  final String name;

  const Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    return Tag(
      id: json['id'] as String,
      name: attrs['tag'] as String? ?? attrs['name'] as String? ?? '',
    );
  }
}
