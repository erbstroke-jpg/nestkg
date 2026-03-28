import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';

import '../providers/providers.dart';
import '../config/theme.dart';
import 'home_feed_screen.dart';
import 'listings_screens.dart';
import 'create_listing_screen.dart';
import 'conversations_screen.dart';
import 'other_screens.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeFeedScreen(),
    FavoritesScreen(),
    CreateListingScreen(),
    ConversationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final unreadAsync = ref.watch(unreadCountProvider);
    final unread = unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              backgroundColor: AppTheme.appBarBg,
              foregroundColor: Colors.white,
              elevation: 4,
              child: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread', style: const TextStyle(fontSize: 10)),
                backgroundColor: AppTheme.danger,
                child: const Icon(Icons.notifications_outlined),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: loc.homeFeed,
                  isActive: _index == 0, onTap: () => setState(() => _index = 0)),
                _NavItem(icon: Icons.favorite_outline, activeIcon: Icons.favorite_rounded, label: loc.favorites,
                  isActive: _index == 1, onTap: () => setState(() => _index = 1)),
                _AddButton(onTap: () => setState(() => _index = 2)),
                _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble_rounded, label: loc.messages,
                  isActive: _index == 3, onTap: () => setState(() => _index = 3)),
                _NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: loc.profile,
                  isActive: _index == 4, onTap: () => setState(() => _index = 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(isActive ? activeIcon : icon, size: 24,
              color: isActive ? AppTheme.primary : Colors.grey[400]),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppTheme.primary : Colors.grey[400],
            )),
          ]),
        ),
      );
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      );
}
