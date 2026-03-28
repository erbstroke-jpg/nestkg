import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../widgets/widgets.dart';
import '../config/theme.dart';
import 'listings_screens.dart';
import 'other_screens.dart';
import 'conversations_screen.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final int listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  Listing? _listing;
  bool _loading = true;
  String? _error;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final l = await ref.read(listingsServiceProvider).getById(widget.listingId);
      setState(() { _listing = l; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_listing == null) return;
    try {
      if (_listing!.isFavorited) {
        await ref.read(favoritesServiceProvider).remove(_listing!.id);
      } else {
        await ref.read(favoritesServiceProvider).add(_listing!.id);
      }
      setState(() => _listing = _listing!.copyWith(isFavorited: !_listing!.isFavorited));
      ref.invalidate(favoritesProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _contactSeller() async {
    if (_listing == null) return;
    final myId = ref.read(authProvider).user?.id;
    if (myId == null || myId == _listing!.ownerId) return;

    try {
      final conv = await ref.read(messagingServiceProvider).createConversation(
        listingId: _listing!.id,
        recipientId: _listing!.ownerId,
        initialMessage: 'Здравствуйте! Интересует "${_listing!.title}"',
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conv, myId: myId),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = ref.watch(localeProvider);
    final myId = ref.watch(authProvider).user?.id;

    if (_loading) return Scaffold(appBar: AppBar(), body: const LoadingWidget());
    if (_error != null) return Scaffold(appBar: AppBar(), body: AppErrorWidget(message: _error!, onRetry: _load));
    final listing = _listing!;
    final isOwner = myId == listing.ownerId;

    return Scaffold(
      body: CustomScrollView(slivers: [
        // ── Image Gallery ──
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: listing.media.isNotEmpty
                ? Stack(children: [
                    PageView.builder(
                      itemCount: listing.media.length,
                      onPageChanged: (i) => setState(() => _currentImage = i),
                      itemBuilder: (_, i) => CachedNetworkImage(
                        imageUrl: mediaUrl(listing.media[i].fileUrl),
                        fit: BoxFit.cover, width: double.infinity,
                        placeholder: (_, __) => Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 48)),
                      ),
                    ),
                    if (listing.media.length > 1)
                      Positioned(
                        bottom: 12, left: 0, right: 0,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (int i = 0; i < listing.media.length; i++)
                            Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _currentImage ? Colors.white : Colors.white54,
                              ),
                            ),
                        ]),
                      ),
                    if (listing.isPromoted)
                      Positioned(top: 80, left: 12, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppTheme.promoted, borderRadius: BorderRadius.circular(6)),
                        child: Text(loc.promoted, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )),
                  ])
                : Container(color: Colors.grey[200], child: const Icon(Icons.apartment, size: 64)),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Title + Price ──
            Text(listing.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Text('\$${listing.price.toStringAsFixed(0)} ${listing.currency}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              if (listing.isNegotiable) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                  child: Text(loc.negotiable, style: TextStyle(color: Colors.green[700], fontSize: 12)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(listing.city, style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              const Icon(Icons.visibility, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${listing.viewCount} ${loc.views}', style: const TextStyle(color: Colors.grey)),
            ]),
            if (listing.condition != null) ...[
              const SizedBox(height: 8),
              StatusBadge(status: listing.condition!),
            ],

            const Divider(height: 24),

            // ── Category Attributes ──
            if (listing.attributesJson != null && listing.attributesJson!.isNotEmpty) ...[
              _AttributesGrid(attributes: listing.attributesJson!, lang: lang),
              const Divider(height: 24),
            ],

            // ── Description ──
            Text(loc.description, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(listing.description, style: const TextStyle(height: 1.5)),

            const Divider(height: 24),

            // ── Owner Card ──
            if (listing.owner != null)
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => OwnerProfileScreen(userId: listing.owner!.id),
                )),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50], borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: listing.owner!.profileImageUrl != null
                          ? CachedNetworkImageProvider(mediaUrl(listing.owner!.profileImageUrl!))
                          : null,
                      child: listing.owner!.profileImageUrl == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(listing.owner!.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      if (listing.owner!.city != null)
                        Text(listing.owner!.city!, style: const TextStyle(color: Colors.grey)),
                    ])),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ]),
                ),
              ),

            // ── Map ──
            if (listing.latitude != null && listing.longitude != null) ...[
              const SizedBox(height: 16),
              Text(loc.location, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(listing.latitude!, listing.longitude!),
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(listing.latitude!, listing.longitude!),
                          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 80), // space for bottom buttons
          ]),
        )),
      ]),

      // ── Bottom Action Buttons ──
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            // Favorite
            IconButton.filled(
              onPressed: _toggleFavorite,
              icon: Icon(
                listing.isFavorited ? Icons.favorite : Icons.favorite_border,
                color: listing.isFavorited ? Colors.red : null,
              ),
            ),
            const SizedBox(width: 8),
            // Report
            IconButton.outlined(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ReportScreen(targetType: 'listing', targetId: listing.id),
              )),
              icon: const Icon(Icons.flag_outlined),
            ),
            const SizedBox(width: 8),
            // Promote (owner only)
            if (isOwner && listing.status == 'approved') ...[
              IconButton.outlined(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PromoteListingScreen(listing: listing),
                )),
                icon: const Icon(Icons.rocket_launch),
              ),
              const SizedBox(width: 8),
            ],
            // Contact seller
            if (!isOwner)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _contactSeller,
                  icon: const Icon(Icons.chat),
                  label: Text(loc.contactSeller),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Attributes Grid (translated) ─────────────────

