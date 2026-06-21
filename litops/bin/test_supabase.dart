import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://gqmyqrnbmutxhjjelhhb.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI',
  );

  print('Initialized Supabase Client');

  try {
    print('Querying event_assignments...');
    final response = await supabase.from('event_assignments').select().limit(1);
    print('Event assignments: $response');
  } catch (e) {
    print('Error querying event_assignments: $e');
  }

  try {
    print('Querying events...');
    final response = await supabase.from('events').select().limit(1);
    print('Events: $response');
  } catch (e) {
    print('Error querying events: $e');
  }

  try {
    print('Querying profiles...');
    final response = await supabase.from('profiles').select().limit(1);
    print('Profiles: $response');
  } catch (e) {
    print('Error querying profiles: $e');
  }
}
