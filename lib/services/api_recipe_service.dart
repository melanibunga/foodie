import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/utils/recipe_formatters.dart';
import '../models/models.dart';
import '../providers/storage_provider.dart';
import 'recipe_cache_service.dart';
import 'recipe_service.dart';

/// Notifier untuk notifikasi toast fallback data cadangan
class RecipeFallbackToastNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) {
    state = message;
  }

  void clear() {
    state = null;
  }
}

final recipeFallbackToastProvider =
    NotifierProvider<RecipeFallbackToastNotifier, String?>(
      RecipeFallbackToastNotifier.new,
    );

/// URL Dasar API Resep Masakan Utama (API #1)
const String kRecipeApiBase = String.fromEnvironment(
  'RECIPE_API_BASE',
  defaultValue: 'https://api-resep-masakan.vercel.app/api/v1',
);

/// Sumber resep yang digunakan aplikasi: 'api' (default) atau 'local'
const String kRecipeSource = String.fromEnvironment(
  'RECIPE_SOURCE',
  defaultValue: 'api',
);

/// Adapter untuk memetakan respons dari API #1 (Resep Masakan Nusantara) ke domain [Recipe]
class ResepMasakanApiAdapter {
  static Recipe fromJson(Map<String, dynamic> json) {
    final String slug =
        json['slug'] as String? ?? json['id'] as String? ?? 'unknown';
    final String id = 'api:$slug';

    // Nama menu: gunakan 'name', BUKAN 'title' (karena title mengandung nomor urut prefix)
    String name = (json['name'] as String? ?? '').trim();
    if (name.isEmpty) {
      final rawTitle = (json['title'] as String? ?? '').trim();
      name = rawTitle.replaceFirst(RegExp(r'^\d+\.\s*'), '');
    }
    if (name.isEmpty) {
      name = 'Resep Nusantara';
    }

    // Ekstraksi gambar yang tangguh dari berbagai kemungkinan nama field
    final dynamic rawImage =
        json['imageUrl'] ??
        json['image'] ??
        json['image_url'] ??
        json['thumbnail'] ??
        json['photo'] ??
        json['picture'] ??
        json['img'];
    String? imageUrl;
    if (rawImage != null) {
      final s = rawImage.toString().trim();
      if (s.isNotEmpty && s != 'null') {
        imageUrl = s;
      }
    }

    final String origin = (json['origin'] as String? ?? 'Nusantara').trim();

    String categoryName = 'Tradisional';
    if (json['category'] is Map) {
      categoryName = (json['category']['name'] as String? ?? 'Tradisional')
          .trim();
    }

    final String description = 'Masakan khas $origin · $categoryName.';

    // Parse bahan-bahan (Ingredient)
    final List<Ingredient> ingredients = [];
    if (json['ingredientGroups'] is List) {
      final groups = json['ingredientGroups'] as List;
      for (final group in groups) {
        if (group is Map && group['ingredients'] is List) {
          final items = group['ingredients'] as List;
          for (final item in items) {
            if (item is Map) {
              final rawMap = Map<String, dynamic>.from(item);
              final ingId =
                  rawMap['id']?.toString() ?? 'ing-${ingredients.length}';
              final ingName = (rawMap['name']?.toString() ?? '').trim();
              final amount = rawMap['amount']?.toString().trim();
              final rawText = rawMap['rawText']?.toString().trim();
              final unit = rawMap['unit']?.toString().trim();

              final qty = (amount != null && amount.isNotEmpty)
                  ? amount
                  : (rawText != null && rawText.isNotEmpty ? rawText : '1');

              ingredients.add(
                Ingredient(
                  id: ingId,
                  name: ingName.isNotEmpty ? ingName : (rawText ?? 'Bahan'),
                  qty: qty,
                  unit: (unit != null && unit.isNotEmpty) ? unit : null,
                  price: 0, // HARGA BAHAN dari API = 0 sesuai aturan Fase B2
                ),
              );
            }
          }
        }
      }
    }

    // Parse langkah memasak (RecipeStep)
    final List<RecipeStep> steps = [];
    if (json['steps'] is List) {
      final rawSteps = json['steps'] as List;
      for (int i = 0; i < rawSteps.length; i++) {
        final stepItem = rawSteps[i];
        if (stepItem is Map) {
          final sMap = Map<String, dynamic>.from(stepItem);
          final stepId = sMap['id']?.toString() ?? 'step-${i + 1}';
          final stepNum = sMap['stepNumber'] ?? (i + 1);
          final stepTitle = (sMap['title']?.toString() ?? '').trim();
          final instruction =
              (sMap['instruction']?.toString() ??
                      sMap['rawText']?.toString() ??
                      '')
                  .trim();

          steps.add(
            RecipeStep(
              id: stepId,
              title: stepTitle.isNotEmpty ? stepTitle : 'Langkah $stepNum',
              description: instruction,
              durationMin: null,
            ),
          );
        }
      }
    }

    // Bila tidak ada langkah terstruktur, coba dari rawContent
    if (steps.isEmpty && json['rawContent'] is String) {
      final rawContent = json['rawContent'] as String;
      final lines = rawContent
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      int stepCounter = 1;
      for (final line in lines) {
        if (line.toLowerCase().contains('langkah') || line.contains(':')) {
          steps.add(
            RecipeStep(
              id: 'step-$stepCounter',
              title: 'Langkah $stepCounter',
              description: line.trim(),
            ),
          );
          stepCounter++;
        }
      }
    }

    // Data yang dikelola sendiri (derived, deterministik dari hash id supaya konsisten)
    final int hash = id.hashCode.abs();

    // derived: servings 1–6
    final int servings = 1 + (hash % 6);

    // derived: kcal 150–700
    final int kcal = 150 + (hash % 551);

    // derived: difficulty Mudah/Sedang/Sulit
    final Difficulty difficulty = [
      Difficulty.mudah,
      Difficulty.sedang,
      Difficulty.sulit,
    ][hash % 3];

    // derived: rating dasar 3.8–5.0
    final double rating = double.parse(
      (3.8 + ((hash % 13) / 10.0)).toStringAsFixed(1),
    );

    // derived: jumlah ulasan dasar 10–210
    final int reviews = 10 + (hash % 201);

    // derived: timeMin prep+cook bila ada, kalau tidak derived
    final int prep = (json['prepTimeMinutes'] as num?)?.toInt() ?? 0;
    final int cook = (json['cookTimeMinutes'] as num?)?.toInt() ?? 0;
    final int timeMin = (prep + cook > 0)
        ? (prep + cook)
        : (20 + ((hash % 9) * 5)); // 20..60 menit

    // derived: mainIngredient diturunkan dari daftar bahan (ayam, telur, sapi, ikan, kangkung, sayur)
    String mainIngredient = 'Lainnya';
    final allIngredientsText = ingredients
        .map((i) => i.name.toLowerCase())
        .join(' ');
    if (allIngredientsText.contains('ayam') ||
        allIngredientsText.contains('chicken')) {
      mainIngredient = 'Ayam';
    } else if (allIngredientsText.contains('sapi') ||
        allIngredientsText.contains('daging') ||
        allIngredientsText.contains('beef') ||
        allIngredientsText.contains('kambing')) {
      mainIngredient = 'Sapi';
    } else if (allIngredientsText.contains('ikan') ||
        allIngredientsText.contains('udang') ||
        allIngredientsText.contains('cumi') ||
        allIngredientsText.contains('seafood') ||
        allIngredientsText.contains('salmon')) {
      mainIngredient = 'Ikan';
    } else if (allIngredientsText.contains('telur') ||
        allIngredientsText.contains('egg')) {
      mainIngredient = 'Telur';
    } else if (allIngredientsText.contains('kangkung')) {
      mainIngredient = 'Kangkung';
    } else if (allIngredientsText.contains('sayur') ||
        allIngredientsText.contains('bayam') ||
        allIngredientsText.contains('tahu') ||
        allIngredientsText.contains('tempe')) {
      mainIngredient = 'Sayur';
    } else if (ingredients.isNotEmpty) {
      mainIngredient = ingredients.first.name;
    }

    // derived: meal (MealType) diturunkan dari kata kunci kategori + fallback hash agar 6 tile Search by Meal terisi
    final combinedForMeal =
        '${categoryName.toLowerCase()} ${name.toLowerCase()}';
    final MealType meal;
    if (combinedForMeal.contains('sarapan') ||
        combinedForMeal.contains('pagi') ||
        combinedForMeal.contains('breakfast') ||
        combinedForMeal.contains('bubur')) {
      meal = MealType.breakfast;
    } else if (combinedForMeal.contains('lunch') ||
        combinedForMeal.contains('siang')) {
      meal = MealType.lunch;
    } else if (combinedForMeal.contains('dinner') ||
        combinedForMeal.contains('malam')) {
      meal = MealType.dinner;
    } else if (combinedForMeal.contains('snack') ||
        combinedForMeal.contains('camilan') ||
        combinedForMeal.contains('gorengan')) {
      meal = MealType.snack;
    } else if (combinedForMeal.contains('dessert') ||
        combinedForMeal.contains('kue') ||
        combinedForMeal.contains('manis') ||
        combinedForMeal.contains('puding')) {
      meal = MealType.dessert;
    } else if (combinedForMeal.contains('minuman') ||
        combinedForMeal.contains('drink') ||
        combinedForMeal.contains('es ') ||
        combinedForMeal.contains('jus')) {
      meal = MealType.drinks;
    } else {
      // fallback hash agar 6 tile Search by Meal terisi merata
      meal = MealType.values[hash % MealType.values.length];
    }

    final formattedIngredients = RecipeFormatters.formatIngredients(
      ingredients,
    );
    final formattedSteps = RecipeFormatters.formatSteps(
      steps,
      rawContent: json['rawContent'] as String?,
    );

    return Recipe(
      id: id,
      title: name,
      description: description,
      image: imageUrl,
      category: categoryName,
      cuisine: origin,
      meal: meal,
      mainIngredient: mainIngredient,
      rating: rating,
      reviews: reviews,
      timeMin: timeMin,
      servings: servings,
      kcal: kcal,
      difficulty: difficulty,
      ingredients: formattedIngredients,
      steps: formattedSteps,
    );
  }
}

