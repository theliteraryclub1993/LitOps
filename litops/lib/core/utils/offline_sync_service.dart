import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../supabase/supabase_config.dart';
import '../supabase/supabase_tables.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._();
  OfflineSyncService._();

  bool _isSyncing = false;
  StreamSubscription? _subscription;

  void initialize() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        syncOfflineRecords();
      }
    });
  }

  Future<void> syncOfflineRecords() async {
    if (_isSyncing) return;
    final box = Hive.box('offline_attendance');
    if (box.isEmpty) return;

    _isSyncing = true;
    final keysToDelete = [];

    for (var key in box.keys) {
      final record = box.get(key);
      if (record != null) {
        try {
          await SupabaseConfig.client.from(SupabaseTables.attendance).insert({
            'event_id': record['event_id'],
            'registration_id': record['registration_id'],
            'student_id': record['student_id'],
            'marked_by': record['marked_by'],
            'method': record['method'] ?? 'barcode',
            'is_offline': true,
            'synced_at': DateTime.now().toIso8601String(),
          });
          keysToDelete.add(key);
        } catch (_) {
          // If insert fails (e.g., uniqueness constraint or database issue), 
          // we should handle it. If it's a unique constraint error (already marked),
          // we can delete it from queue to avoid blocking other records.
        }
      }
    }

    for (var key in keysToDelete) {
      await box.delete(key);
    }
    _isSyncing = false;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
