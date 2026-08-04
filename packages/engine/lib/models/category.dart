class Category {
  final String id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    return Category(
      id: json['id'] as String,
      name: attrs['name'] as String? ?? 'Unnamed',
    );
  }
}
