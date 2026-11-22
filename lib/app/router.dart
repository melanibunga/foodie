import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_text.dart';
import '../models/models.dart';
import '../pages/about_page.dart';
import '../pages/cook_page.dart';
import '../pages/cooked_page.dart';
import '../pages/create_recipe_page.dart';
import '../pages/dev_components_page.dart';
import '../pages/dev_tokens_page.dart';
import '../pages/favorites_page.dart';
import '../pages/groceries_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/meal_plan_page.dart';
import '../pages/my_recipes_page.dart';
import '../pages/nearby_full_map_page.dart';
import '../pages/nearby_page.dart';
import '../pages/profile_page.dart';
import '../pages/recipe_detail_page.dart';
import '../pages/register_page.dart';
import '../pages/search_page.dart';
import '../pages/splash_page.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_bottom_nav.dart';

/// Listenable untuk memberitahu GoRouter bila status auth berubah sesuai PRD §8.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isLoggedIn != next.isLoggedIn) {
        notifyListeners();
      }
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Factory pembuat GoRouter yang mendukung guard otentikasi.
GoRouter createRouter({
  Listenable? refreshListenable,
  AuthState Function()? getAuthState,
  String initialLocation = '/',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = getAuthState != null ? getAuthState() : null;
      final isLoggedIn = auth?.isLoggedIn ?? false;
      final path = state.uri.path;

      final isPublic =
          path == '/' ||
          path == '/login' ||
          path == '/register' ||
          path.startsWith('/dev');

      // Guard: tanpa session -> redirect ke /login (kecuali /, /login, /register, /dev/*)
      if (!isLoggedIn && !isPublic) {
        return '/login';
      }

      // Guard: sudah login dan buka "/" -> langsung /home
      if (isLoggedIn && path == '/') {
        return '/home';
      }

      return null;
    },
    routes: [
      // Splash / Onboarding
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),

      // Auth
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // ShellRoute untuk tab utama dengan floating bottom nav (Home, Search, Add, Meal Plan, Nearby)
      // /add kembali ke dalam shell (dengan bottom nav aktif) sesuai PRD §15.5
      ShellRoute(
        builder: (context, state, child) {
          final palette = context.palette;
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: palette.bg,
            body: Stack(
              children: [
                Positioned.fill(child: child),
                AppBottomNav(currentRoute: state.uri.path),
              ],
            ),
          );
        },
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/search',
            builder: (context, state) {
              final pickDate = state.uri.queryParameters['pick'];
              return SearchPage(pickDate: pickDate);
            },
          ),
          GoRoute(
            path: '/add',
            builder: (context, state) => const CreateRecipePage(),
          ),
          GoRoute(
            path: '/meal-plan',
            builder: (context, state) => const MealPlanPage(),
          ),
          GoRoute(
            path: '/nearby',
            builder: (context, state) => const NearbyPage(),
          ),
        ],
      ),

      // My Recipes
      GoRoute(
        path: '/my-recipes',
        builder: (context, state) => const MyRecipesPage(),
      ),

      // Favorites
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesPage(),
      ),

      // Riwayat Dimasak (PRD §14.10)
      GoRoute(path: '/cooked', builder: (context, state) => const CookedPage()),

      // Riwayat Dimasak (PRD §14.10)
      GoRoute(path: '/cooked', builder: (context, state) => const CookedPage()),

      // Groceries (Keranjang)
      GoRoute(
        path: '/groceries',
        builder: (context, state) => const GroceriesPage(),
      ),

      // Profile & Info
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutPage()),

      // Nearby Peta Penuh Interaktif (di luar shell)
      GoRoute(
        path: '/nearby/map',
        builder: (context, state) {
          final place = state.extra as Place?;
          return NearbyFullMapPage(initialSelectedPlace: place);
        },
      ),

      // Detail & Cooking Mode
      GoRoute(
        path: '/recipe/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return RecipeDetailPage(recipeId: id);
        },
        routes: [
          GoRoute(
            path: 'cook',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CookPage(recipeId: id);
            },
          ),
        ],
      ),

      // Halaman inspeksi dev tokens & dev components (hanya aktif saat kDebugMode)
      if (kDebugMode) ...[
        GoRoute(
          path: '/dev/tokens',
          builder: (context, state) => const DevTokensPage(),
        ),
        GoRoute(
          path: '/dev/components',
          builder: (context, state) => const DevComponentsPage(),
        ),
      ],
    ],

    // 404 Error handler
    errorBuilder: (context, state) {
      final palette = context.palette;
      return Scaffold(
        backgroundColor: palette.bg,
        appBar: AppBar(
          title: Text(
            '404 Not Found',
            style: AppText.pageTitle.copyWith(color: palette.textStrong),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: palette.danger),
                const SizedBox(height: 16),
                Text(
                  'Halaman tidak ditemukan',
                  style: AppText.sectionTitle.copyWith(
                    color: palette.textStrong,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.uri.toString(),
                  style: AppText.caption.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.actionBg,
                    foregroundColor: palette.onAction,
                  ),
                  onPressed: () => context.go('/home'),
                  child: const Text(
                    'Kembali ke Beranda',
                    style: AppText.buttonMd,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Instance default router untuk kompatibilitas
final GoRouter appRouter = createRouter();

/// Provider router utama dengan auth guard aktif
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return createRouter(
    refreshListenable: notifier,
    getAuthState: () => ref.read(authProvider),
  );
});
