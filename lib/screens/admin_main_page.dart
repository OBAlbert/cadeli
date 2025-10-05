import 'package:flutter/material.dart';
import '../widget/app_scaffold.dart';
import 'home_page.dart';
import 'products_page.dart';
import 'chat_list_page.dart';
import 'admin_dashboard.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});
  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _index = 0;

  void _onTabSelected(int i) async {
    if (i==3){
      final r=await Navigator.push(
          context, MaterialPageRoute(builder:(_)=>const AdminDashboard()));
      if(r=='home') setState(()=>_index=0); return; }
    setState(()=>_index=i); }

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomePage(),
      ProductsPage(),
      ChatListPage(isAdmin: true),
    ];

    return AppScaffold(
      currentIndex: _index,
      onTabSelected: _onTabSelected,
      isAdmin: true,                 // show Admin tab
      hideAppBar: false,             // keep glass header
      showAddressDropdown: true,     // same look as customer shell
      child: IndexedStack(index: _index, children: pages),
    );
  }
}
