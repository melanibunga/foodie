import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';

/// Halaman Tentang Aplikasi (/about) sesuai PRD §7.9, §16:
/// - Logo FOODIE.ID dengan titik amber
/// - Versi aplikasi 1.0.0
/// - Deskripsi singkat & tagline
/// - Ringkasan fitur utama Foodie.id
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
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
                          decoration: BoxDecoration(
                            color: palette.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.shadowColor,
                                blurRadius: 4.0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.arrowLeft,
                            size: 20.0,
                            color: palette.textStrong,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Text(
                        'Tentang Aplikasi',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22.0,
                          fontWeight: FontWeight.w700,
                          color: palette.textStrong,
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
                      decoration: BoxDecoration(
                        color: palette.surface,
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
                            children: [
                              Text(
                                'FOODIE',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: palette.textStrong,
                                ),
                              ),
                              Text(
                                '.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.w800,
                                  color: palette.accent,
                                ),
                              ),
                              Text(
                                'ID',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: palette.textStrong,
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
                              color: palette.chip,
                              borderRadius: BorderRadius.circular(999.0),
                            ),
                            child: Text(
                              'Versi 1.0.0',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          // Tagline
                          Text(
                            'Masak Lebih Mudah, Hidup Lebih Teratur.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: palette.danger,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12.0),

                          // Deskripsi
                          Text(
                            'Foodie.id adalah asisten kuliner pintar yang dirancang untuk menemani keseharian memasakmu. Dari inspirasi resep Nusantara 100% Halal, perencanaan menu mingguan, hingga estimasi belanja bahan masakan yang rapi dan terorganisir.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.0,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                              color: palette.textSecondary,
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
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: AppRadius.cardLarge,
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fitur Unggulan',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              color: palette.textStrong,
                            ),
                          ),
                          const SizedBox(height: 14.0),

                          _buildFeatureItem(
                            context: context,
                            icon: LucideIcons.utensils,
                            iconColor: palette.danger,
                            title: 'Inspirasi Resep Nusantara',
                            description: 'Koleksi resep khas Indonesia terpercaya dengan bahan dan takaran yang jelas.',
                          ),
                          Divider(color: palette.divider, height: 24.0),

                          _buildFeatureItem(
                            context: context,
                            icon: LucideIcons.calendarDays,
                            iconColor: palette.accent,
                            title: 'Meal Plan Mingguan',
                            description: 'Jadwalkan menu harian Senin–Minggu agar tidak bingung mau masak apa.',
                          ),
                          Divider(color: palette.divider, height: 24.0),

                          _buildFeatureItem(
                            context: context,
                            icon: LucideIcons.shoppingCart,
                            iconColor: palette.textStrong,
                            title: 'My Groceries (Daftar Belanja)',
                            description: 'Otomatisasi daftar belanja dari bahan resep dengan kalkulasi estimasi pengeluaran.',
                          ),
                          Divider(color: palette.divider, height: 24.0),

                          _buildFeatureItem(
                            context: context,
                            icon: LucideIcons.mapPin,
                            iconColor: palette.danger,
                            title: 'Nearby Places (Sekitarmu)',
                            description: 'Rekomendasi tempat makan dan warung kuliner terdekat dengan estimasi jarak.',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18.0),

                    // Kartu Atribusi Sumber Data sesuai PRD Fase B2
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: AppRadius.cardLarge,
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sumber Data & Atribusi',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              color: palette.textStrong,
                            ),
                          ),
                          const SizedBox(height: 10.0),
                          Text(
                            'Data resep masakan Nusantara bersumber dari Resep Masakan Nusantara API (api-resep-masakan.vercel.app).',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.0,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Catatan: Informasi porsi, kalori, tingkat kesulitan, dan rating adalah estimasi aplikasi untuk memudahkan eksplorasi kuliner.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Copyright & Tagline Bawah
                    Text(
                      '© 2026 Foodie.id • Dibuat untuk pecinta kuliner Indonesia',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontWeight: FontWeight.w400,
                        color: palette.textSecondary,
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
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final palette = context.palette;
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
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                description,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.0,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
