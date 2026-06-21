import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/search_providers.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/responsive.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(globalSearchProvider);
    final historyAsync = ref.watch(searchHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1D1A18),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Input Row
              _buildSearchBar(context),

              // Results or history
              Expanded(
                child: searchQuery.isEmpty
                    ? _buildSearchHistory(historyAsync)
                    : _buildSearchResults(searchResultsAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search USN, name, events, or teams...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) {
                  ref.read(searchQueryProvider.notifier).state = val;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistory(AsyncValue<List<SearchHistoryEntry>> historyAsync) {
    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 16),
                Text(
                  'Fuzzy Search Engine Ready',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Type to search anything in Lit Life',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(searchControllerProvider).clearHistory(),
                  child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...history.map((entry) {
              return ListTile(
                onTap: () {
                  _searchCtrl.text = entry.query;
                  ref.read(searchQueryProvider.notifier).state = entry.query;
                },
                leading: const Icon(Icons.history_rounded, color: Colors.white38),
                title: Text(entry.query, style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.north_west_rounded, color: Colors.white30, size: 18),
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<SearchResult>> resultsAsync) {
    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sentiment_dissatisfied_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 16),
                const Text('No records match your query', style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: context.r.pageInsets,
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return _buildResultTile(result);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Search error: $e',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildResultTile(SearchResult result) {
    IconData leadingIcon;
    Color iconColor;
    String route = '';

    switch (result.resultType.toLowerCase()) {
      case 'student':
        leadingIcon = Icons.person_rounded;
        iconColor = const Color(0xFF6366F1);
        route = '/students/${result.resultId}';
        break;
      case 'event':
        leadingIcon = Icons.event_rounded;
        iconColor = const Color(0xFF10B981);
        route = '/events/${result.resultId}';
        break;
      case 'team':
        leadingIcon = Icons.groups_rounded;
        iconColor = const Color(0xFFF59E0B);
        route = '/registration';
        break;
      case 'member':
        leadingIcon = Icons.shield_rounded;
        iconColor = const Color(0xFFEC4899);
        route = '/profile';
        break;
      default:
        leadingIcon = Icons.search_rounded;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: ListTile(
        onTap: () {
          if (route.isNotEmpty) {
            // Trigger refresh of search history log
            ref.invalidate(searchHistoryProvider);
            context.push(route);
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(leadingIcon, color: iconColor),
        ),
        title: Text(
          result.primaryText,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          result.secondaryText,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result.resultType.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
