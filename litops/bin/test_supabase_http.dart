import 'dart:io';
import 'dart:convert';

void main() async {
  final client = HttpClient();
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI';

  Future<dynamic> getRequest(String path) async {
    final uri = Uri.parse('https://gqmyqrnbmutxhjjelhhb.supabase.co/rest/v1$path');
    final request = await client.getUrl(uri);
    request.headers.add('apikey', anonKey);
    request.headers.add('Authorization', 'Bearer $anonKey');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body);
  }

  try {
    print('Fetching events with title...');
    final events = await getRequest('/events?select=id,title&limit=1');
    print('Events response: $events');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
