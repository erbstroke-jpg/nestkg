import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/api_client.dart';
import '../widgets/widgets.dart';
import 'listings_screens.dart';
import 'conversations_screen.dart';
import 'listing_detail_screen.dart';
import 'auth_screens.dart';

// ════════════════════════════════════════════════════
// NOTIFICATIONS SCREEN
// ════════════════════════════════════════════════════

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsServiceProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: Text(loc.markAllRead),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (result) {
          if (result.items.isEmpty) return EmptyState(text: loc.noNotifications, icon: Icons.notifications_none);
          return RefreshIndicator(
            onRefresh: () async { ref.invalidate(notificationsProvider); ref.invalidate(unreadCountProvider); },
            child: ListView.builder(
              itemCount: result.items.length,
              itemBuilder: (_, i) {
                final n = result.items[i];
                return ListTile(
                  leading: Icon(
                    _notifIcon(n.type),
                    color: n.isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: n.body != null ? Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                  trailing: Text(n.createdAt.split('T').first, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  tileColor: n.isRead ? null : Theme.of(context).colorScheme.primary.withOpacity(0.04),
                  onTap: () async {
                    if (!n.isRead) {
                      await ref.read(notificationsServiceProvider).markRead(n.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                    }
                    // Navigate based on reference type
                    if (n.referenceType == 'conversation' && n.referenceId != null) {
                      final myId = ref.read(authProvider).user?.id ?? 0;
                      try {
                        final convs = await ref.read(messagingServiceProvider).getConversations();
                        final conv = convs.items.where((c) => c.id == n.referenceId).firstOrNull;
                        if (conv != null && context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatScreen(conversation: conv, myId: myId),
                          ));
                        }
                      } catch (_) {}
                    } else if (n.referenceType == 'listing' && n.referenceId != null) {
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listingId: n.referenceId!),
                        ));
                      }
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'listing_approved': return Icons.check_circle;
      case 'listing_rejected': return Icons.cancel;
      case 'new_message': return Icons.chat;
      case 'payment_success': return Icons.payment;
      case 'promo_activated': return Icons.rocket_launch;
      case 'promo_expired': return Icons.timer_off;
      default: return Icons.notifications;
    }
  }
}

// ════════════════════════════════════════════════════
// PROFILE SCREEN
// ════════════════════════════════════════════════════

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() { _name.dispose(); _bio.dispose(); _city.dispose(); _phone.dispose(); super.dispose(); }

  void _startEdit(User user) {
    _name.text = user.fullName;
    _bio.text = user.bio ?? '';
    _city.text = user.city ?? '';
    _phone.text = user.phone ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userServiceProvider).updateProfile({
        'full_name': _name.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      });
      await ref.read(authProvider.notifier).refreshUser();
      setState(() { _editing = false; _saving = false; });
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.profileUpdated)));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      await ref.read(userServiceProvider).uploadAvatar(bytes, picked.name);
      await ref.read(authProvider.notifier).refreshUser();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final currentLang = ref.watch(localeProvider);

    if (user == null) return const Scaffold(body: LoadingWidget());

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.profile),
        actions: [
          if (!_editing)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => _startEdit(user)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Avatar
        Center(child: GestureDetector(
          onTap: _pickAvatar,
          child: Stack(children: [
            CircleAvatar(
              radius: 52,
              backgroundImage: user.profileImageUrl != null
                  ? CachedNetworkImageProvider(mediaUrl(user.profileImageUrl!)) : null,
              child: user.profileImageUrl == null ? const Icon(Icons.person, size: 52) : null,
            ),
            Positioned(bottom: 0, right: 0, child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.camera_alt, size: 20, color: Theme.of(context).colorScheme.primary),
            )),
          ]),
        )),
        const SizedBox(height: 16),

        if (_editing) ...[
          TextFormField(controller: _name, decoration: InputDecoration(labelText: loc.fullName)),
          const SizedBox(height: 12),
          TextFormField(controller: _bio, decoration: InputDecoration(labelText: loc.bio), maxLines: 3),
          const SizedBox(height: 12),
          TextFormField(controller: _city, decoration: InputDecoration(labelText: loc.city)),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, decoration: InputDecoration(labelText: loc.phone)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(loc.saveChanges),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => setState(() => _editing = false), child: Text(loc.cancel)),
        ] else ...[
          Center(child: Text(user.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
          Center(child: Text(user.email, style: const TextStyle(color: Colors.grey))),
          if (user.city != null) Center(child: Text(user.city!, style: const TextStyle(color: Colors.grey))),
          if (user.bio != null) ...[
            const SizedBox(height: 8),
            Text(user.bio!, textAlign: TextAlign.center),
          ],
        ],

        const Divider(height: 32),

        // Language
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(loc.language),
          trailing: DropdownButton<String>(
            value: currentLang,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ru', child: Text('Русский')),
            ],
            onChanged: (v) {
              if (v != null) ref.read(localeProvider.notifier).setLocale(v);
            },
          ),
        ),

        // Menu items
        ListTile(
          leading: const Icon(Icons.list),
          title: Text(loc.myListings),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.payment),
          title: Text(loc.paymentHistory),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsHistoryScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.rocket_launch),
          title: Text(loc.myPromotions),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPromotionsScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(loc.logout, style: const TextStyle(color: Colors.red)),
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false,
              );
            }
          },
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// REPORT SCREEN
// ════════════════════════════════════════════════════

