import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../config/theme.dart';
import 'main_shell.dart';
import 'auth_screens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _slideUp = Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.8, curve: Curves.easeOut)));
    _animController.forward();
    _init();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  Future<void> _init() async {
    await ref.read(authProvider.notifier).tryRestoreSession();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final auth = ref.read(authProvider);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => auth.isAuthenticated ? const MainShell() : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
          child: Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (_, __) => Opacity(
                opacity: _fadeIn.value,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Logo
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
                      ),
                      child: const Icon(Icons.apartment_rounded, size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text('NestKG', style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2,
                    )),
                    const SizedBox(height: 6),
                    Text('Найди свой дом', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5), letterSpacing: 1)),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.5)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
