import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _searchHistoryKey = 'search_history';
const _maxHistory = 10;

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super(const []);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_searchHistoryKey) ?? const [];
  }

  Future<void> add(String term) async {
    final normalized = term.trim();
    if (normalized.isEmpty) return;
    final withoutDup = state
        .where((t) => t.toLowerCase() != normalized.toLowerCase())
        .toList();
    final next = [normalized, ...withoutDup].take(_maxHistory).toList();
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, next);
  }

  Future<void> clear() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
  (ref) => SearchHistoryNotifier(),
);
