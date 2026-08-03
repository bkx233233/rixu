import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../health/presentation/health_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../schedule/presentation/schedule_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  Future<void> _signOut() => Supabase.instance.client.auth.signOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日序'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      // 保留三个页面的状态，正常切换不再重新请求整页数据。
      body: IndexedStack(
        index: _selectedIndex,
        children: const [SchedulePage(), HealthPage(), ProfilePage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: '日程'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: '健康'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的'),
        ],
      ),
    );
  }
}