class _AttributesGrid extends StatelessWidget {
  final Map<String, dynamic> attributes;
  final String lang;
  const _AttributesGrid({required this.attributes, required this.lang});

  static const _labelsEn = {
    'rooms': 'Rooms', 'area_sqm': 'Area', 'floor': 'Floor', 'total_floors': 'Total floors',
    'building_type': 'Building', 'renovation': 'Renovation', 'furnishing': 'Furnishing',
    'land_sqm': 'Land area', 'floors': 'Floors', 'heating': 'Heating', 'garage': 'Garage',
    'property_type': 'Type', 'parking_spaces': 'Parking', 'land_type': 'Land type',
    'utilities': 'Utilities', 'rental_period': 'Rental', 'utilities_included': 'Utilities incl.',
  };

  static const _labelsRu = {
    'rooms': 'Комнат', 'area_sqm': 'Площадь', 'floor': 'Этаж', 'total_floors': 'Всего этажей',
    'building_type': 'Тип дома', 'renovation': 'Ремонт', 'furnishing': 'Мебель',
    'land_sqm': 'Участок', 'floors': 'Этажей', 'heating': 'Отопление', 'garage': 'Гараж',
    'property_type': 'Тип', 'parking_spaces': 'Парковка', 'land_type': 'Тип земли',
    'utilities': 'Коммуникации', 'rental_period': 'Аренда', 'utilities_included': 'Комм. вкл.',
  };

  static const _valuesRu = {
    'brick': 'Кирпич', 'panel': 'Панель', 'monolith': 'Монолит', 'block': 'Блок',
    'adobe': 'Саман', 'frame': 'Каркас', 'concrete': 'Бетон',
    'euro': 'Евро', 'cosmetic': 'Косметический', 'designer': 'Дизайнерский', 'needs_repair': 'Без ремонта',
    'furnished': 'С мебелью', 'semi': 'Частично', 'unfurnished': 'Без мебели',
    'central': 'Центральное', 'gas': 'Газ', 'electric': 'Электрическое', 'solid_fuel': 'Твёрдое топливо',
    'office': 'Офис', 'retail': 'Магазин', 'warehouse': 'Склад', 'restaurant': 'Ресторан', 'hotel': 'Отель',
    'residential': 'Жилая', 'agricultural': 'С/х', 'industrial': 'Промышленная', 'commercial': 'Коммерческая',
    'all': 'Все', 'electricity_only': 'Только свет', 'none': 'Нет',
    'daily': 'Посуточно', 'monthly': 'Помесячно', 'long_term': 'Долгосрочно',
  };

  String _label(String key) {
    final labels = lang == 'ru' ? _labelsRu : _labelsEn;
    return labels[key] ?? key.replaceAll('_', ' ');
  }

  String _formatValue(String key, dynamic value) {
    if (value is bool) return lang == 'ru' ? (value ? 'Да' : 'Нет') : (value ? 'Yes' : 'No');
    final str = value.toString();
    if (lang == 'ru' && _valuesRu.containsKey(str)) return _valuesRu[str]!;
    if (key == 'area_sqm' || key == 'land_sqm') return '$str м²';
    return str.replaceAll('_', ' ');
  }

  IconData _icon(String key) {
    switch (key) {
      case 'rooms': return Icons.meeting_room_outlined;
      case 'area_sqm': case 'land_sqm': return Icons.square_foot;
      case 'floor': case 'total_floors': case 'floors': return Icons.layers;
      case 'building_type': return Icons.apartment;
      case 'renovation': return Icons.construction;
      case 'furnishing': return Icons.chair;
      case 'heating': return Icons.local_fire_department;
      case 'garage': return Icons.garage;
      case 'parking_spaces': return Icons.local_parking;
      case 'property_type': case 'land_type': return Icons.category;
      case 'utilities': case 'utilities_included': return Icons.electrical_services;
      case 'rental_period': return Icons.calendar_month;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = attributes.entries.where((e) => e.value != null).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 3.2, crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50], borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(children: [
            Icon(_icon(e.key), size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_label(e.key), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(_formatValue(e.key, e.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            ])),
          ]),
        );
      },
    );
  }
}
