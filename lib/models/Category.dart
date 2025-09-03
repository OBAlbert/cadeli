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
    // parent can be int or string → normalize to int?
    int? parent;
    final rawParent = json['parent'];
    if (rawParent is num) {
      parent = rawParent.toInt();
    } else if (rawParent is String && rawParent.isNotEmpty) {
      parent = int.tryParse(rawParent);
    }

    // image can be object or string → normalize to String?
    String? imageUrl;
    final img = json['image'];
    if (img is Map) {
      imageUrl = img['src']?.toString();
    } else if (img is String) {
      imageUrl = img;
    }

    return Category(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      parent: parent,
      imageUrl: imageUrl,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, parent: $parent)';
  }
}
