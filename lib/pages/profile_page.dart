import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app/app_shell.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text.dart';
import '../data/user.dart';
import '../providers/auth_provider.dart';
import '../providers/cooked_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/recipes_provider.dart';
import '../providers/reset_data.dart';
import '../providers/theme_provider.dart';
import '../providers/ui_helper.dart';
import '../services/notification_service.dart';
import '../widgets/ui/app_bottom_sheet.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_input.dart';
import '../widgets/ui/app_toggle.dart';
import '../widgets/ui/smart_image.dart';

/// Halaman Profil Saya (/profile) sesuai PRD §6.12, §7.7, §7.9, §11, §16 dan design/akun.jpg:
/// - Top bar panah kiri + "Profil Saya" (24/700).
/// - Kartu profil (foto 80 placeholder bulat inisial, nama, email, chip "Edit profil" dangerSoft).
/// - Kartu statistik 3 kolom pemisah vertikal: Favorit, Dimasak, Resep Saya (tap -> /my-recipes).
/// - Judul "Pengaturan" (20/700).
/// - Kartu pengaturan: Pengingat makan (toggle danger), Mode gelap (toggle aktif ke themeModeProvider).
/// - Kartu "Tentang aplikasi" (tap -> /about).
/// - Tombol Logout outline danger -> hapus session -> /login.
/// - "Versi 1.0.0" -> tekan lama = dialog "Reset data demo?".
/// - Tanpa AppHeader global dan tanpa AppBottomNav.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _handleLogout() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Keluar dari akun?',
      message: 'Kamu perlu login kembali untuk mengakses data resep dan jadwal belanja.',
      confirmLabel: 'Logout',
      cancelLabel: 'Batal',
      isDanger: true,
    );

    if (confirmed && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _handleResetDemoData() async {
    final palette = context.palette;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Menu Pengembang',
            style: AppText.sectionTitle.copyWith(color: palette.textStrong),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.bell, color: palette.accent),
                title: Text(
                  'Kirim notifikasi uji',
                  style: AppText.bodyMedium.copyWith(color: palette.textStrong),
                ),
                subtitle: Text(
                  'Muncul 5 detik kemudian',
                  style: AppText.caption.copyWith(color: palette.textSecondary),
                ),
                onTap: () => Navigator.of(dialogContext).pop('test_notif'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(LucideIcons.refreshCw, color: palette.danger),
                title: Text(
                  'Reset data demo',
                  style: AppText.bodyMedium.copyWith(color: palette.danger),
                ),
                subtitle: Text(
                  'Kembalikan akun demo ke data awal',
                  style: AppText.caption.copyWith(color: palette.textSecondary),
                ),
                onTap: () => Navigator.of(dialogContext).pop('reset_demo'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Batal',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'test_notif') {
      await ref.read(notificationServiceProvider).sendTestNotification(
            delay: const Duration(seconds: 5),
          );
      if (mounted) {
        showAppToast(context, 'Notifikasi uji akan muncul dalam 5 detik');
      }
    } else if (action == 'reset_demo') {
      await resetAllDataRef(ref);
      if (mounted) {
        showAppToast(context, 'Data demo berhasil di-reset');
      }
    }
  }

  void _showEditProfileSheet() {
    final currentUser = ref.read(currentUserProvider) ?? seedUser;
    final nameController = TextEditingController(text: currentUser.name);
    final emailController = TextEditingController(text: currentUser.email);
    String? tempAvatar = currentUser.avatar;

    showAppBottomSheet(
      context: context,
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final initials = nameController.text.trim().isNotEmpty
                ? nameController.text
                      .trim()
                      .split(' ')
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .take(2)
                      .join()
                : 'NC';

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Profil',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // Foto Avatar + Tombol Ganti Foto
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      SmartImage(
                        src: tempAvatar,
                        initials: initials,
                        isCircle: true,
                        width: 88.0,
                        height: 88.0,
                      ),
                      Semantics(
                        label: 'Ganti foto profil',
                        button: true,
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await _picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1080,
                              imageQuality: 80,
                            );
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              if (bytes.length > 1024 * 1024) {
                                if (context.mounted) {
                                  showAppToast(
                                    context,
                                    'Ukuran foto maksimal 1MB',
                                  );
                                }
                                return;
                              }
                              final dataUri =
                                  'data:image/jpeg;base64,${base64Encode(bytes)}';
                              setSheetState(() {
                                tempAvatar = dataUri;
                              });
                            }
                          },
                          child: Container(
                            width: 32.0,
                            height: 32.0,
                            decoration: BoxDecoration(
                              color: palette.actionBg,
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
                              LucideIcons.camera,
                              size: 16.0,
                              color: palette.onAction,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  TextButton(
                    onPressed: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1080,
                        imageQuality: 80,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        if (bytes.length > 1024 * 1024) {
                          if (context.mounted) {
                            showAppToast(context, 'Ukuran foto maksimal 1MB');
                          }
                          return;
                        }
                        final dataUri =
                            'data:image/jpeg;base64,${base64Encode(bytes)}';
                        setSheetState(() {
                          tempAvatar = dataUri;
                        });
                      }
                    },
                    child: Text(
                      'Ganti foto',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: palette.danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Input Nama
                  AppInput(
                    label: 'Nama Lengkap',
                    controller: nameController,
                    prefixIcon: Icon(
                      LucideIcons.user,
                      size: 18.0,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14.0),

                  // Input Email (Readonly)
                  AppInput(
                    label: 'Email (tidak dapat diubah)',
                    controller: emailController,
                    prefixIcon: Icon(
                      LucideIcons.mail,
                      size: 18.0,
                      color: palette.textSecondary,
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 24.0),

                  // Tombol Simpan
                  AppButton(
                    label: 'Simpan',
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () async {
                      final newName = nameController.text.trim();
                      if (newName.isEmpty) {
                        showAppToast(context, 'Nama tidak boleh kosong');
                        return;
                      }

                      await ref
                          .read(authProvider.notifier)
                          .updateProfile(name: newName, avatar: tempAvatar);

                      if (context.mounted) {
                        Navigator.pop(sheetContext);
                        showAppToast(context, 'Profil berhasil diperbarui');
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatColumn({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String count,
    required String label,
    required String route,
    required BorderRadius borderRadius,
  }) {
    final palette = context.palette;
    return Expanded(
      child: Semantics(
        label: 'Buka $label',
        button: true,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            child: InkWell(
              onTap: () => context.push(route),
              borderRadius: borderRadius,
              splashColor: palette.dangerSoft,
              highlightColor: palette.dangerSoft.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20.0, color: iconColor),
                    const SizedBox(height: 6.0),
                    Text(
                      count,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24.0,
                        fontWeight: FontWeight.w700,
                        color: palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                        fontWeight: FontWeight.w400,
                        color: palette.textSecondary,
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? seedUser;
    final favCount = ref.watch(favoriteCountProvider);
    final cookedCount = ref.watch(cookedCountProvider);
    final myRecipes = ref.watch(myRecipesProvider);
    final myRecipesCount = myRecipes.length;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final palette = context.palette;

    final initials = user.name.isNotEmpty
        ? user.name
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
        : 'NC';

    final topPadding = AppShell.topChrome(context);

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const PageStorageKey<String>('profile_scroll_view'),
          slivers: [
            // 1. Top Bar: Panah Kembali + Judul "Profil Saya"
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 14.0,
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
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
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
                    Text(
                      'Profil Saya',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24.0,
                        fontWeight: FontWeight.w700,
                        color: palette.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Konten Profil
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kartu Profil (Putih, radius 20, padding 20)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: AppRadius.cardLarge,
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          // Foto Avatar 80px
                          SmartImage(
                            src: user.avatar,
                            initials: initials,
                            isCircle: true,
                            width: 80.0,
                            height: 80.0,
                          ),
                          const SizedBox(width: 16.0),

                          // Kolom Info Nama, Email & Tombol Edit
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textStrong,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  user.email,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w400,
                                    color: palette.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10.0),

                                // Chip "✎ Edit profil" (dangerSoft, teks onDangerSoft 12/600)
                                Semantics(
                                  label: 'Edit profil',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: _showEditProfileSheet,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14.0,
                                        vertical: 6.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.dangerSoft,
                                        borderRadius: BorderRadius.circular(
                                          999.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            LucideIcons.pencil,
                                            size: 13.0,
                                            color: palette.onDangerSoft,
                                          ),
                                          const SizedBox(width: 6.0),
                                          Text(
                                            'Edit profil',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w600,
                                              color: palette.onDangerSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Kartu Statistik 3 Kolom (PRD §14.11)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: AppRadius.cardLarge,
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          // Kolom Favorit -> /favorites
                          _buildStatColumn(
                            context: context,
                            icon: LucideIcons.heart,
                            iconColor: palette.danger,
                            count: '$favCount',
                            label: 'Favorit',
                            route: '/favorites',
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(20.0),
                            ),
                          ),

                          // Pemisah Vertikal 1
                          Container(
                            width: 1.0,
                            height: 48.0,
                            color: palette.border,
                          ),

                          // Kolom Dimasak -> /cooked
                          _buildStatColumn(
                            context: context,
                            icon: LucideIcons.chefHat,
                            iconColor: palette.accent,
                            count: '$cookedCount',
                            label: 'Dimasak',
                            route: '/cooked',
                            borderRadius: BorderRadius.zero,
                          ),

                          // Pemisah Vertikal 2
                          Container(
                            width: 1.0,
                            height: 48.0,
                            color: palette.border,
                          ),

                          // Kolom Resep Saya -> /my-recipes
                          _buildStatColumn(
                            context: context,
                            icon: LucideIcons.bookOpen,
                            iconColor: palette.danger,
                            count: '$myRecipesCount',
                            label: 'Resep Saya',
                            route: '/my-recipes',
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(20.0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Judul "Pengaturan" (20/700)
                    Text(
                      'Pengaturan',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700,
                        color: palette.textStrong,
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Kartu Pengaturan: Pengingat Makan + Mode Gelap
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: AppRadius.cardLarge,
                        boxShadow: AppShadows.card,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        children: [
                          // Row 1: Pengingat Makan
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.bell,
                                  size: 20.0,
                                  color: palette.textStrong,
                                ),
                                const SizedBox(width: 14.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pengingat makan',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w700,
                                          color: palette.textStrong,
                                        ),
                                      ),
                                      const SizedBox(height: 2.0),
                                      Text(
                                        user.settings.mealReminder
                                            ? 'Notifikasi jadwal makan aktif'
                                            : 'Notifikasi jadwal makan nonaktif',
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
                                AppToggle(
                                  key: const ValueKey('toggle-meal-reminder'),
                                  value: user.settings.mealReminder,
                                  onChanged: (_) async {
                                    final willEnable =
                                        !user.settings.mealReminder;
                                    if (willEnable) {
                                      final granted = await ref
                                          .read(notificationServiceProvider)
                                          .requestPermissions();
                                      if (!granted) {
                                        if (context.mounted) {
                                          showAppToast(
                                            context,
                                            'Izin notifikasi ditolak',
                                          );
                                        }
                                        return;
                                      }
                                    }
                                    await ref
                                        .read(authProvider.notifier)
                                        .toggleMealReminder();
                                    if (!willEnable) {
                                      await ref
                                          .read(notificationServiceProvider)
                                          .cancelAll();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          Divider(color: palette.divider, height: 16.0),

                          // Row 2: Mode Gelap (disambungkan ke themeModeProvider)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.moon,
                                  size: 20.0,
                                  color: palette.textStrong,
                                ),
                                const SizedBox(width: 14.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mode gelap',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w700,
                                          color: palette.textStrong,
                                        ),
                                      ),
                                      const SizedBox(height: 2.0),
                                      Text(
                                        isDark
                                            ? 'Tampilan gelap sedang digunakan'
                                            : 'Tampilan terang sedang digunakan',
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
                                AppToggle(
                                  key: const ValueKey('toggle-dark-mode'),
                                  value: isDark,
                                  onChanged: (_) {
                                    ref
                                        .read(themeModeProvider.notifier)
                                        .toggleDarkMode();
                                    ref
                                        .read(authProvider.notifier)
                                        .toggleDarkMode();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14.0),

                    // Kartu "Tentang aplikasi"
                    GestureDetector(
                      onTap: () => context.push('/about'),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: AppRadius.cardLarge,
                          boxShadow: AppShadows.card,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18.0,
                          vertical: 16.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.info,
                              size: 20.0,
                              color: palette.textStrong,
                            ),
                            const SizedBox(width: 14.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tentang aplikasi',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textStrong,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    'Kenali teman masakmu lebih dekat',
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
                            Icon(
                              LucideIcons.chevronRight,
                              size: 18.0,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Tombol Logout (Outline danger 1.5px, radius 12, tinggi ≈ 48, lebar penuh)
                    Semantics(
                      label: 'Logout dari akun',
                      button: true,
                      child: GestureDetector(
                        key: const ValueKey('logout-button'),
                        onTap: _handleLogout,
                        child: Container(
                          width: double.infinity,
                          height: 48.0,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: palette.danger,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.logOut,
                                size: 18.0,
                                color: palette.danger,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                  color: palette.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Footer Versi (Tekan lama = Reset data demo)
                    Center(
                      child: GestureDetector(
                        onLongPress: _handleResetDemoData,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            'Versi 1.0.0',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w400,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
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
}
