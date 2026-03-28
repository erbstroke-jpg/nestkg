import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../widgets/widgets.dart';
import 'listing_detail_screen.dart';
import 'create_listing_screen.dart';

// ── Favorites Screen ──────────────────────────────

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final favsAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.favorites)),
      body: favsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(favoritesProvider)),
        data: (result) {
          if (result.items.isEmpty) return EmptyState(text: loc.noFavorites, icon: Icons.favorite_border);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoritesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: result.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => ListingCard(
                listing: result.items[i],
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listingId: result.items[i].id),
                  )).then((_) => ref.invalidate(favoritesProvider));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── My Listings Screen ────────────────────────────

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});
  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _statuses = [null, 'draft', 'pending_review', 'approved', 'rejected', 'sold', 'archived'];
  final Map<int, List<Listing>> _cache = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) _loadTab(_tabController.index); });
    _loadTab(0);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadTab(int idx) async {
    if (_cache.containsKey(idx)) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(listingsServiceProvider).getMyListings(statusFilter: _statuses[idx]);
      _cache[idx] = result.items;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final labels = [loc.all, loc.draft, loc.pending, loc.approved, loc.rejected, loc.sold, loc.archived];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myListings),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_statuses.length, (idx) {
          if (_loading && !_cache.containsKey(idx)) return const LoadingWidget();
          final items = _cache[idx] ?? [];
          if (items.isEmpty) return const EmptyState(text: 'No listings', icon: Icons.list);
          return RefreshIndicator(
            onRefresh: () async { _cache.remove(idx); await _loadTab(idx); },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final l = items[i];
                return ListingCard(
                  listing: l,
                  onTap: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ListingDetailScreen(listingId: l.id),
                    ));
                    _cache.clear();
                    _loadTab(_tabController.index);
                  },
                );
              },
            ),
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateListingScreen()));
          if (created == true) { _cache.clear(); _loadTab(_tabController.index); }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Owner Profile Screen ──────────────────────────

class OwnerProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  const OwnerProfileScreen({super.key, required this.userId});
  @override
  ConsumerState<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends ConsumerState<OwnerProfileScreen> {
  UserPublic? _user;
  List<Listing> _listings = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final userSvc = ref.read(userServiceProvider);
      final user = await userSvc.getPublicProfile(widget.userId);
      final result = await userSvc.getUserListings(widget.userId);
      setState(() { _user = user; _listings = result.items; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (_loading) return Scaffold(appBar: AppBar(), body: const LoadingWidget());

    return Scaffold(
      appBar: AppBar(title: Text(loc.ownerProfile)),
      body: CustomScrollView(slivers: [
        if (_user != null)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              CircleAvatar(
                radius: 48,
                backgroundImage: _user!.profileImageUrl != null
                    ? CachedNetworkImageProvider(mediaUrl(_user!.profileImageUrl!)) : null,
                child: _user!.profileImageUrl == null ? const Icon(Icons.person, size: 48) : null,
              ),
              const SizedBox(height: 12),
              Text(_user!.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (_user!.city != null) ...[
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(_user!.city!, style: const TextStyle(color: Colors.grey)),
                ]),
              ],
              if (_user!.bio != null) ...[
                const SizedBox(height: 8),
                Text(_user!.bio!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StatItem(label: loc.activeListings, value: '${_user!.activeListingsCount}'),
                const SizedBox(width: 32),
                _StatItem(label: loc.memberSince, value: _user!.createdAt.split('T').first),
              ]),
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(loc.viewAllListings, style: Theme.of(context).textTheme.titleMedium),
              ),
            ]),
          )),
        if (_listings.isEmpty)
          const SliverFillRemaining(child: EmptyState(text: 'No listings', icon: Icons.list)),
        if (_listings.isNotEmpty)
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListingCard(
                listing: _listings[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ListingDetailScreen(listingId: _listings[i].id),
                )),
              ),
            ),
            childCount: _listings.length,
          )),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]);
}
