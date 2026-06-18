import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/supabase/supabase_config.dart';
import 'core/utils/offline_sync_service.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  await Hive.openBox('offline_attendance');
  await Hive.openBox('sync_queue');
  await Hive.openBox('app_settings');

  OfflineSyncService.instance.initialize();

  await SupabaseConfig.initialize();
  await NotificationService().initialize();

  runApp(const ProviderScope(child: LitLifeApp()));
}
