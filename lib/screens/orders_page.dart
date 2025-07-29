import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A233D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: Color(0xFF1A233D),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A233D),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1A233D),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList('pending', 'processing', 'out_for_delivery'),
          _buildOrdersList('delivered', 'completed'),
          _buildOrdersList('cancelled'),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String status1, [String? status2, String? status3]) {
    List<String> statuses = [status1];
    if (status2 != null) statuses.add(status2);
    if (status3 != null) statuses.add(status3);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login to view orders'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('uid', isEqualTo: user.uid)
          .where('status', whereIn: statuses)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No orders found', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final order = snapshot.data!.docs[index];
            final orderData = order.data() as Map<String, dynamic>;
            return _buildOrderCard(orderData, order.id);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> orderData, String orderId) {
    final timestamp = orderData['timestamp'] as Timestamp?;
    final items = orderData['items'] as List<dynamic>? ?? [];
    final status = orderData['status'] ?? 'pending';
    final total = orderData['totalCost'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${orderId.substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A233D),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            if (timestamp != null)
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate()),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            const SizedBox(height: 12),
            ...items.take(2).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: const Icon(Icons.water_drop, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Water Bottle',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${item['quantity']}x • €${item['price']}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            if (items.length > 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '+${items.length - 2} more items',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: €${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A233D),
                  ),
                ),
                if (status == 'pending' || status == 'processing')
                  ElevatedButton(
                    onPressed: () => _showOrderDetails(orderData, orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A233D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('Track Order', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String displayText;
    
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        displayText = 'Pending';
        break;
      case 'processing':
        color = Colors.blue;
        displayText = 'Preparing';
        break;
      case 'out_for_delivery':
        color = Colors.purple;
        displayText = 'Out for Delivery';
        break;
      case 'delivered':
      case 'completed':
        color = Colors.green;
        displayText = 'Delivered';
        break;
      case 'cancelled':
        color = Colors.red;
        displayText = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> orderData, String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Order #${orderId.substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A233D),
                  ),
                ),
                const SizedBox(height: 20),
                _buildOrderTrackingSteps(orderData['status']),
                const SizedBox(height: 20),
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A233D),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: (orderData['items'] as List).length,
                    itemBuilder: (context, index) {
                      final item = (orderData['items'] as List)[index];
                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: const Icon(Icons.water_drop, color: Colors.blue),
                        ),
                        title: Text(item['name'] ?? 'Water Bottle'),
                        subtitle: Text('${item['quantity']}x • €${item['price']}'),
                        trailing: Text(
                          '€${(item['quantity'] * item['price']).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A233D),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderTrackingSteps(String currentStatus) {
    final steps = [
      {'status': 'pending', 'title': 'Order Placed', 'icon': Icons.receipt},
      {'status': 'processing', 'title': 'Preparing', 'icon': Icons.inventory},
      {'status': 'out_for_delivery', 'title': 'Out for Delivery', 'icon': Icons.local_shipping},
      {'status': 'delivered', 'title': 'Delivered', 'icon': Icons.check_circle},
    ];

    int currentIndex = steps.indexWhere((step) => step['status'] == currentStatus);
    if (currentIndex == -1) currentIndex = 0;

    return Column(
      children: steps.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> step = entry.value;
        bool isCompleted = index <= currentIndex;
        bool isCurrent = index == currentIndex;

        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF1A233D) : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                step['icon'] as IconData,
                color: isCompleted ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title'] as String,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? const Color(0xFF1A233D) : Colors.grey,
                    ),
                  ),
                  if (index < steps.length - 1)
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      height: 30,
                      width: 2,
                      color: isCompleted ? const Color(0xFF1A233D) : Colors.grey.shade200,
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
