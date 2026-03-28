import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../config/theme.dart';

// ── Loading ───────────────────────────────────────

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: AppTheme.primary));
}

// ── Error ─────────────────────────────────────────

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded, color: Colors.red[300], size: 40),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ]),
        ),
      );
}

// ── Empty State ───────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, required this.text, this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: Colors.grey[350]),
            ),
            const SizedBox(height: 16),
            Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ]),
        ),
      );
}

// ── Listing Card (Zillow-style) ───────────────────

class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback? onTap;
  final bool compact;
  const ListingCard({super.key, required this.listing, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final imgUrl = listing.primaryImageUrl;
    final attrs = listing.attributesJson;
    final rooms = attrs?['rooms'];
    final area = attrs?['area_sqm'];
    final floor = attrs?['floor'];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image with overlays
          Stack(children: [
            AspectRatio(
              aspectRatio: compact ? 4 / 3 : 16 / 10,
              child: imgUrl != null
                  ? CachedNetworkImage(
                      imageUrl: mediaUrl(imgUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImagePlaceholder(),
                      errorWidget: (_, __, ___) => _ImagePlaceholder(icon: Icons.broken_image),
                    )
                  : _ImagePlaceholder(),
            ),
            // Price tag
            Positioned(
              bottom: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${_formatPrice(listing.price)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            // Promoted badge
            if (listing.isPromoted)
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF8C00)]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bolt, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text('TOP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10)),
                  ]),
                ),
              ),
            // Favorite hint
            if (listing.isFavorited)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.favorite, size: 16, color: Colors.red),
                ),
              ),
          ]),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              // Location
              Row(children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(listing.city, style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              // Stats row
              Row(children: [
                if (rooms != null) _StatChip(Icons.meeting_room_outlined, '$rooms комн.'),
                if (area != null) _StatChip(Icons.square_foot, '${area} м²'),
                if (floor != null) _StatChip(Icons.layers_outlined, '${floor} эт.'),
                const Spacer(),
                if (listing.viewCount > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.visibility_outlined, size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('${listing.viewCount}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        ]),
      );
}

class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  const _ImagePlaceholder({this.icon = Icons.apartment_rounded});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF1F5F9),
        child: Center(child: Icon(icon, size: 40, color: Colors.grey[300])),
      );
}

// ── Adaptive Grid Helper ──────────────────────────

class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double itemMinWidth;
  final double spacing;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.itemMinWidth = 340,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = (constraints.maxWidth / itemMinWidth).floor().clamp(1, 4);
      if (cols == 1) {
        return Column(
          children: children.map((c) => Padding(padding: EdgeInsets.only(bottom: spacing), child: c)).toList(),
        );
      }
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children.map((c) => SizedBox(
          width: (constraints.maxWidth - spacing * (cols - 1)) / cols,
          child: c,
        )).toList(),
      );
    });
  }
}

// ── Status Badge ──────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'approved': case 'successful': case 'active': return AppTheme.success;
      case 'rejected': case 'failed': case 'cancelled': return AppTheme.danger;
      case 'pending': case 'pending_review': case 'pending_payment': return Colors.orange;
      case 'sold': return Colors.blue;
      case 'expired': return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}

// ── Section Header ────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}
