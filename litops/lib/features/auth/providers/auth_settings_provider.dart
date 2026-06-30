import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

class AuthSettings {
  final bool signInEnabled;
  final bool registrationEnabled;
  final String signInDisabledMessage;

  const AuthSettings({
    this.signInEnabled = true,
    this.registrationEnabled = true,
    this.signInDisabledMessage = defaultSignInDisabledMessage,
  });

  static const defaultSignInDisabledMessage =
      'Sign-in is temporarily disabled while we resolve authentication issues. Please try again later.';

  factory AuthSettings.fromRows(List<dynamic> rows) {
    final map = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return AuthSettings(
      signInEnabled: map['sign_in_enabled'] != 'false',
      registrationEnabled: map['registration_enabled'] != 'false',
      signInDisabledMessage: map['sign_in_disabled_message']?.trim().isNotEmpty == true
          ? map['sign_in_disabled_message']!.trim()
          : defaultSignInDisabledMessage,
    );
  }
}

Future<AuthSettings> fetchAuthSettings() async {
  final data = await SupabaseConfig.client.from(SupabaseTables.appSettings).select();
  if (data.isEmpty) return const AuthSettings();
  return AuthSettings.fromRows(data);
}

final _appSettingsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return SupabaseConfig.client
      .from(SupabaseTables.appSettings)
      .stream(primaryKey: ['key'])
      .map((rows) => rows.cast<Map<String, dynamic>>());
});

/// Live auth gate settings (sign-in, registration, maintenance message).
final authSettingsProvider = FutureProvider<AuthSettings>((ref) async {
  ref.watch(_appSettingsStreamProvider);
  try {
    return await fetchAuthSettings();
  } catch (e) {
    debugPrint('Error fetching auth settings: $e');
    return const AuthSettings();
  }
});

/// Returns `true` when sign-in is allowed for regular users.
final signInEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = await ref.watch(authSettingsProvider.future);
  return settings.signInEnabled;
});

/// Returns `true` when new user sign-ups are allowed.
final registrationEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = await ref.watch(authSettingsProvider.future);
  return settings.registrationEnabled;
});

Future<void> upsertAppSetting(String key, String value) async {
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  await SupabaseConfig.client.from(SupabaseTables.appSettings).upsert({
    'key': key,
    'value': value,
    'updated_at': DateTime.now().toIso8601String(),
    if (userId != null) 'updated_by': userId,
  }, onConflict: 'key');
}