/// Adapter untuk memetakan respons dari API #2 (Masak Apa Hari Ini) ke domain [Recipe]
class MasakApaApiAdapter {
  static Recipe fromJson(Map<String, dynamic> json) {
    final String key =
        json['key'] as String? ?? json['id'] as String? ?? 'unknown';
    final String id = 'api2:$key';

    final String name =
        (json['title'] as String? ??
                json['name'] as String? ??
                'Resep Nusantara')
            .trim();
    final String? imageUrl =
        json['thumb'] as String? ?? json['imageUrl'] as String?;
    final String origin = (json['origin'] as String? ?? 'Nusantara').trim();
    final String category = (json['category'] as String? ?? 'Tradisional')
        .trim();
    final String description = 'Masakan khas $origin · $category.';

    final List<Ingredient> ingredients = [];
    if (json['ingredient'] is List) {
      for (final ing in json['ingredient']) {
        final text = ing.toString().trim();
        ingredients.add(
          Ingredient(
            id: 'ing-${ingredients.length}',
            name: text,
            qty: '1',
            price: 0,
          ),
        );
      }
    }

    final List<RecipeStep> steps = [];
    if (json['step'] is List) {
      for (int i = 0; i < json['step'].length; i++) {
        steps.add(
          RecipeStep(
            id: 'step-${i + 1}',
            title: 'Langkah ${i + 1}',
            description: json['step'][i].toString().trim(),
          ),
        );
      }
    }

    final int hash = id.hashCode.abs();
    final int servings = 1 + (hash % 6);
    final int kcal = 150 + (hash % 551);
    final Difficulty difficulty = [
      Difficulty.mudah,
      Difficulty.sedang,
      Difficulty.sulit,
    ][hash % 3];
    final double rating = double.parse(
      (3.8 + ((hash % 13) / 10.0)).toStringAsFixed(1),
    );
    final int reviews = 10 + (hash % 201);
    final int timeMin = 20 + ((hash % 9) * 5);

    return Recipe(
      id: id,
      title: name,
      description: description,
      image: imageUrl,
      category: category,
      cuisine: origin,
      meal: MealType.values[hash % MealType.values.length],
      mainIngredient: 'Lainnya',
      rating: rating,
      reviews: reviews,
      timeMin: timeMin,
      servings: servings,
      kcal: kcal,
      difficulty: difficulty,
      ingredients: ingredients,
      steps: steps,
    );
  }
}

