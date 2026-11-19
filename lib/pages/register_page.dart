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

/// Halaman Register sesuai PRD §6.3 dan design/Register.jpg.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreeTerms = false;
  bool _isLoading = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _termsError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _termsError = null;
    });

    bool hasError = false;

    if (name.isEmpty) {
      _nameError = 'Nama lengkap wajib diisi';
      hasError = true;
    }

    if (email.isEmpty || !_validateEmail(email)) {
      _emailError = 'Format email tidak valid';
      hasError = true;
    }

    if (password.length < 8) {
      _passwordError = 'Kata sandi minimal 8 karakter';
      hasError = true;
    }

    if (confirmPassword != password) {
      _confirmPasswordError = 'Konfirmasi kata sandi tidak cocok';
      hasError = true;
    }

    if (!_agreeTerms) {
      _termsError = 'Kamu harus menyetujui Syarat & Ketentuan';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref
        .read(authProvider.notifier)
        .register(
          name: name,
          email: email,
          password: password,
          rememberMe: true,
        );

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
              // Top bar: Panah kembali + "Register"
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
                          context.go('/login');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Register',
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

              // H1: "Resep baru, / cerita baru."
              const Text(
                'Resep baru,\ncerita baru.',
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
                'Buat akun untuk mulai masak versimu.',
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
                    // Field Nama Lengkap
                    AppInput(
                      label: 'Nama lengkap',
                      hintText: 'Masukkan nama lengkap',
                      controller: _nameController,
                      prefixIcon: const Icon(
                        LucideIcons.user,
                        size: 20,
                        color: AppColors.sage,
                      ),
                      errorText: _nameError,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

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
                      hintText: 'Minimal 8 karakter',
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

                    // Field Konfirmasi Kata Sandi
                    AppInput(
                      label: 'Konfirmasi kata sandi',
                      hintText: 'Ulangi kata sandi',
                      controller: _confirmPasswordController,
                      isPassword: true,
                      prefixIcon: const Icon(
                        LucideIcons.lock,
                        size: 20,
                        color: AppColors.sage,
                      ),
                      errorText: _confirmPasswordError,
                      onChanged: (_) {
                        if (_confirmPasswordError != null) {
                          setState(() => _confirmPasswordError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Checkbox Syarat & Ketentuan
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppCheckbox(
                          value: _agreeTerms,
                          onChanged: (val) {
                            setState(() {
                              _agreeTerms = val;
                              if (_agreeTerms) _termsError = null;
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textBody,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(text: 'Aku menyetujui '),
                                TextSpan(
                                  text: 'Syarat & Ketentuan',
                                  style: TextStyle(
                                    color: AppColors.maroon,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: ' dan '),
                                TextSpan(
                                  text: 'Kebijakan Privasi.',
                                  style: TextStyle(
                                    color: AppColors.maroon,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_termsError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _termsError!,
                        style: AppText.caption.copyWith(
                          color: AppColors.maroon,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tombol Daftar
                    AppButton(
                      label: 'Daftar',
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

              // Link Masuk
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun? ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textBody,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                      child: const Text(
                        'Masuk',
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
