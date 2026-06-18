import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';

class AuthRepository {
  final _client = SupabaseConfig.client;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp(String email, String password, String fullName, DateTime dob) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'date_of_birth': dob.toIso8601String().split('T').first,
      },
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Profile> getProfile(String userId) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client
        .from(SupabaseTables.profiles)
        .update(data)
        .eq('id', userId);
  }

  Future<bool> verifyDateOfBirth(String userId, DateTime dob) async {
    try {
      final data = await _client
          .from(SupabaseTables.profiles)
          .select('date_of_birth')
          .eq('id', userId)
          .single();

      final storedDob = data['date_of_birth'] as String?;
      if (storedDob == null) return true; // No DOB set, skip verification

      final storedDate = DateTime.parse(storedDob);
      return storedDate.year == dob.year &&
          storedDate.month == dob.month &&
          storedDate.day == dob.day;
    } catch (_) {
      return false;
    }
  }

  Future<bool> preAuthVerifyDob(String email, DateTime dob) async {
    try {
      final dobStr = dob.toIso8601String().split('T').first;
      final List<dynamic> data = await _client.rpc(
        'verify_user_dob',
        params: {
          'p_email': email,
          'p_dob': dobStr,
        },
      );
      return data.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  String? get currentUserId => _client.auth.currentUser?.id;
}
