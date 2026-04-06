enum SearchSortBy { distance, sortBoost, name }

class SearchFilters {
  final String? categoryId;
  final bool isOpenNow;
  final String? minVerificationStatus;
  final SearchSortBy sortBy;

  const SearchFilters({
    this.categoryId,
    this.isOpenNow = false,
    this.minVerificationStatus,
    this.sortBy = SearchSortBy.distance,
  });

  SearchFilters copyWith({
    String? categoryId,
    bool clearCategory = false,
    bool? isOpenNow,
    String? minVerificationStatus,
    bool clearMinVerificationStatus = false,
    SearchSortBy? sortBy,
  }) {
    return SearchFilters(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      isOpenNow: isOpenNow ?? this.isOpenNow,
      minVerificationStatus: clearMinVerificationStatus
          ? null
          : (minVerificationStatus ?? this.minVerificationStatus),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  static const empty = SearchFilters();
}
