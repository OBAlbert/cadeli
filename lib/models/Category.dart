class Category {
  final int id;
  final String name;
  final String slug;
  final int? parent;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.parent,
    this.imageUrl,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      parent: json['parent'] is int ? json['parent'] : null,
      imageUrl: json['image'] != null ? json['image']['src'] : null,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, parent: $parent)';
  }
}
