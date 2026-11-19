import 'enums.dart';
import 'ingredient.dart';
import 'recipe_step.dart';

/// Model Resep utama sesuai PRD §9
class Recipe {
  final String id;
  final String title;
  final String description;
  final String? image; // null/kosong = placeholder abu-abu
  final String category;
  final String cuisine;
  final MealType meal;
  final String mainIngredient;
  final double rating;
  final int reviews;
  final int timeMin;
  final int servings;
  final int kcal;
  final Difficulty difficulty;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final String? authorId;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    this.image,
    required this.category,
    required this.cuisine,
    required this.meal,
    required this.mainIngredient,
    required this.rating,
    required this.reviews,
    required this.timeMin,
    required this.servings,
    required this.kcal,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    this.authorId,
  });

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? image,
    String? category,
    String? cuisine,
    MealType? meal,
    String? mainIngredient,
    double? rating,
    int? reviews,
    int? timeMin,
    int? servings,
    int? kcal,
    Difficulty? difficulty,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    String? authorId,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      category: category ?? this.category,
      cuisine: cuisine ?? this.cuisine,
      meal: meal ?? this.meal,
      mainIngredient: mainIngredient ?? this.mainIngredient,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      timeMin: timeMin ?? this.timeMin,
      servings: servings ?? this.servings,
      kcal: kcal ?? this.kcal,
      difficulty: difficulty ?? this.difficulty,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      authorId: authorId ?? this.authorId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image': image,
      'category': category,
      'cuisine': cuisine,
      'meal': meal.name,
      'mainIngredient': mainIngredient,
      'rating': rating,
      'reviews': reviews,
      'timeMin': timeMin,
      'servings': servings,
      'kcal': kcal,
      'difficulty': difficulty.name,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'steps': steps.map((s) => s.toJson()).toList(),
      'authorId': authorId,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      image: json['image'] as String?,
      category: json['category'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? '',
      meal: MealType.fromString(json['meal'] as String?),
      mainIngredient: json['mainIngredient'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      timeMin: (json['timeMin'] as num?)?.toInt() ?? 0,
      servings: (json['servings'] as num?)?.toInt() ?? 0,
      kcal: (json['kcal'] as num?)?.toInt() ?? 0,
      difficulty: Difficulty.fromString(json['difficulty'] as String?),
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map((item) => Ingredient.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map((item) => RecipeStep.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      authorId: json['authorId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recipe && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
