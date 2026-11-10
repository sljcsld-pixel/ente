const int searchTabIndex = 3;
const int favoritesTabIndex = 4;

// Tab events keep stable IDs: Search remains 3 when optional tabs are hidden.
List<int> homeTabIndices({required bool showFeed, bool showFavorites = true}) =>
    [
      0,
      1,
      if (showFeed) 2,
      if (showFavorites) favoritesTabIndex,
      searchTabIndex,
    ];
