import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyLocalStorage extends LocalStorage {
  const MyLocalStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<void> persistSession(String session) async {}
  @override
  Future<void> removePersistedSession() async {}
}

void main() {
  test('Check if system_settings table exists', () async {
    await Supabase.initialize(
      url: 'https://gqmyqrnbmutxhjjelhhb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI',
      authOptions: const FlutterAuthClientOptions(
        localStorage: MyLocalStorage(),
      ),
    );
    final client = Supabase.instance.client;
    try {
      final res = await client.from('system_settings').select();
      print('=== DB RESULT ===');
      print(res);
      print('=== END DB RESULT ===');
    } catch (e) {
      print('=== DB ERROR ===');
      print(e);
      print('=== END DB ERROR ===');
    }
  });
}
