import 'package:flutter/material.dart';
import 'admin_pending_orders.dart';
import 'admin_active_orders.dart';
import 'admin_order_history.dart';



class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> myTabs = const [
    Tab(text: 'Pending'),
    Tab(text: 'Active'),
    Tab(text: 'History'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: myTabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD2E4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2D3D),
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          tabs: myTabs,
          indicatorColor: Colors.lightBlueAccent,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PendingOrdersPage(),
          ActiveOrdersPage(),
          OrderHistoryPage(),
        ],
      ),
    );
  }
}
