class Product {
  final String name;
  final String brand;
  final String imagePath;
  final List<String> sizes;
  final List<String> packages;
  int quantity;

  Product({
    required this.name,
    required this.brand,
    required this.imagePath,
    this.sizes = const ["500ml", "1.5L"],
    this.packages = const ["Single", "6-Pack"],
    this.quantity = 1,
  });
}
