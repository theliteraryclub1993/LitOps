import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://gqmyqrnbmutxhjjelhhb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI',
  );
  
  final client = Supabase.instance.client;
  print('Signing in as theliteraryclubmce@gmail.com...');
  final response = await client.auth.signInWithPassword(
    email: 'theliteraryclubmce@gmail.com',
    password: 'Malnad2K27',
  );
  
  final userId = response.user?.id;
  if (userId == null) {
    print('Failed to sign in.');
    return;
  }
  print('Logged in successfully. User ID: $userId');
  
  print('Updating role in profiles table to super_admin...');
  final updateResult = await client
      .from('profiles')
      .update({'role': 'super_admin'})
      .eq('id', userId)
      .select();
      
  print('Update result: $updateResult');
  
  print('Sign out...');
  await client.auth.signOut();
  print('Done!');
}
