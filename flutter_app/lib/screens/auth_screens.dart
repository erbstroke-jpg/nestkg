import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nestkg/l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../config/theme.dart';
import 'main_shell.dart';

// ── Login ─────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    if (ok) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          // Dark header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(28, MediaQuery.of(context).padding.top + 40, 28, 32),
            decoration: const BoxDecoration(
              gradient: AppTheme.darkGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(gradient: AppTheme.brandGradient, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.apartment_rounded, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('NestKG', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('Маркетплейс недвижимости\nКыргызстана', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5), height: 1.4)),
            ]),
          ),

          // Form
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(loc.login, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email, keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: loc.email, prefixIcon: const Icon(Icons.email_outlined, size: 20)),
                  validator: (v) => v != null && v.contains('@') ? null : 'Введите email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password, obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: loc.password, prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v != null && v.length >= 6 ? null : 'Минимум 6 символов',
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: Colors.red[400], size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(auth.error!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(loc.login, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Нет аккаунта?', style: TextStyle(color: Colors.grey[500])),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text(loc.register, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: Text(loc.forgotPassword, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Register ──────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _lang = 'ru';
  bool _obscure = true;

  @override
  void dispose() { _name.dispose(); _email.dispose(); _phone.dispose(); _password.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phone.text.trim();
    final ok = await ref.read(authProvider.notifier).register(
      fullName: _name.text.trim(), email: _email.text.trim(),
      phone: phone.isEmpty ? null : phone,
      password: _password.text, confirmPassword: _confirm.text,
      preferredLanguage: _lang,
    );
    if (!mounted) return;
    if (ok) {
      ref.read(localeProvider.notifier).setLocale(_lang);
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.register), backgroundColor: AppTheme.appBarBg),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            TextFormField(controller: _name, decoration: InputDecoration(labelText: loc.fullName, prefixIcon: const Icon(Icons.person_outlined, size: 20)),
              validator: (v) => v != null && v.length >= 2 ? null : 'Минимум 2 символа'),
            const SizedBox(height: 14),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: loc.email, prefixIcon: const Icon(Icons.email_outlined, size: 20)),
              validator: (v) => v != null && v.contains('@') ? null : 'Введите email'),
            const SizedBox(height: 14),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: loc.phone, prefixIcon: const Icon(Icons.phone_outlined, size: 20))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _lang, decoration: InputDecoration(labelText: loc.preferredLanguage, prefixIcon: const Icon(Icons.language, size: 20)),
              items: const [DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'ru', child: Text('Русский'))],
              onChanged: (v) => setState(() => _lang = v ?? 'ru'),
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _password, obscureText: _obscure,
              decoration: InputDecoration(labelText: loc.password, prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure))),
              validator: (v) => v != null && v.length >= 6 ? null : 'Минимум 6 символов'),
            const SizedBox(height: 14),
            TextFormField(controller: _confirm, obscureText: true,
              decoration: InputDecoration(labelText: loc.confirmPassword, prefixIcon: const Icon(Icons.lock_outlined, size: 20)),
              validator: (v) => v == _password.text ? null : 'Пароли не совпадают'),
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                child: Text(auth.error!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
            ],
            const SizedBox(height: 28),
            SizedBox(height: 52, child: ElevatedButton(
              onPressed: auth.isLoading ? null : _submit,
              child: auth.isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(loc.submit, style: const TextStyle(fontSize: 16)),
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Forgot Password ───────────────────────────────

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try { await ref.read(authServiceProvider).forgotPassword(_email.text.trim()); } catch (_) {}
    setState(() { _sent = true; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.resetPassword), backgroundColor: AppTheme.appBarBg),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _sent
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                  child: Icon(Icons.mark_email_read, size: 48, color: Colors.green[400])),
                const SizedBox(height: 20),
                Text(loc.resetSent, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              ]))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: loc.email, prefixIcon: const Icon(Icons.email_outlined, size: 20))),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(loc.sendResetLink, style: const TextStyle(fontSize: 16)),
                )),
              ]),
      ),
    );
  }
}
