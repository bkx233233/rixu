import 'package:flutter/material.dart';

import 'core/config/supabase_config.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/setup/presentation/config_required_page.dart';

class RixuApp extends StatelessWidget {
  const RixuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日序',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146C5A)),
        useMaterial3: true,
      ),
      home: SupabaseConfig.isConfigured
          ? const AuthGate()
          : const ConfigRequiredPage(),
    );
  }
}
