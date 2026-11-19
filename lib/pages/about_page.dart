import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';

/// Halaman Tentang Aplikasi (/about) sesuai PRD §7.9:
/// - Logo FOODIE.ID dengan titik amber
/// - Versi aplikasi 1.0.0
/// - Deskripsi singkat & tagline
/// - Ringkasan fitur utama Foodie.id
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            // Top Bar: Panah Kembali + Judul
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: AppShell.topChrome(context) + 12.0,
                  left: 24.0,
                  right: 24.0,
                  bottom: 16.0,
                ),
                child: Row(
                  children: [
                    Semantics(
                      label: 'Kembali',
                      button: true,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowShell,
                                blurRadius: 4.0,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            LucideIcons.arrowLeft,
                            size: 20.0,
                            color: AppColors.olive,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    const Expanded(
                      child: Text(
                        'Tentang Aplikasi',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.olive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Konten Utama
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Kartu Logo & Deskripsi
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 28.0,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: AppRadius.cardLarge,
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        children: [
                          // Logo FOODIE.ID
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: const [
                              Text(
                                'FOODIE',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: AppColors.olive,
                                ),
                              ),
                              Text(
                                '.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.amber,
                                ),
                              ),
                              Text(
                                'ID',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: AppColors.olive,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),

                          // Pill Versi
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.chipGray,
                              borderRadius: BorderRadius.circular(999.0),
                            ),
                            child: const Text(
                              'Versi 1.0.0',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.sage,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          // Tagline
                          const Text(
                            'Masak Lebih Mudah, Hidup Lebih Teratur.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.maroon,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12.0),

                          // Deskripsi
                          const Text(
                            'Foodie.id adalah asisten kuliner pintar yang dirancang untuk menemani keseharian memasakmu. Dari inspirasi resep Nusantara 100% Halal, perencanaan menu mingguan, hingga estimasi belanja bahan masakan yang rapi dan terorganisir.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.0,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18.0),

                    // Kartu Fitur Utama
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: AppRadius.cardLarge,
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fitur Unggulan',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.olive,
                            ),
                          ),
                          const SizedBox(height: 14.0),

                          _buildFeatureItem(
                            icon: LucideIcons.utensils,
                            iconColor: AppColors.maroon,
                            title: 'Inspirasi Resep Nusantara',
                            description: 'Koleksi resep khas Indonesia terpercaya dengan bahan dan takaran yang jelas.',
                          ),
                          const Divider(color: AppColors.border, height: 24.0),

                          _buildFeatureItem(
                            icon: LucideIcons.calendarDays,
                            iconColor: AppColors.amber,
                            title: 'Meal Plan Mingguan',
                            description: 'Jadwalkan menu harian Senin–Minggu agar tidak bingung mau masak apa.',
                          ),
                          const Divider(color: AppColors.border, height: 24.0),

                          _buildFeatureItem(
                            icon: LucideIcons.shoppingCart,
                            iconColor: AppColors.olive,
                            title: 'My Groceries (Daftar Belanja)',
                            description: 'Otomatisasi daftar belanja dari bahan resep dengan kalkulasi estimasi pengeluaran.',
                          ),
                          const Divider(color: AppColors.border, height: 24.0),

                          _buildFeatureItem(
                            icon: LucideIcons.mapPin,
                            iconColor: AppColors.maroon,
                            title: 'Nearby Places (Sekitarmu)',
                            description: 'Rekomendasi tempat makan dan warung kuliner terdekat dengan estimasi jarak.',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Copyright & Tagline Bawah
                    const Text(
                      '© 2026 Foodie.id • Dibuat untuk pecinta kuliner Indonesia',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontWeight: FontWeight.w400,
                        color: AppColors.sage,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18.0, color: iconColor),
        ),
        const SizedBox(width: 14.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.olive,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w400,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
