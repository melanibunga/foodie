import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import 'ui/smart_image.dart';

/// Menghitung sapaan berdasarkan jam sesuai PRD §15.2:
/// - 04.00–10.59: "Selamat pagi"
/// - 11.00–14.59: "Selamat siang"
/// - 15.00–17.59: "Selamat sore"
/// - 18.00–03.59: "Selamat malam"
String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 4 && hour < 11) {
    return 'Selamat pagi';
  } else if (hour >= 11 && hour < 15) {
    return 'Selamat siang';
  } else if (hour >= 15 && hour < 18) {
    return 'Selamat sore';
  } else {
    return 'Selamat malam';
  }
}

/// Header global Foodie.id (Home, Search, Add, Meal Plan, Nearby) sesuai PRD §5.1, §14.3, §14.4, §15.2.
/// - Kiri: Foto profil bulat ≈ 48 (inisial olive di atas photoGray). Tap -> /profile
/// - Tengah (kanan avatar): Greeting 2 baris (sapaan waktu 11/400 sage + nama depan 15/700 olive)
/// - Kanan:
///   - Pill Favorit: bg olive, ikon heart terisi putih + angka putih, 59 × 38. Tap -> /favorites
///   - Keranjang: ikon cart olive + angka olive (tanpa bg). Tap -> /groceries
class AppHeader extends ConsumerWidget {
  final bool includeTopPadding;
  final Color? backgroundColor;
  final DateTime? currentTime;

  const AppHeader({
    super.key,
    this.includeTopPadding = true,
    this.backgroundColor,
    this.currentTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final favCount = ref.watch(favoriteCountProvider);
    final cartCount = ref.watch(cartCountProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.bg);

    final initials = user?.name.isNotEmpty == true
        ? user!.name
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
        : 'NC';

    final firstName = user?.name.isNotEmpty == true
        ? user!.name
              .trim()
              .split(' ')
              .firstWhere((w) => w.isNotEmpty, orElse: () => 'Teman')
        : 'Teman';

    final topInset = MediaQuery.paddingOf(context).top;
    // Jarak header berjarak sekitar 45px dengan logo baterai hp di status bar
    final headerTop = includeTopPadding
        ? (topInset > 0 ? (topInset + 16.0) : 45.0)
        : 0.0;
    final now = currentTime ?? DateTime.now();

    return Container(
      color: bg,
      padding: EdgeInsets.only(
        top: headerTop,
        left: 24.0,
        right: 24.0,
        bottom: 12.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto Profil / Avatar Kiri
          Semantics(
            label: 'Profil Saya',
            button: true,
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: SmartImage(
                src: user?.avatar,
                initials: initials,
                isCircle: true,
                width: 48.0,
                height: 48.0,
              ),
            ),
          ),

          const SizedBox(width: 12.0),

          // Greeting 2 Baris (PRD §15.2)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingFor(now),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.0,
                    fontWeight: FontWeight.w400,
                    color: AppColors.sage,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1.0),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.olive,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8.0),

          // Sisi Kanan: Pill Favorit + Ikon Keranjang
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pill Favorit (59 × 38, radius pill, bg olive, ikon heart terisi putih)
              Semantics(
                label: 'Favorit',
                button: true,
                child: GestureDetector(
                  onTap: () => context.push('/favorites'),
                  child: Container(
                    width: 59.0,
                    height: 38.0,
                    decoration: const BoxDecoration(
                      color: AppColors.olive,
                      borderRadius: AppRadius.pill,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: AppColors.white,
                          size: 16.0,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          favCount.toString(),
                          style: AppText.caption.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Keranjang (ikon shoppingCart olive + angka olive)
              Semantics(
                label: 'Keranjang Belanja ($cartCount item)',
                button: true,
                child: GestureDetector(
                  onTap: () => context.push('/groceries'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 6.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.shoppingCart,
                          color: AppColors.olive,
                          size: 20.0,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cartCount.toString(),
                          style: AppText.caption.copyWith(
                            color: AppColors.olive,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
