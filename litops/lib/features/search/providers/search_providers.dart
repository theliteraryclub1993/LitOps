import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/search_service.dart';
import '../../../core/models/models.dart';

final searchServiceProvider = Provider((ref) => SearchService());

final searchQueryProvider = StateProvider<String>((ref) => '');

// Debounced fuzzy search provider
final globalSearchProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  // Set up cancellation flag to avoid race conditions when typing quickly
  bool cancelled = false;
  ref.onDispose(() => cancelled = true);

  // Debounce: wait for 350ms before sending request to server
  await Future.delayed(const Duration(milliseconds: 350));
  
  if (cancelled) {
    throw Exception('Cancelled');
  }
  
  final service = ref.read(searchServiceProvider);
  final results = await service.executeGlobalSearch(query);
  
  if (cancelled) {
    throw Exception('Cancelled');
  }
  
  return results;
});

// Search history provider
final searchHistoryProvider = FutureProvider<List<SearchHistoryEntry>>((ref) async {
  final user = ref.watch(currentProfileProvider);
  if (user == null) return [];
  final service = ref.read(searchServiceProvider);
  return service.getSearchHistory(user.id);
});

// Search controller for mutations
class SearchController {
  final Ref _ref;
  SearchController(this._ref);

  Future<void> clearHistory() async {
    final user = _ref.read(currentProfileProvider);
    if (user == null) return;
    await _ref.read(searchServiceProvider).clearSearchHistory(user.id);
    _ref.invalidate(searchHistoryProvider);
  }
}

final searchControllerProvider = Provider((ref) => SearchController(ref));
