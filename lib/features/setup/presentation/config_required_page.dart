import 'package:flutter/material.dart';

class ConfigRequiredPage extends StatelessWidget {
  const ConfigRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日序')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('尚未连接云端项目', style: TextStyle(fontSize: 22)),
              SizedBox(height: 12),
              Text('请在启动命令中提供 SUPABASE_URL 和 SUPABASE_PUBLISHABLE_KEY。'),
            ],
          ),
        ),
      ),
    );
  }
}
