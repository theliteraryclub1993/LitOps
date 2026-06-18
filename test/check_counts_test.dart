import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('check counts', () async {
    print('Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://gqmyqrnbmutxhjjelhhb.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI',
    );
    
    final client = Supabase.instance.client;
    try {
      final profiles = await client.from('profiles').select('id');
      final activeProfiles = await client.from('profiles').select('id').eq('is_active', true);
      final students = await client.from('student_master').select('id');
      final registrations = await client.from('registrations').select('id, student_id').eq('is_cancelled', false);
      
      print('Total Profiles: ${profiles.length}');
      print('Active Profiles: ${activeProfiles.length}');
      print('Total Students in Master: ${students.length}');
      print('Active Registrations: ${registrations.length}');
      
      final uniqueRegs = (registrations as List).map((r) => r['student_id']).toSet().length;
      print('Unique Registered Students: $uniqueRegs');
    } catch (e) {
      print('Error checking counts: $e');
    }
  });
}
