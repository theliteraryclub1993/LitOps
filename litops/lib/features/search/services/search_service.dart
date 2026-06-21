import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';

class SearchService {
  final _client = SupabaseConfig.client;

  // Execute unified fuzzy trigram search via RPC
  Future<List<SearchResult>> executeGlobalSearch(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final List<dynamic> data = await _client.rpc(
        'global_search',
        params: {
          'search_query': query,
          'max_results': 20,
        },
      );

      final results = data.map((e) => SearchResult.fromJson(e as Map<String, dynamic>)).toList();

      // Log search history if user is authenticated
      final userId = _client.auth.currentUser?.id;
      if (userId != null && results.isNotEmpty) {
        _logSearchHistory(userId, query, results.first.resultType, results.length);
      }

      return results;
    } catch (e) {
      print('executeGlobalSearch error: $e');
      return [];
    }
  }

  // Save history log asynchronously
  Future<void> _logSearchHistory(
    String userId,
    String query,
    String? topResultType,
    int count,
  ) async {
    try {
      await _client.from(SupabaseTables.searchHistory).insert({
        'user_id': userId,
        'query': query,
        'result_type': topResultType,
        'result_count': count,
      });
    } catch (_) {
      // Fail silently to prevent search blocking
    }
  }

  // Get user search history logs
  Future<List<SearchHistoryEntry>> getSearchHistory(String userId) async {
    try {
      final List<dynamic> data = await _client
          .from(SupabaseTables.searchHistory)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      return data.map((e) => SearchHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // Clear search history for user
  Future<void> clearSearchHistory(String userId) async {
    try {
      await _client
          .from(SupabaseTables.searchHistory)
          .delete()
          .eq('user_id', userId);
    } catch (_) {}
  }
}
