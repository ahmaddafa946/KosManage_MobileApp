import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../home/presentation/home_gate_page.dart';
import '../application/auth_controller.dart';
import 'demo_credentials.dart';
import 'login_role.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole = 'owner';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Always resolve the profile for the newly authenticated session.
      ref.invalidate(currentProfileProvider);
      final freshProfile = await ref.read(currentProfileProvider.future);
      final roleMessage = roleMismatchMessage(
        selectedRole: _selectedRole,
        actualRole: freshProfile.role.name,
      );

      if (roleMessage != null) {
        // Do not leave a session active when the selected role is incorrect.
        await ref.read(authControllerProvider.notifier).signOut();
        ref.invalidate(currentProfileProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(roleMessage),
            backgroundColor: AppTheme.ink,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      debugPrint(
        'Login success role=${freshProfile.role.name} user=${freshProfile.id}',
      );
      if (!mounted) return;
      context.go('/home');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loginErrorMessage(error)),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _useDemoAccount() {
    final credentials = demoCredentialsForRole(_selectedRole);
    setState(() {
      _emailController.text = credentials.email;
      _passwordController.text = credentials.password;
    });
  }

  String _loginErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('invalid login') ||
        text.contains('invalid_credentials') ||
        text.contains('email not confirmed')) {
      return 'Email atau kata sandi tidak valid.';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('timeout') ||
        text.contains('failed host')) {
      return 'Koneksi internet bermasalah. Coba lagi.';
    }
    if (text.contains('supabase_url') ||
        text.contains('supabase_anon_key') ||
        text.contains('not initialized')) {
      return 'Konfigurasi Supabase belum benar di perangkat ini.';
    }
    return 'Login gagal. Periksa kredensial dan koneksi.';
  }

  Widget _roleOption({
    required String role,
    required String label,
  }) {
    final selected = _selectedRole == role;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Masuk sebagai $label',
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('login-role-$role'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selectedRole = role),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border.all(
                        color: AppTheme.border.withValues(alpha: 0.7),
                      )
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.brand : AppTheme.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.brand,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.brand.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.house_outlined,
                            size: 23,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KosManage',
                                style: TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.55,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Kelola kos, lebih tenang.',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 142),
                        decoration: const BoxDecoration(color: AppTheme.ink),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 18,
                              right: -82,
                              child: Transform.rotate(
                                angle: 0.18,
                                child: Container(
                                  width: 190,
                                  height: 190,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppTheme.brand.withValues(
                                        alpha: 0.8,
                                      ),
                                      width: 22,
                                    ),
                                    borderRadius: BorderRadius.circular(48),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Selamat datang di',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.68,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Ruang kelola kos Anda.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      height: 1.08,
                                      letterSpacing: -0.9,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Pantau hunian, pembayaran, dan kebutuhan '
                                    'kamar dalam satu tempat.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 12,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Masuk ke akun',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Gunakan akun KosManage Anda.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          _roleOption(role: 'owner', label: 'Pemilik'),
                          _roleOption(role: 'tenant', label: 'Penghuni'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Email',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const Key('login-email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'nama@email.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email wajib diisi';
                        }
                        if (!value.contains('@')) {
                          return 'Format email belum benar';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kata sandi',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const Key('login-password'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Masukkan kata sandi',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 19,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Tampilkan kata sandi'
                              : 'Sembunyikan kata sandi',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Kata sandi wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('login-submit'),
                        onPressed: isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppTheme.brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pastikan koneksi internet stabil untuk terhubung '
                      'ke akun Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        key: const Key('login-demo'),
                        onPressed: isLoading ? null : _useDemoAccount,
                        icon: const Icon(Icons.science_outlined, size: 16),
                        label: const Text('Gunakan Akun Demo'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.muted,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
