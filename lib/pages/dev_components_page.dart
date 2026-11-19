import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import '../providers/recipes_provider.dart';
import '../widgets/widgets.dart';

/// Halaman inspeksi semua komponen bersama (reusable widgets) sesuai PRD §5.
/// Hanya aktif dalam mode debug.
class DevComponentsPage extends ConsumerStatefulWidget {
  const DevComponentsPage({super.key});

  @override
  ConsumerState<DevComponentsPage> createState() => _DevComponentsPageState();
}

class _DevComponentsPageState extends ConsumerState<DevComponentsPage> {
  bool _checkboxSquareVal = true;
  bool _checkboxCircleVal = false;
  bool _toggleVal = true;
  int _selectedChipIndex = 0;
  bool _isFav = true;

  final TextEditingController _inputController = TextEditingController(
    text: 'Input teks terisi',
  );
  final TextEditingController _passController = TextEditingController(
    text: 'rahasia123',
  );

  @override
  void dispose() {
    _inputController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRecipes = ref.watch(recipesProvider);
    final demoRecipe = allRecipes.first; // Ayam Kecap Bawang
    final demoGridRecipe = allRecipes.length > 2
        ? allRecipes[2]
        : allRecipes.first; // Soto Ayam

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Konten Scrollable
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 140.0),
              children: [
                // 1. AppHeader (PRD §5.1)
                const AppHeader(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader('1. AppButtons (PRD §5.3)'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppButton(
                            label: 'Primary Lg',
                            size: AppButtonSize.lg,
                            variant: AppButtonVariant.primary,
                            onPressed: () {},
                          ),
                          AppButton(
                            label: 'Accent Md',
                            size: AppButtonSize.md,
                            variant: AppButtonVariant.accent,
                            onPressed: () {},
                          ),
                          AppButton(
                            label: 'Danger Sm',
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.danger,
                            onPressed: () {},
                          ),
                          AppButton(
                            label: 'Outline Danger',
                            size: AppButtonSize.md,
                            variant: AppButtonVariant.outlineDanger,
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            onPressed: () {},
                          ),
                          AppButton(
                            label: 'Soft',
                            size: AppButtonSize.md,
                            variant: AppButtonVariant.soft,
                            onPressed: () {},
                          ),
                          AppButton(
                            label: 'Ghost',
                            size: AppButtonSize.md,
                            variant: AppButtonVariant.ghost,
                            onPressed: () {},
                          ),
                          AppButton(
                            label: 'Loading',
                            size: AppButtonSize.md,
                            isLoading: true,
                            onPressed: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      _buildHeader('2. AppChips Kategori'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children:
                            [
                              'Semua',
                              'Ayam',
                              'Daging Sapi',
                              'Ikan',
                              'Sayur',
                            ].asMap().entries.map((e) {
                              return AppChip(
                                label: e.value,
                                selected: _selectedChipIndex == e.key,
                                onTap: () =>
                                    setState(() => _selectedChipIndex = e.key),
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 28),
                      _buildHeader('3. AppInput (PRD §5.3)'),
                      const SizedBox(height: 12),
                      AppInput(
                        label: 'Email Pengguna',
                        hintText: 'Masukkan email',
                        controller: _inputController,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.sage,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppInput(
                        label: 'Kata Sandi',
                        hintText: 'Minimal 8 karakter',
                        controller: _passController,
                        isPassword: true,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.sage,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const AppInput(
                        label: 'Error State Input',
                        hintText: 'Input salah',
                        errorText:
                            'Format email tidak valid (contoh@domain.com)',
                      ),

                      const SizedBox(height: 28),
                      _buildHeader('4. AppCheckbox, Toggle & Badge'),
                      const SizedBox(height: 12),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppCheckbox(
                                value: _checkboxSquareVal,
                                onChanged: (v) =>
                                    setState(() => _checkboxSquareVal = v),
                              ),
                              const SizedBox(width: 8),
                              const Text('Kotak 22px', style: AppText.body),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppCheckbox.circle(
                                value: _checkboxCircleVal,
                                onChanged: (v) =>
                                    setState(() => _checkboxCircleVal = v),
                              ),
                              const SizedBox(width: 8),
                              const Text('Bulat 28px', style: AppText.body),
                            ],
                          ),
                          AppToggle(
                            value: _toggleVal,
                            onChanged: (v) => setState(() => _toggleVal = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          AppBadge.square(count: 6),
                          const SizedBox(width: 12),
                          AppBadge.pill(
                            count: 12,
                            icon: const Icon(
                              Icons.favorite,
                              color: AppColors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      _buildHeader(
                        '5. ImagePlaceholder & SmartImage (PRD §10)',
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          // Placeholder kotak >= 64px (menampilkan ikon garpu-sendok)
                          ImagePlaceholder(
                            width: 80,
                            height: 80,
                            borderRadius: AppRadius.card,
                          ),
                          SizedBox(width: 16),
                          // Placeholder kecil < 64px (ikon tersembunyi sesuai PRD §10)
                          ImagePlaceholder(
                            width: 48,
                            height: 48,
                            borderRadius: AppRadius.buttonSmall,
                          ),
                          SizedBox(width: 16),
                          // Avatar bulat berinisial
                          ImagePlaceholder(
                            width: 48,
                            height: 48,
                            isCircle: true,
                            initials: 'NC',
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      _buildHeader('6. Skeleton Loading Denyut Halus'),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Skeleton(width: 72, height: 72),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Skeleton(width: double.infinity, height: 16),
                                SizedBox(height: 8),
                                Skeleton(width: 140, height: 14),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      _buildHeader('7. Modals: Sheet, Dialog & Toast'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppButton(
                            label: 'Buka Sheet',
                            size: AppButtonSize.sm,
                            onPressed: () {
                              showAppBottomSheet(
                                context: context,
                                builder: (ctx) => Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Filter Resep',
                                        style: AppText.sectionTitle,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Ini adalah contoh AppBottomSheet dengan radius atas 24 px.',
                                        style: AppText.body,
                                      ),
                                      const SizedBox(height: 24),
                                      AppButton(
                                        label: 'Terapkan',
                                        fullWidth: true,
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          AppButton(
                            label: 'Dialog Sukses',
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.accent,
                            onPressed: () {
                              showAppSuccessDialog(
                                context,
                                title: 'Resep berhasil disimpan',
                                message:
                                    'Resepmu sudah bisa dilihat di Resep Saya.',
                              );
                            },
                          ),
                          AppButton(
                            label: 'Dialog Alert',
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.danger,
                            onPressed: () {
                              showAppConfirmDialog(
                                context,
                                title: 'Hapus dari favorit?',
                                message:
                                    'Resep akan dihapus dari daftar favoritmu.',
                              );
                            },
                          ),
                          AppButton(
                            label: 'Tampilkan Toast',
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.soft,
                            onPressed: () {
                              showAppToast(
                                context,
                                'Bahan ditambahkan ke keranjang',
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      _buildHeader('8. Recipe Cards (PRD §5.4)'),
                      const SizedBox(height: 12),
                      const Text(
                        'A. FeaturedRecipeCard (Daily Inspiration / Meal Plan)',
                        style: AppText.formLabel,
                      ),
                      const SizedBox(height: 8),
                      FeaturedRecipeCard(
                        recipe: demoRecipe,
                        isFavorite: _isFav,
                        onToggleFav: () => setState(() => _isFav = !_isFav),
                        onOpen: () {},
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'B. GridRecipeCard & FavoriteRecipeCard',
                        style: AppText.formLabel,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GridRecipeCard(
                              recipe: demoGridRecipe,
                              isFavorite: false,
                              onToggleFav: () {},
                              onQuickAdd: () {
                                showAppToast(
                                  context,
                                  'Bahan ditambahkan ke keranjang',
                                );
                              },
                              onOpen: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FavoriteRecipeCard(
                              recipe: demoGridRecipe,
                              isFavorite: true,
                              onRemove: () {
                                showAppConfirmDialog(
                                  context,
                                  title: 'Hapus menu favorit?',
                                  message: 'Menu ini akan dihapus dari daftar favoritmu.',
                                );
                              },
                              onOpen: () {},
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      _buildHeader('9. EmptyState'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: AppRadius.card,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: EmptyState(
                          icon: LucideIcons.heart,
                          title: 'Belum Ada Menu Favorit',
                          subtitle: 'Simpan resep favoritmu agar mudah ditemukan kembali.',
                          action: AppButton(
                            label: 'Cari Resep',
                            size: AppButtonSize.sm,
                            onPressed: () {},
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 10. AppBottomNav (PRD §5.2) Floating di dasar layar
          const AppBottomNav(currentRoute: '/home'),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.olive,
        borderRadius: AppRadius.buttonSmall,
      ),
      child: Text(
        title,
        style: AppText.cardHeroTitle.copyWith(
          color: AppColors.white,
          fontSize: 13,
        ),
      ),
    );
  }
}
