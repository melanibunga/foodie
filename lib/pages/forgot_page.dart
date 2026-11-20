import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../providers/ui_helper.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_input.dart';

/// Halaman Lupa Kata Sandi sesuai PRD §7.9.
class ForgotPage extends ConsumerStatefulWidget {
  const ForgotPage({super.key});

  @override
  ConsumerState<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends ConsumerState<ForgotPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();

    setState(() => _emailError = null);

    if (email.isEmpty || !_validateEmail(email)) {
      setState(() => _emailError = 'Format email tidak valid');
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _isLoading = false);

    showAppToast(context, 'Tautan reset telah dikirim ke email kamu');

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = AppShell.topChrome(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
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
              // Top bar: Panah kembali + "Lupa kata sandi"
              Row(
                children: [
                  Semantics(
                    label: 'Kembali',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        LucideIcons.arrowLeft,
                        size: 24,
                        color: palette.textStrong,
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
                  Text(
                    'Lupa kata sandi',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: palette.textStrong,
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
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'MASAK LEBIH MUDAH',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: palette.onAccentSoft,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // H1: "Atur ulang / kata sandi."
              Text(
                'Atur ulang\nkata sandi.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: palette.textStrong,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              // Sub-judul
              Text(
                'Masukkan email terdaftar untuk menerima tautan pemulihan kata sandi.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // Kartu form
              Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: AppRadius.cardLarge,
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppInput(
                      label: 'Email',
                      hintText: 'Masukkan email kamu',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icon(
                        LucideIcons.mail,
                        size: 20,
                        color: palette.textSecondary,
                      ),
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    AppButton(
                      label: 'Kirim tautan',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      isLoading: _isLoading,
                      onPressed: _submit,
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
                    color: palette.textSecondary,
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
