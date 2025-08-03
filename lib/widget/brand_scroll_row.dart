import 'package:flutter/material.dart';

class BrandScrollRow extends StatelessWidget {
  final List<Map<String, dynamic>> brandData;
  final String? selectedBrandId;
  final Function(String brandId) onBrandTap;

  const BrandScrollRow({
    super.key,
    required this.brandData,
    required this.onBrandTap,
    this.selectedBrandId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100, // Slightly taller to accommodate box styling
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: brandData.length,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemBuilder: (context, index) {
          final brand = brandData[index];
          final isSelected = brand['id'] == selectedBrandId;

          return GestureDetector(
            onTap: () {
              // Toggle selection - tap selected brand to deselect
              if (isSelected) {
                onBrandTap(''); // Send empty string to indicate "show all"
              } else {
                onBrandTap(brand['id']?.toString() ?? '');
              }
            },
            child: Container(
              width: 80, // Slightly wider for better spacing
              margin: const EdgeInsets.only(right:4),
              child: Column(
                children: [
                  // Brand logo container with black border
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8), // Rectangular with slight rounding
                      border: Border.all(
                        color: Colors.black, // Black outline
                        width: 1,
                      ),
                      color: isSelected ? Colors.blue[50] : Colors.white, // Light blue when selected
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6), // Inner padding
                      child: brand['image'] != null && brand['image'].isNotEmpty
                          ? Image.network(
                        brand['image'],
                        fit: BoxFit.contain,
                      )
                          : Center(
                        child: Text(
                          brand['name']?.substring(0, 2) ?? 'BR',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                ],
              ),
            ),
          );
        },
      ),
    );
  }
}