import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart' as date_data;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/notifications/schedule_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await date_data.initializeDateFormatting('zh_CN');

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.apiKey,
    );
  }
  if (!kIsWeb) {
    await ScheduleNotificationService.instance.initialize();
  }

  runApp(const RixuApp());
}