/// Implementasi utama RecipeService dengan integrasi API, pagination, caching Hive,
/// dan mekanisme fallback berantai (API #1 -> API #2 -> Cache -> Local Seed).
class ApiRecipeService implements RecipeService {
  final Dio _dio;
  final Ref? _ref;
  final FoodieBoxes? _boxes;
  final LocalRecipeService _localService;
  final void Function(String message)? _onFallbackToast;

  CancelToken? _searchCancelToken;
  bool _fallbackToastShown = false;

  ApiRecipeService({
    Ref? ref,
    FoodieBoxes? boxes,
    LocalRecipeService? localService,
    void Function(String message)? onFallbackToast,
    Dio? dio,
  }) : _ref = ref,
       // ignore: prefer_initializing_formals
       _boxes = boxes,
       _localService = localService ?? LocalRecipeService(ref),
       // ignore: prefer_initializing_formals
       _onFallbackToast = onFallbackToast,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: kRecipeApiBase,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 10),
             ),
           );

  void _showFallbackToastOnce() {
    if (!_fallbackToastShown) {
      _fallbackToastShown = true;
      _onFallbackToast?.call('Memakai data cadangan');
      if (_ref != null) {
        try {
          _ref
              .read(recipeFallbackToastProvider.notifier)
              .show('Memakai data cadangan');
        } catch (_) {}
      }
    }
  }

  /// Reset toast fallback agar dapat muncul kembali bila ada kegagalan berikutnya
  void resetFallbackToastFlag() {
    _fallbackToastShown = false;
  }

  Box? get _recipesBox {
    if (_boxes != null) return _boxes.recipes;
    if (_ref != null) {
      try {
        return _ref.read(recipesBoxProvider);
      } catch (_) {}
    }
    return null;
  }

  Box? get _recipeCacheBox {
    if (_boxes != null) return _boxes.recipeCache;
    if (_ref != null) {
      try {
        return _ref.read(recipeCacheBoxProvider);
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<List<Recipe>> list({
    String? q,
    MealType? meal,
    String? category,
    String? cuisine,
    String? mainIngredient,
    Difficulty? difficulty,
    int? maxTimeMin,
    int? minTimeMin,
    int page = 1,
    int limit = 10,
  }) async {
    // Jika environment menetapkan mode local, gunakan LocalRecipeService langsung
    if (kRecipeSource == 'local') {
      return _localService.list(
        q: q,
        meal: meal,
        category: category,
        cuisine: cuisine,
        mainIngredient: mainIngredient,
        difficulty: difficulty,
        maxTimeMin: maxTimeMin,
        minTimeMin: minTimeMin,
      );
    }

    // 1. Coba fetch dari API #1
    try {
      _searchCancelToken?.cancel();
      _searchCancelToken = CancelToken();

      final fetchLimit =
          (category != null || cuisine != null || mainIngredient != null)
          ? 100
          : (limit > 100 ? 100 : limit);

      final queryParams = <String, dynamic>{
        'scope': 'INDONESIA',
        'limit': fetchLimit,
        'page': page,
      };

      if (q != null && q.trim().isNotEmpty) {
        queryParams['search'] = q.trim();
      }

      final response = await _dio.get(
        '/recipes',
        queryParameters: queryParams,
        cancelToken: _searchCancelToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['data'] is List) {
          final items = data['data'] as List;
          final List<Recipe> recipes = items
              .whereType<Map<String, dynamic>>()
              .map((item) => ResepMasakanApiAdapter.fromJson(item))
              .toList();

          // Simpan ke Cache Hive: box recipes (detail) dan box recipeCache (list TTL 24 jam)
          await _saveListToCache(
            key:
                'list_p${page}_q${q ?? ''}_c${category ?? ''}_cu${cuisine ?? ''}',
            recipes: recipes,
          );

          return _filterClientSide(
            recipes: recipes,
            meal: meal,
            category: category,
            cuisine: cuisine,
            mainIngredient: mainIngredient,
            difficulty: difficulty,
            minTimeMin: minTimeMin,
            maxTimeMin: maxTimeMin,
          );
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return [];
      }
      // API #1 gagal, lanjut ke fallback berantai
    } catch (_) {}

    // 2. Coba API #2 (Masak Apa) sebagai fallback ke-2
    try {
      final api2Dio = Dio(
        BaseOptions(
          baseUrl: 'https://masak-apa.tomorisakura.vercel.app/api',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final res2 = await api2Dio.get(
        q != null && q.isNotEmpty ? '/search/?q=$q' : '/recipes',
      );
      if (res2.statusCode == 200 && res2.data != null) {
        final results = res2.data['results'];
        if (results is List && results.isNotEmpty) {
          final List<Recipe> recipes = results
              .whereType<Map<String, dynamic>>()
              .map((item) => MasakApaApiAdapter.fromJson(item))
              .toList();
          _showFallbackToastOnce();
          return _filterClientSide(
            recipes: recipes,
            meal: meal,
            category: category,
            cuisine: cuisine,
            mainIngredient: mainIngredient,
            difficulty: difficulty,
            minTimeMin: minTimeMin,
            maxTimeMin: maxTimeMin,
          );
        }
      }
    } catch (_) {}

    // 3. Coba Cache Hive
    final cached = _readListFromCache(
      'list_p${page}_q${q ?? ''}_c${category ?? ''}_cu${cuisine ?? ''}',
    );
    if (cached != null && cached.isNotEmpty) {
      _showFallbackToastOnce();
      return _filterClientSide(
        recipes: cached,
        meal: meal,
        category: category,
        cuisine: cuisine,
        mainIngredient: mainIngredient,
        difficulty: difficulty,
        minTimeMin: minTimeMin,
        maxTimeMin: maxTimeMin,
      );
    }

    // 4. Fallback akhir ke LocalRecipeService (seed)
    _showFallbackToastOnce();
    return _localService.list(
      q: q,
      meal: meal,
      category: category,
      cuisine: cuisine,
      mainIngredient: mainIngredient,
      difficulty: difficulty,
      minTimeMin: minTimeMin,
      maxTimeMin: maxTimeMin,
    );
  }

  @override
  Future<Recipe?> getById(String id) async {
    // 0. Jika resep lokal/seed/buatan user
    if (!id.startsWith('api:')) {
      return _localService.getById(id);
    }

    // 1. Cek cache offline permanen di box 'recipes'
    Recipe? partialCachedRecipe;
    try {
      final recipesBox = _recipesBox;
      if (recipesBox != null) {
        final raw = recipesBox.get(id);
        if (raw is Map) {
          final cached = Recipe.fromJson(Map<String, dynamic>.from(raw));
          // Hanya gunakan cache jika SUDAH memiliki detail lengkap (bahan & langkah)
          if (cached.ingredients.isNotEmpty && cached.steps.isNotEmpty) {
            return cached;
          }
          partialCachedRecipe = cached;
        }
      }
    } catch (_) {}

    // 2. Fetch detail lengkap dari API #1 (/recipes/{slug})
    final slug = id.substring('api:'.length);
    try {
      final response = await _dio.get('/recipes/$slug');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['data'] is Map) {
          final recipe = ResepMasakanApiAdapter.fromJson(
            Map<String, dynamic>.from(data['data'] as Map),
          );
          // Simpan ke box recipes (detail permanen offline dengan bahan & langkah)
          final recipesBox = _recipesBox;
          if (recipesBox != null) {
            await recipesBox.put(recipe.id, recipe.toJson());
          }
          final cacheBox = _recipeCacheBox;
          if (cacheBox != null) {
            await RecipeCacheService.saveSummary(cacheBox, recipe);
          }
          return recipe;
        }
      }
    } catch (e) {
      debugPrint('Error fetching recipe detail from API ($slug): $e');
    }

    // 3. Fallback jika offline / fetch gagal:
    // Gunakan partialCachedRecipe jika ada
    if (partialCachedRecipe != null &&
        (partialCachedRecipe.ingredients.isNotEmpty ||
            partialCachedRecipe.steps.isNotEmpty)) {
      return partialCachedRecipe;
    }

    // Fallback akhir ke seedRecipes lokal
    _showFallbackToastOnce();
    final localFallback = await _localService.getById(id);
    if (localFallback != null) {
      return localFallback;
    }

    return partialCachedRecipe;
  }

  @override
  Future<List<Recipe>> popular({int limit = 10}) async {
    final recipes = await list(limit: 20);
    final sorted = List<Recipe>.from(recipes)
      ..sort((a, b) => (b.rating * b.reviews).compareTo(a.rating * a.reviews));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Recipe>> inspiration(String dateKey, {int limit = 5}) async {
    final effectiveLimit = limit.clamp(1, 5);
    final cacheBox = _recipeCacheBox;
    final cacheKey = 'foodie:inspiration:$dateKey';

    // 1. Cek persist cache untuk tanggal ini
    if (cacheBox != null) {
      try {
        final cached = cacheBox.get(cacheKey);
        if (cached is List && cached.isNotEmpty) {
          final list = cached
              .whereType<Map>()
              .map((item) => Recipe.fromJson(Map<String, dynamic>.from(item)))
              .toList();
          if (list.isNotEmpty) {
            return list.take(effectiveLimit).toList();
          }
        }
      } catch (_) {}
    }

    // 2. Jika belum ada di cache untuk tanggal ini, fetch kandidat dari API #1
    try {
      final response = await _dio.get(
        '/recipes',
        queryParameters: {'scope': 'INDONESIA', 'limit': 50, 'page': 1},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['data'] is List) {
          final items = data['data'] as List;
          final recipes = items
              .whereType<Map<String, dynamic>>()
              .map((item) => ResepMasakanApiAdapter.fromJson(item))
              .toList();

          if (recipes.isNotEmpty) {
            // Acak deterministik per hari dari seed dateKey (yyyy-MM-dd)
            final seed = dateKey.codeUnits.fold<int>(
              0,
              (prev, elem) => prev + elem,
            );
            final shuffled = List<Recipe>.from(recipes)..shuffle(Random(seed));

            // Maksimal 5 resep unik
            final selected = <Recipe>[];
            final seenIds = <String>{};
            for (final r in shuffled) {
              if (seenIds.add(r.id)) {
                selected.add(r);
                if (selected.length >= effectiveLimit) break;
              }
            }

            // Simpan ke cache persist
            if (cacheBox != null) {
              await RecipeCacheService.saveSummaries(cacheBox, selected);
              await cacheBox.put(
                cacheKey,
                selected.map((r) => r.toJson()).toList(),
              );

              // Bersihkan cache tanggal lama
              final keysToDelete = <dynamic>[];
              for (final key in cacheBox.keys) {
                final keyStr = key.toString();
                if (keyStr.startsWith('foodie:inspiration:') &&
                    keyStr != cacheKey) {
                  keysToDelete.add(key);
                }
              }
              for (final k in keysToDelete) {
                await cacheBox.delete(k);
              }
            }

            return selected;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching inspiration from API: $e');
    }

    // 3. Fallback jika API gagal: pakai daftar terakhir yang tersimpan di cache
    if (cacheBox != null) {
      try {
        for (final key in cacheBox.keys) {
          final keyStr = key.toString();
          if (keyStr.startsWith('foodie:inspiration:')) {
            final cached = cacheBox.get(key);
            if (cached is List && cached.isNotEmpty) {
              final list = cached
                  .whereType<Map>()
                  .map(
                    (item) => Recipe.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .toList();
              if (list.isNotEmpty) {
                _showFallbackToastOnce();
                return list.take(effectiveLimit).toList();
              }
            }
          }
        }
      } catch (_) {}
    }

    // 4. Bila tidak ada cache sama sekali, fallback ke seed lokal
    _showFallbackToastOnce();
    return _localService.inspiration(dateKey, limit: effectiveLimit);
  }

  List<Recipe> _filterClientSide({
    required List<Recipe> recipes,
    MealType? meal,
    String? category,
    String? cuisine,
    String? mainIngredient,
    Difficulty? difficulty,
    int? minTimeMin,
    int? maxTimeMin,
  }) {
    var results = List<Recipe>.from(recipes);

    if (meal != null) {
      results = results.where((r) => r.meal == meal).toList();
    }
    if (category != null && category.trim().isNotEmpty) {
      final cat = category.trim().toLowerCase();
      results = results
          .where(
            (r) =>
                r.category.toLowerCase() == cat ||
                r.category.toLowerCase().contains(cat),
          )
          .toList();
    }
    if (cuisine != null && cuisine.trim().isNotEmpty) {
      final cui = cuisine.trim().toLowerCase();
      results = results
          .where(
            (r) =>
                r.cuisine.toLowerCase() == cui ||
                r.cuisine.toLowerCase().contains(cui),
          )
          .toList();
    }
    if (mainIngredient != null && mainIngredient.trim().isNotEmpty) {
      final mi = mainIngredient.trim().toLowerCase();
      results = results.where((r) {
        return r.mainIngredient.toLowerCase() == mi ||
            r.ingredients.any((i) => i.name.toLowerCase().contains(mi));
      }).toList();
    }
    if (difficulty != null) {
      results = results.where((r) => r.difficulty == difficulty).toList();
    }
    if (minTimeMin != null && minTimeMin > 0) {
      results = results.where((r) => r.timeMin >= minTimeMin).toList();
    }
    if (maxTimeMin != null && maxTimeMin > 0) {
      results = results.where((r) => r.timeMin <= maxTimeMin).toList();
    }
    return results;
  }

  Future<void> _saveListToCache({
    required String key,
    required List<Recipe> recipes,
  }) async {
    try {
      final cacheBox = _recipeCacheBox;
      final recipesBox = _recipesBox;

      if (cacheBox != null) {
        await RecipeCacheService.saveSummaries(cacheBox, recipes);
        await cacheBox.put(key, {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': recipes.map((r) => r.toJson()).toList(),
        });
      }

      // Simpan ke box 'recipes' hanya jika belum ada atau belum punya detail lengkap
      if (recipesBox != null) {
        for (final r in recipes) {
          final existing = recipesBox.get(r.id);
          if (existing is Map) {
            final existingIngredients = existing['ingredients'] as List?;
            if (existingIngredients != null && existingIngredients.isNotEmpty) {
              continue; // Pertahankan detail resep yang sudah lengkap!
            }
          }
          await recipesBox.put(r.id, r.toJson());
        }
      }
    } catch (_) {}
  }

  List<Recipe>? _readListFromCache(String key) {
    try {
      final cacheBox = _recipeCacheBox;
      if (cacheBox == null) return null;
      final raw = cacheBox.get(key);
      if (raw is Map) {
        final timestamp = raw['timestamp'] as int? ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        // TTL 24 jam (86.400.000 ms)
        if (age < 86400000 && raw['data'] is List) {
          final list = raw['data'] as List;
          return list
              .map(
                (item) =>
                    Recipe.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }
}
