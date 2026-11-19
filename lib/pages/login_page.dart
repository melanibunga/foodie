import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../providers/auth_provider.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_checkbox.dart';
import '../widgets/ui/app_input.dart';

/// Halaman Login sesuai PRD §6.2 dan design/Login.jpg.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isLoading = false;

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool hasError = false;

    if (email.isEmpty || !_validateEmail(email)) {
      _emailError = 'Format email tidak valid';
      hasError = true;
    }

    if (password.length < 8) {
      _passwordError = 'Kata sandi minimal 8 karakter';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref
        .read(authProvider.notifier)
        .login(email: email, password: password, rememberMe: _rememberMe);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = AppShell.topChrome(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding,
            left: 24.0,
            right: 24.0,
            bottom: 32.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: Panah kembali + "Login"
              Row(
                children: [
                  Semantics(
                    label: 'Kembali',
                    button: true,
                    child: IconButton(
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        size: 24,
                        color: AppColors.textTitle,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTitle,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Tag "MASAK LEBIH MUDAH"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'MASAK LEBIH MUDAH',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.olive,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // H1 2 baris: "Selamat / datang kembali."
              const Text(
                'Selamat\ndatang kembali.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.olive,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              // Sub-judul
              const Text(
                'Masuk dan lanjutkan cerita dapurmu.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.sage,
                ),
              ),

              const SizedBox(height: 28),

              // Kartu putih form
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.cardLarge,
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field Email
                    AppInput(
                      label: 'Email',
                      hintText: 'Masukkan email kamu',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(
                        LucideIcons.mail,
                        size: 20,
                        color: AppColors.sage,
                      ),
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Field Kata Sandi
                    AppInput(
                      label: 'Kata sandi',
                      hintText: 'Masukkan kata sandi',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: const Icon(
                        LucideIcons.lock,
                        size: 20,
                        color: AppColors.sage,
                      ),
                      errorText: _passwordError,
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Baris: "Ingat saya" & "Lupa kata sandi?"
                    Row(
                      children: [
                        AppCheckbox(
                          value: _rememberMe,
                          onChanged: (val) {
                            setState(() => _rememberMe = val);
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Ingat saya',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textBody,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/forgot'),
                          child: const Text(
                            'Lupa kata sandi?',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.maroon,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Tombol Masuk
                    AppButton(
                      label: 'Masuk',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Link Daftar
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun? ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textBody,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: const Text(
                        'Daftar',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.maroon,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Footer tagline
              Center(
                child: Text(
                  'Ide masak sehari-hari, dalam satu tempat.',
                  style: AppText.caption.copyWith(
                    color: AppColors.sage,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
