import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// Halaman Splash / Onboarding sesuai PRD §6.1 dan design/splash.jpg.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    // Lebar kontainer aplikasi (maks 440 px)
    final screenWidth = mediaQuery.size.width > 440
        ? 440.0
        : mediaQuery.size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.splashDark,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Area foto hero (tinggi ≈ 560-600 px) dengan label melayang
              SizedBox(
                height: 560,
                width: screenWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Blok photoGray polos tanpa ikon untuk v1 sesuai PRD §6.1 & §10
                    Positioned.fill(
                      child: Container(color: AppColors.photoGray),
                    ),

                    // Gradien memudar ke splashDark (#082B21) mulai ≈ y 560
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.55, 0.85, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              AppColors.splashDark.withValues(alpha: 0.85),
                              AppColors.splashDark,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 1. Label melayang: "Bumbu Halus" (x ≈ 95, y ≈ 210)
                    // pill olive + lingkaran putih ber-border olive berisi ikon keranjang
                    Positioned(
                      left: screenWidth * 0.216,
                      top: 210,
                      child: _FloatingPill(
                        text: 'Bumbu Halus',
                        bgColor: AppColors.olive,
                        textColor: AppColors.white,
                        circleColor: AppColors.white,
                        circleBorderColor: AppColors.olive,
                        icon: const Icon(
                          LucideIcons.shoppingBag,
                          size: 13,
                          color: AppColors.olive,
                        ),
                      ),
                    ),

                    // 2. Label melayang: "Kecap Manis" (x ≈ 205, y ≈ 300)
                    // pill olive + lingkaran putih berisi +
                    Positioned(
                      left: screenWidth * 0.466,
                      top: 300,
                      child: _FloatingPill(
                        text: 'Kecap Manis',
                        bgColor: AppColors.olive,
                        textColor: AppColors.white,
                        circleColor: AppColors.white,
                        circleBorderColor: null,
                        icon: const Icon(
                          LucideIcons.plus,
                          size: 15,
                          color: AppColors.olive,
                        ),
                      ),
                    ),

                    // 3. Label melayang: "Siap Masak" (x ≈ 70, y ≈ 435)
                    // pill amber + lingkaran ikon keranjang
                    Positioned(
                      left: screenWidth * 0.159,
                      top: 435,
                      child: _FloatingPill(
                        text: 'Siap Masak',
                        bgColor: AppColors.amber,
                        textColor: AppColors.olive,
                        circleColor: AppColors.white,
                        circleBorderColor: null,
                        icon: const Icon(
                          LucideIcons.shoppingBag,
                          size: 13,
                          color: AppColors.olive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Blok konten bawah (rata tengah)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Foodie.id: lingkaran putih + ikon garpu-sendok + teks FOODIE.ID
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.utensilsCrossed,
                              size: 16,
                              color: AppColors.olive,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'FOODIE',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: AppColors.white,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              TextSpan(
                                text: '.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: AppColors.amber,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              TextSpan(
                                text: 'ID',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: AppColors.white,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Judul 2 baris: Jelajahi Cita Rasa / Autentik Nusantara
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Jelajahi Cita Rasa\n',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: AppColors.white,
                              height: 1.3,
                            ),
                          ),
                          TextSpan(
                            text: 'Autentik Nusantara',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: AppColors.amber,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Paragraf deskripsi putih 70%
                    Text(
                      'Ribuan resep masakan khas daerah & belanja bahan segar dalam satu genggaman praktis.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: AppColors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tombol amber 383 × 44 "Mulai Eksplorasi →"
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 383),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: AppColors.olive,
                            elevation: 0,
                            shadowColor: AppColors.amber.withValues(
                              alpha: 0.35,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            final auth = ref.read(authProvider);
                            if (auth.isLoggedIn) {
                              context.go('/home');
                            } else {
                              context.push('/login');
                            }
                          },
                          child: const Text(
                            'Mulai Eksplorasi →',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.olive,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Baris kecil: ✓ 100% Halal • ✓ Bahan Segar Terpilih
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '✓ ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '100% Halal',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '  •  ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                          const Text(
                            '✓ ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Bahan Segar Terpilih',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingPill extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  final Color circleColor;
  final Color? circleBorderColor;
  final Widget icon;

  const _FloatingPill({
    required this.text,
    required this.bgColor,
    required this.textColor,
    required this.circleColor,
    required this.circleBorderColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowNav,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              border: circleBorderColor != null
                  ? Border.all(color: circleBorderColor!, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ],
      ),
    );
  }
}
