import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../config/theme.dart';
import 'listing_detail_screen.dart';
import 'search_filter_screen.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});
  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final List<Listing> _listings = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isFirstLoad = true;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadPage(int page) async {
    if (page == 1)
      setState(() {
        _listings.clear();
        _currentPage = 1;
        _hasMore = true;
        _isFirstLoad = true;
      });
    try {
      final filter = ref.read(feedFilterProvider);
      final result = await ref.read(listingsServiceProvider).fetchFeed(
            page: page,
            search: filter.search,
            categoryId: filter.categoryId ?? _selectedCategoryId,
            city: filter.city,
            minPrice: filter.minPrice,
            maxPrice: filter.maxPrice,
            condition: filter.condition,
            sortBy: filter.sortBy,
          );
      setState(() {
        if (page == 1) _listings.clear();
        _listings.addAll(result.items);
        _currentPage = page;
        _hasMore = result.hasMore;
        _isLoadingMore = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    await _loadPage(_currentPage + 1);
  }

  Future<void> _refresh() async => await _loadPage(1);

  void _onSearch() {
    ref.read(feedFilterProvider.notifier).state = FeedFilter(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      categoryId: _selectedCategoryId,
    );
    _loadPage(1);
  }

  void _selectCategory(int? id) {
    setState(() => _selectedCategoryId = id);
    ref.read(feedFilterProvider.notifier).state = FeedFilter(categoryId: id);
    _loadPage(1);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = ref.watch(localeProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];

    ref.listen(feedFilterProvider, (_, __) => _loadPage(1));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          // ── App Bar with search ──
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppTheme.appBarBg,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.darkGradient),
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.apartment_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 6),
                        const Text('NestKG',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                        const Spacer(),
                        // Filter button
                        IconButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SearchFilterScreen())),
                          icon: const Icon(Icons.tune_rounded,
                              color: Colors.white70, size: 22),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // Search bar
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: loc.search,
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.white.withOpacity(0.5), size: 20),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            filled: false,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _onSearch(),
                        ),
                      ),
                    ]),
              ),
            ),
          ),
        ],
        body: Column(children: [
          // ── Category chips ──
          if (cats.isNotEmpty)
            Container(
              color: Colors.white,
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _CategoryChip(
                    label: loc.allCategories,
                    selected: _selectedCategoryId == null,
                    onTap: () => _selectCategory(null),
                  ),
                  ...cats.map((c) => _CategoryChip(
                        label: c.name(lang),
                        selected: _selectedCategoryId == c.id,
                        onTap: () => _selectCategory(c.id),
                      )),
                ],
              ),
            ),

          // ── Listings ──
          Expanded(
            child: _isFirstLoad
                ? const LoadingWidget()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppTheme.primary,
                    child: _listings.isEmpty
                        ? ListView(children: [
                            SizedBox(
                                height: 200,
                                child: EmptyState(
                                  text: loc.noListings,
                                  subtitle: 'Попробуйте изменить фильтры',
                                  icon: Icons.apartment_outlined,
                                )),
                          ])
                        : LayoutBuilder(builder: (context, constraints) {
                            final cols = (constraints.maxWidth / 360)
                                .floor()
                                .clamp(1, 3);
                            return GridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: cols == 1 ? 0.82 : 0.75,
                              ),
                              itemCount: _listings.length + (_hasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= _listings.length) {
                                  return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: LoadingWidget());
                                }
                                return ListingCard(
                                  listing: _listings[i],
                                  compact: cols > 1,
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ListingDetailScreen(
                                              listingId: _listings[i].id),
                                        ));
                                    _loadPage(1);
                                  },
                                );
                              },
                            );
                          }),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppTheme.primary : Colors.grey[300]!),
            ),
            child: Text(label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[700],
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                )),
          ),
        ),
      );
}