class ReportScreen extends ConsumerStatefulWidget {
  final String targetType;
  final int targetId;
  const ReportScreen({super.key, required this.targetType, required this.targetId});
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String? _reasonCode;
  final _text = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() { _text.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_reasonCode == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(reportsServiceProvider).create(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reasonCode: _reasonCode!,
        reasonText: _text.text.trim().isEmpty ? null : _text.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final reasons = {
      'spam': loc.spam, 'fake': loc.fake, 'scam': loc.scam,
      'offensive': loc.offensive, 'duplicate': loc.duplicate,
      'prohibited': loc.prohibited, 'harassment': loc.harassment, 'other': loc.other,
    };

    return Scaffold(
      appBar: AppBar(title: Text(widget.targetType == 'listing' ? loc.reportListing : loc.reportUser)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: _reasonCode,
            decoration: InputDecoration(labelText: loc.reason),
            items: reasons.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _reasonCode = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text, maxLines: 4,
            decoration: InputDecoration(labelText: loc.additionalInfo, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting || _reasonCode == null ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(loc.submitReport),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// PROMOTE LISTING SCREEN
// ════════════════════════════════════════════════════

class PromoteListingScreen extends ConsumerStatefulWidget {
  final Listing listing;
  const PromoteListingScreen({super.key, required this.listing});
  @override
  ConsumerState<PromoteListingScreen> createState() => _PromoteListingScreenState();
}

class _PromoteListingScreenState extends ConsumerState<PromoteListingScreen> {
  PromotionPackage? _selected;
  final _targetCity = TextEditingController();
  bool _processing = false;

  @override
  void dispose() { _targetCity.dispose(); super.dispose(); }

  Future<void> _purchase() async {
    if (_selected == null) return;
    setState(() => _processing = true);
    try {
      final promo = await ref.read(promotionsServiceProvider).purchase(
        listingId: widget.listing.id,
        packageId: _selected!.id,
        targetCity: _targetCity.text.trim().isEmpty ? null : _targetCity.text.trim(),
      );
      // Mock confirm payment
      if (promo.paymentId != null) {
        await ref.read(paymentsServiceProvider).confirm(promo.paymentId!, success: true);
      }
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.paymentSuccess)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = ref.watch(localeProvider);
    final packagesAsync = ref.watch(promotionPackagesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.promoteListing)),
      body: packagesAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString()),
        data: (packages) => ListView(padding: const EdgeInsets.all(16), children: [
          Text(widget.listing.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(loc.selectPackage, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...packages.map((pkg) => Card(
            color: _selected?.id == pkg.id ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
            child: ListTile(
              title: Text(pkg.name(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${pkg.durationDays} ${loc.days} • ${pkg.promotionType}'),
              trailing: Text('\$${pkg.price.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              selected: _selected?.id == pkg.id,
              onTap: () => setState(() => _selected = pkg),
            ),
          )),
          const SizedBox(height: 16),
          TextField(
            controller: _targetCity,
            decoration: InputDecoration(labelText: loc.targetCity),
          ),
          const SizedBox(height: 24),
          if (_selected != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('Total: \$${_selected!.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${_selected!.durationDays} ${loc.days} ${_selected!.promotionType}'),
              ]),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selected == null || _processing ? null : _purchase,
            child: _processing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('${loc.pay} \$${_selected?.price.toStringAsFixed(2) ?? ''}'),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// PAYMENTS HISTORY SCREEN
// ════════════════════════════════════════════════════

class PaymentsHistoryScreen extends ConsumerStatefulWidget {
  const PaymentsHistoryScreen({super.key});
  @override
  ConsumerState<PaymentsHistoryScreen> createState() => _PaymentsHistoryScreenState();
}

class _PaymentsHistoryScreenState extends ConsumerState<PaymentsHistoryScreen> {
  List<Payment> _payments = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await ref.read(paymentsServiceProvider).getMyPayments();
      setState(() { _payments = r.items; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_loading) return Scaffold(appBar: AppBar(title: Text(loc.paymentHistory)), body: const LoadingWidget());

    return Scaffold(
      appBar: AppBar(title: Text(loc.paymentHistory)),
      body: _payments.isEmpty
          ? const EmptyState(text: 'No payments', icon: Icons.payment)
          : ListView.builder(
              itemCount: _payments.length,
              itemBuilder: (_, i) {
                final p = _payments[i];
                return ListTile(
                  leading: Icon(p.status == 'successful' ? Icons.check_circle : Icons.pending, color: p.status == 'successful' ? Colors.green : Colors.orange),
                  title: Text('\$${p.amount.toStringAsFixed(2)} ${p.currency}'),
                  subtitle: Text(p.createdAt.split('T').first),
                  trailing: StatusBadge(status: p.status),
                );
              },
            ),
    );
  }
}

// ════════════════════════════════════════════════════
// MY PROMOTIONS SCREEN
// ════════════════════════════════════════════════════

class MyPromotionsScreen extends ConsumerStatefulWidget {
  const MyPromotionsScreen({super.key});
  @override
  ConsumerState<MyPromotionsScreen> createState() => _MyPromotionsScreenState();
}

class _MyPromotionsScreenState extends ConsumerState<MyPromotionsScreen> {
  List<Promotion> _promos = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await ref.read(promotionsServiceProvider).getMyPromotions();
      setState(() { _promos = r.items; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_loading) return Scaffold(appBar: AppBar(title: Text(loc.myPromotions)), body: const LoadingWidget());

    return Scaffold(
      appBar: AppBar(title: Text(loc.myPromotions)),
      body: _promos.isEmpty
          ? const EmptyState(text: 'No promotions', icon: Icons.rocket_launch)
          : ListView.builder(
              itemCount: _promos.length,
              itemBuilder: (_, i) {
                final p = _promos[i];
                return ListTile(
                  leading: const Icon(Icons.rocket_launch),
                  title: Text('Listing #${p.listingId} • ${p.promotionType}'),
                  subtitle: Text(p.targetCity != null ? 'Target: ${p.targetCity}' : '\$${p.purchasedPrice.toStringAsFixed(2)}'),
                  trailing: StatusBadge(status: p.status),
                );
              },
            ),
    );
  }
}
