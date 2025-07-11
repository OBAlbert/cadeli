// ✅ Final FIXED ProductDetailPage with no app bars, floating back button, and image fix

import 'dart:ui';
import 'package:cadeli/models/cart_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cadeli/models/product.dart';
import '../widget/app_scaffold.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with SingleTickerProviderStateMixin {
  String selectedSize = "500ml";
  String selectedPackage = "6-Pack";
  int quantity = 1;
  bool isFavorite = false;

  late AnimationController _controller;
  late Animation<Offset> _animationOffset;
  late GlobalKey imageKey;

  @override
  void initState() {
    super.initState();
    imageKey = GlobalKey(debugLabel: 'imageKey_${widget.product.id}');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationOffset = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _checkFavoriteStatus();
    _logRecentlyViewed();
  }

  Future<void> _checkFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.product.id)
          .get();
      if (doc.exists) {
        setState(() => isFavorite = true);
      }
    }
  }

  Future<void> _logRecentlyViewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final recentRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recentlyViewed')
        .doc(widget.product.id);

    await recentRef.set({
      'name': widget.product.name,
      'brand': widget.product.brand,
      'imageUrl': widget.product.imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }


  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.product.id);

    if (isFavorite) {
      await favRef.delete();
    } else {
      await favRef.set({
        'name': widget.product.name,
        'brand': widget.product.brand,
        'imageUrl': widget.product.imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    setState(() => isFavorite = !isFavorite);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void adjustQuantity(bool increase) {
    setState(() {
      if (increase) {
        quantity++;
      } else if (quantity > 1) {
        quantity--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return AppScaffold(
      currentIndex: 1,
      hideNavigationBar: true,
      onTabSelected: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Stack(
        children: [
          // ✅ Main card container — fully visible, no scroll
          Align(
            alignment: Alignment.center,
            child: SlideTransition(
              position: _animationOffset,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height - 180, // Leaves space for add-to-cart button
                  ),
                  margin: const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 90),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 12)),
                      BoxShadow(color: Colors.white24, offset: Offset(0, -2), blurRadius: 4),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            p.imageUrl,
                            key: imageKey,
                            height: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                height: 200,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.brand,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '€${p.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        _buildLabeledSection("Select Size", p.sizeOptions, selectedSize, (val) => setState(() => selectedSize = val)),
                        const SizedBox(height: 12),
                        _buildLabeledSection("Select Package", p.packOptions, selectedPackage, (val) => setState(() => selectedPackage = val)),
                        const SizedBox(height: 20),
                        const Text("Quantity", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(icon: const Icon(Icons.remove, size: 22, color: Colors.black), onPressed: () => adjustQuantity(false)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                            IconButton(icon: const Icon(Icons.add, size: 22, color: Colors.black), onPressed: () => adjustQuantity(true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _toggleFavorite,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.redAccent : Colors.black38,
                                size: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isFavorite ? 'Favorited' : 'Add to Favorites',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),



          // ⬅ Floating back button


          // Glassy floating back button under app bar

          Positioned(
            top: MediaQuery.of(context).padding.top - 40, // ⬅ Tighter padding
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 14, color: Colors.black87),
                        SizedBox(width: 6),
                        Text("Back to Products", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ⬅ Add to cart button floating above nav bar
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                final cart = Provider.of<CartProvider>(context, listen: false);
                cart.addToCart(widget.product, selectedSize, selectedPackage, quantity);

                final imageBox = imageKey.currentContext?.findRenderObject() as RenderBox?;
                final cartBox = findCartIconRenderBox(context);

                if (imageBox != null && cartBox != null) {
                  final imagePosition = imageBox.localToGlobal(Offset.zero);
                  final cartPosition = cartBox.localToGlobal(Offset.zero);

                  final overlay = Overlay.of(context);
                  final entry = OverlayEntry(
                    builder: (context) {
                      return _FlyingImageAnimation(
                        imageUrl: widget.product.imageUrl,
                        start: imagePosition,
                        end: cartPosition,
                      );
                    },
                  );

                  overlay.insert(entry);
                  await Future.delayed(const Duration(milliseconds: 800));
                  entry.remove();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Added to cart")),
                );
              },
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double scale = 1 + (_controller.value * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: const Color(0xFF1A2D3D),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            offset: Offset(0, 10),
                            blurRadius: 22,
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart, color: Colors.white),
                          SizedBox(width: 10),
                          Text("Add to Cart", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledSection(String label, List<String> options, String selected, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: options.map((value) {
            return ChoiceChip(
              label: Text(value),
              selected: selected == value,
              onSelected: (_) => onChanged(value),
              selectedColor: const Color(0xFF1A2D3D),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(color: selected == value ? Colors.white : Colors.black87),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black12.withOpacity(0.2)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  RenderBox? findCartIconRenderBox(BuildContext context) {
    RenderBox? found;
    void search(Element element) {
      if (element.widget is IconButton && (element.widget as IconButton).tooltip == "Cart") {
        final renderObject = element.renderObject;
        if (renderObject is RenderBox) {
          found = renderObject;
        }
      }
      element.visitChildren(search);
    }
    context.visitChildElements(search);
    return found;
  }
}

class _FlyingImageAnimation extends StatefulWidget {
  final String imageUrl;
  final Offset start;
  final Offset end;

  const _FlyingImageAnimation({required this.imageUrl, required this.start, required this.end});

  @override
  State<_FlyingImageAnimation> createState() => _FlyingImageAnimationState();
}

class _FlyingImageAnimationState extends State<_FlyingImageAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _position = Tween<Offset>(begin: widget.start, end: widget.end).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Positioned(
          top: _position.value.dy,
          left: _position.value.dx,
          child: child!,
        );
      },
      child: Image.asset('assets/products/${widget.imageUrl}', height: 40, width: 40),
    );
  }
}
