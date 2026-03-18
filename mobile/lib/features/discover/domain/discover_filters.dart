/// Filter state for the discover/search screen
class DiscoverFilters {
  final String searchQuery;
  final bool openNow;
  final bool open24hs;
  final bool lateNight;
  final bool onDutyToday;
  final bool nearMe;
  final String? category;
  final String? locality;

  const DiscoverFilters({
    this.searchQuery = '',
    this.openNow = false,
    this.open24hs = false,
    this.lateNight = false,
    this.onDutyToday = false,
    this.nearMe = false,
    this.category,
    this.locality,
  });

  bool get hasActiveFilters =>
      openNow ||
      open24hs ||
      lateNight ||
      onDutyToday ||
      nearMe ||
      category != null ||
      locality != null;

  DiscoverFilters copyWith({
    String? searchQuery,
    bool? openNow,
    bool? open24hs,
    bool? lateNight,
    bool? onDutyToday,
    bool? nearMe,
    String? Function()? category,
    String? Function()? locality,
  }) =>
      DiscoverFilters(
        searchQuery: searchQuery ?? this.searchQuery,
        openNow: openNow ?? this.openNow,
        open24hs: open24hs ?? this.open24hs,
        lateNight: lateNight ?? this.lateNight,
        onDutyToday: onDutyToday ?? this.onDutyToday,
        nearMe: nearMe ?? this.nearMe,
        category: category != null ? category() : this.category,
        locality: locality != null ? locality() : this.locality,
      );

  DiscoverFilters clearAll() => const DiscoverFilters();
}
