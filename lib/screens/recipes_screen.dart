import 'package:flutter/material.dart';

import '../data/favorite_recipes_store.dart';
import '../data/fridge_store.dart';
import '../data/profile_store.dart';
import '../data/recipe_notes_store.dart';
import '../data/shopping_list_store.dart';
import '../models/food.dart';
import '../models/shopping_item.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({
    super.key,
    required this.store,
    required this.profileStore,
    required this.shoppingListStore,
    required this.favoriteRecipesStore,
    required this.recipeNotesStore,
  });

  final FridgeStore store;
  final ProfileStore profileStore;
  final ShoppingListStore shoppingListStore;
  final FavoriteRecipesStore favoriteRecipesStore;
  final RecipeNotesStore recipeNotesStore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, profileStore, shoppingListStore, favoriteRecipesStore]),
      builder: (context, _) => _RecipesContent(
        store: store,
        profileStore: profileStore,
        shoppingListStore: shoppingListStore,
        favoriteRecipesStore: favoriteRecipesStore,
        recipeNotesStore: recipeNotesStore,
      ),
    );
  }
}

class _RecipesContent extends StatelessWidget {
  const _RecipesContent({
    required this.store,
    required this.profileStore,
    required this.shoppingListStore,
    required this.favoriteRecipesStore,
    required this.recipeNotesStore,
  });

  final FridgeStore store;
  final ProfileStore profileStore;
  final ShoppingListStore shoppingListStore;
  final FavoriteRecipesStore favoriteRecipesStore;
  final RecipeNotesStore recipeNotesStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foods = store.foods;
    final profile = profileStore.profile;
    final recipes = RecipeCatalog.suggestFor(foods, profile: profile);
    final favoriteRecipes = RecipeCatalog.favoriteRecipesFor(
      favoriteRecipesStore.favoriteNames,
    );

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Recettes'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
      ),
      body: foods.isEmpty && favoriteRecipes.isEmpty
          ? const _EmptyRecipesView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (favoriteRecipes.isNotEmpty) ...[
                  Text(
                    'Mes recettes favorites',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tes recettes gardées de côté, même si des ingrédients manquent.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...favoriteRecipes.map(
                    (recipe) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecipeCard(
                        recipe: recipe,
                        store: store,
                        shoppingListStore: shoppingListStore,
                        favoriteRecipesStore: favoriteRecipesStore,
                        recipeNotesStore: recipeNotesStore,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (foods.isEmpty)
                  const _EmptyRecipesView(compact: true)
                else if (recipes.isEmpty)
                  const _NoMatchingRecipesView(compact: true)
                else ...[
                  Text(
                    'Idées avec ton frigo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${recipes.length} recette${recipes.length > 1 ? 's' : ''} '
                    'basée${recipes.length > 1 ? 's' : ''} sur '
                    '${foods.length} aliment${foods.length > 1 ? 's' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileRecipeBanner(profile: profile),
                  const SizedBox(height: 20),
                  ...recipes.map(
                    (recipe) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecipeCard(
                        recipe: recipe,
                        store: store,
                        shoppingListStore: shoppingListStore,
                        favoriteRecipesStore: favoriteRecipesStore,
                        recipeNotesStore: recipeNotesStore,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Catalogue fictif — remplaçable par une API ou un moteur de suggestions.
// ---------------------------------------------------------------------------

class RecipeIngredient {
  const RecipeIngredient({
    required this.label,
    required this.keywords,
    required this.requiredAmount,
    required this.requiredUnit,
  });

  final String label;
  final List<String> keywords;
  final double requiredAmount;
  final String requiredUnit;

  String get requiredAmountLabel => MeasurementHelper.label(requiredAmount, requiredUnit);
}

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.emoji,
    required this.name,
    required this.time,
    required this.description,
    required this.requiredIngredients,
    required this.steps,
    this.difficulty = RecipeDifficulty.easy,
    this.requiresOven = false,
    this.requiresAirfryer = false,
    this.requiresMicrowave = false,
  });

  final String emoji;
  final String name;
  final String time;
  final String description;
  final List<RecipeIngredient> requiredIngredients;
  final List<String> steps;
  final RecipeDifficulty difficulty;
  final bool requiresOven;
  final bool requiresAirfryer;
  final bool requiresMicrowave;

  List<String> get ingredients =>
      requiredIngredients.map((item) => item.label).toList();

  int get estimatedMinutes {
    final match = RegExp(r'\d+').firstMatch(time);
    return match == null ? 999 : int.parse(match.group(0)!);
  }
}

enum RecipeDifficulty { beginner, easy, intermediate }

class RecipeIngredientMatch {
  const RecipeIngredientMatch({
    required this.ingredient,
    required this.isAvailable,
    this.matchedFoodName,
    this.matchedFoodId,
    this.matchedFoodAmount,
    this.matchedFoodUnit,
    this.matchedFoodAmountLabel,
  });

  final RecipeIngredient ingredient;
  final bool isAvailable;
  final String? matchedFoodName;
  final String? matchedFoodId;
  final double? matchedFoodAmount;
  final String? matchedFoodUnit;
  final String? matchedFoodAmountLabel;

  bool get hasFoodInFridge => matchedFoodId != null;

  double get missingAmount {
    final amount = matchedFoodAmount ?? 0;
    final missing = ingredient.requiredAmount - amount;
    return missing < 0 ? 0 : missing;
  }

  String get requiredDisplayLabel =>
      '${ingredient.label} ${ingredient.requiredAmountLabel}';

  /// Exemple : « Pâtes 500/500 g » ou « Jambon 1/2 tranches ».
  String get fridgeDisplayLabel {
    if (matchedFoodName == null) return requiredDisplayLabel;

    if (matchedFoodUnit != null &&
        RecipeCatalog.normalizeUnitForDisplay(matchedFoodUnit!) ==
            RecipeCatalog.normalizeUnitForDisplay(ingredient.requiredUnit) &&
        matchedFoodAmount != null) {
      final current = MeasurementHelper.inputValue(matchedFoodAmount!);
      final required = MeasurementHelper.inputValue(ingredient.requiredAmount);
      final unit = MeasurementHelper.label(ingredient.requiredAmount, ingredient.requiredUnit)
          .replaceFirst(required, '')
          .trim();
      return '$matchedFoodName $current/$required $unit';
    }

    final current = matchedFoodAmountLabel ?? 'quantité inconnue';
    return '$matchedFoodName $current / ${ingredient.requiredAmountLabel}';
  }

  String get chipLabel => hasFoodInFridge ? fridgeDisplayLabel : requiredDisplayLabel;
}

abstract final class RecipeCatalog {
  static List<RecipeSuggestion> suggestFor(
    List<FoodItem> foods, {
    ProfileData? profile,
  }) {
    if (foods.isEmpty) return [];

    final names = foods.map((food) => food.name.toLowerCase()).toList();
    final recipes = _candidateRecipesForNames(names);

    final filtered = _filterForProfile(recipes, profile);
    final sorted = _sortForProfile(filtered, profile, foods);

    return sorted.take(5).toList();
  }

  static List<RecipeSuggestion> favoriteRecipesFor(List<String> favoriteNames) {
    if (favoriteNames.isEmpty) return [];

    final wanted = favoriteNames.toSet();
    return _allRecipes()
        .where((recipe) => wanted.contains(recipe.name))
        .toList();
  }

  static List<RecipeSuggestion> _allRecipes() {
    return _candidateRecipesForNames(const [
      'pâtes',
      'jambon',
      'salade',
      'œufs',
      'tomates',
      'lait',
      'yaourt',
      'steak',
      'riz',
      'poulet',
      'courgettes',
      'pain',
      'mozzarella',
      'tortillas',
      'avocat',
    ]);
  }

  static List<RecipeSuggestion> _candidateRecipesForNames(List<String> names) {
    final recipes = <RecipeSuggestion>[];

    void addIf(bool condition, RecipeSuggestion recipe) {
      if (condition && !recipes.any((item) => item.name == recipe.name)) {
     recipes.add(recipe);
   }
}

    addIf(
      _hasAny(names, ['pâte', 'pate', 'pâtes', 'pates']),
      const RecipeSuggestion(
        emoji: '🍝',
        name: 'Pâtes à la crème',
        time: '20 min',
        description:
            'Des pâtes onctueuses avec la crème et le fromage déjà dans ton frigo.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Pâtes',
            keywords: ['pâte', 'pate', 'pâtes', 'pates'],
            requiredAmount: 500,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Crème fraîche',
            keywords: ['crème', 'creme'],
            requiredAmount: 20,
            requiredUnit: 'cl',
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
            requiredAmount: 100,
            requiredUnit: 'g',
          ),
        ],
        steps: [
          'Fais cuire les pâtes dans une grande casserole d’eau bouillante salée.',
          'Égoutte les pâtes en gardant un peu d’eau de cuisson.',
          'Dans la poêle, fais chauffer la crème fraîche à feu doux.',
          'Ajoute le fromage râpé et mélange jusqu’à obtenir une sauce lisse.',
          'Incorpore les pâtes, ajuste avec l’eau de cuisson si besoin, puis sers.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['jambon']),
      const RecipeSuggestion(
        emoji: '🥪',
        name: 'Croque jambon express',
        time: '12 min',
        description:
            'Un classique rapide pour utiliser ton jambon avant la date limite.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Jambon',
            keywords: ['jambon'],
            requiredAmount: 2,
            requiredUnit: 'tranches',
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
            requiredAmount: 100,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Pain',
            keywords: ['pain'],
            requiredAmount: 2,
            requiredUnit: 'tranches',
          ),
        ],
        steps: [
          'Tartine deux tranches de pain avec un peu de crème ou de beurre.',
          'Ajoute le jambon et le fromage entre les tranches.',
          'Fais griller 3 à 4 minutes de chaque côté à la poêle.',
          'Sers chaud lorsque le fromage est fondant.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['salade']),
      const RecipeSuggestion(
        emoji: '🥗',
        name: 'Salade fraîche du frigo',
        time: '10 min',
        description:
            'Une salade légère et croquante avec les produits frais disponibles.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Salade',
            keywords: ['salade'],
            requiredAmount: 1,
            requiredUnit: 'unité',
          ),
          RecipeIngredient(
            label: 'Tomates',
            keywords: ['tomate'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
          RecipeIngredient(
            label: 'Œufs',
            keywords: ['œuf', 'oeuf'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
        ],
        steps: [
          'Lave et essore la salade, puis place-la dans un saladier.',
          'Coupe les tomates en quartiers et ajoute-les.',
          'Cuis les œufs 8 minutes, écale-les et coupe-les en deux.',
          'Assaisonne avec huile, vinaigre, sel et poivre avant de servir.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['œuf', 'oeuf', 'œufs', 'oeufs']),
      const RecipeSuggestion(
        emoji: '🍳',
        name: 'Omelette fromage',
        time: '10 min',
        description:
            'Parfaite pour un repas express avec tes produits laitiers.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Œufs',
            keywords: ['œuf', 'oeuf'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
            requiredAmount: 100,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Crème fraîche',
            keywords: ['crème', 'creme'],
            requiredAmount: 20,
            requiredUnit: 'cl',
          ),
        ],
        steps: [
          'Bat les œufs avec une pincée de sel et de poivre.',
          'Verse le mélange dans une poêle chaude légèrement beurrée.',
          'Lorsque l’omelette commence à prendre, ajoute le fromage.',
          'Plie l’omelette en deux et laisse fondre 1 minute avant de servir.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['tomate', 'tomates']),
      const RecipeSuggestion(
        emoji: '🍅',
        name: 'Pâtes tomate fromage',
        time: '15 min',
        description:
            'Un plat simple qui combine tes ingrédients du quotidien.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Pâtes',
            keywords: ['pâte', 'pate', 'pâtes', 'pates'],
            requiredAmount: 500,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Tomates',
            keywords: ['tomate'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
            requiredAmount: 100,
            requiredUnit: 'g',
          ),
        ],
        steps: [
          'Cuire les pâtes al dente dans l’eau bouillante salée.',
          'Coupe les tomates et fais-les revenir 5 minutes à la poêle.',
          'Égoutte les pâtes et mélange-les avec les tomates.',
          'Parseme de fromage râpé et sers immédiatement.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['lait', 'yaourt']),
      const RecipeSuggestion(
        emoji: '🥣',
        name: 'Gratin crémeux',
        time: '25 min',
        difficulty: RecipeDifficulty.intermediate,
        requiresOven: true,
        description: 'Un gratin réconfortant avec tes produits laitiers.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Pommes de terre',
            keywords: ['pomme de terre', 'pommes de terre'],
            requiredAmount: 500,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Crème fraîche',
            keywords: ['crème', 'creme'],
            requiredAmount: 20,
            requiredUnit: 'cl',
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
            requiredAmount: 100,
            requiredUnit: 'g',
          ),
        ],
        steps: [
          'Préchauffe le four à 200 °C.',
          'Coupe les pommes de terre en fines rondelles.',
          'Dispose-les dans un plat, nappe de crème et saupoudre de fromage.',
          'Enfourne 20 minutes jusqu’à ce que le gratin soit doré.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['steak', 'viande', 'haché', 'hache']),
      const RecipeSuggestion(
        emoji: '🥩',
        name: 'Bolognaise express',
        time: '18 min',
        difficulty: RecipeDifficulty.intermediate,
        description: 'Idéal pour consommer ta viande en priorité.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Steak haché',
            keywords: ['steak', 'haché', 'hache', 'viande'],
            requiredAmount: 250,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Tomates',
            keywords: ['tomate'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
          RecipeIngredient(
            label: 'Pâtes',
            keywords: ['pâte', 'pate', 'pâtes', 'pates'],
            requiredAmount: 500,
            requiredUnit: 'g',
          ),
        ],
        steps: [
          'Fais revenir le steak haché dans une poêle chaude.',
          'Ajoute les tomates coupées et laisse mijoter 8 minutes.',
          'Pendant ce temps, cuire les pâtes.',
          'Mélange les pâtes avec la sauce et sers chaud.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['riz']) || _hasAny(names, ['poulet']),
      const RecipeSuggestion(
        emoji: '🍚',
        name: 'Riz sauté au poulet',
        time: '18 min',
        description:
            'Un plat complet et rapide avec du riz, du poulet et des légumes.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Riz',
            keywords: ['riz'],
            requiredAmount: 300,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Poulet',
            keywords: ['poulet'],
            requiredAmount: 300,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Courgettes',
            keywords: ['courgette'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
        ],
        steps: [
          'Fais cuire le riz dans une casserole d’eau salée.',
          'Coupe le poulet et les courgettes en morceaux.',
          'Fais revenir le poulet dans une poêle chaude jusqu’à ce qu’il soit doré.',
          'Ajoute les courgettes et cuis encore quelques minutes.',
          'Mélange avec le riz, assaisonne et sers chaud.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['poulet']) && _hasAny(names, ['courgette']),
      const RecipeSuggestion(
        emoji: '🍗',
        name: 'Poulet courgettes Airfryer',
        time: '16 min',
        requiresAirfryer: true,
        description:
            'Une option croustillante et pratique si tu as un Airfryer.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Poulet',
            keywords: ['poulet'],
            requiredAmount: 300,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Courgettes',
            keywords: ['courgette'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
            requiredAmount: 50,
            requiredUnit: 'g',
          ),
        ],
        steps: [
          'Coupe le poulet et les courgettes en morceaux réguliers.',
          'Assaisonne avec sel, poivre et un filet d’huile.',
          'Place le tout dans l’Airfryer 12 à 15 minutes.',
          'Ajoute un peu d’emmental en fin de cuisson si tu en as.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['pain']) || _hasAny(names, ['mozzarella']),
      const RecipeSuggestion(
        emoji: '🍅',
        name: 'Tartines tomate mozzarella',
        time: '8 min',
        difficulty: RecipeDifficulty.beginner,
        description:
            'Des tartines très rapides avec pain, tomates et mozzarella.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Pain',
            keywords: ['pain'],
            requiredAmount: 2,
            requiredUnit: 'tranches',
          ),
          RecipeIngredient(
            label: 'Tomates',
            keywords: ['tomate'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
          RecipeIngredient(
            label: 'Mozzarella',
            keywords: ['mozzarella'],
            requiredAmount: 125,
            requiredUnit: 'g',
          ),
        ],
        steps: [
          'Fais légèrement griller les tranches de pain.',
          'Coupe les tomates et la mozzarella en tranches.',
          'Dispose-les sur le pain avec sel, poivre et un filet d’huile.',
          'Sers immédiatement avec une salade si tu en as.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['tortilla', 'tortillas']) || _hasAny(names, ['avocat']),
      const RecipeSuggestion(
        emoji: '🌯',
        name: 'Wrap steak avocat',
        time: '15 min',
        description:
            'Un wrap rapide et rassasiant avec steak haché, avocat et fromage.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Tortillas',
            keywords: ['tortilla', 'tortillas'],
            requiredAmount: 2,
            requiredUnit: 'unités',
          ),
          RecipeIngredient(
            label: 'Steak haché',
            keywords: ['steak', 'haché', 'hache', 'viande'],
            requiredAmount: 250,
            requiredUnit: 'g',
          ),
          RecipeIngredient(
            label: 'Avocat',
            keywords: ['avocat'],
            requiredAmount: 1,
            requiredUnit: 'unité',
          ),
        ],
        steps: [
          'Fais cuire le steak haché dans une poêle chaude.',
          'Écrase l’avocat avec un peu de sel et de poivre.',
          'Garnis les tortillas avec la viande et l’avocat.',
          'Roule les wraps et chauffe-les une minute à la poêle.',
        ],
      ),
    );

    addIf(
      _hasAny(names, ['yaourt']),
      const RecipeSuggestion(
        emoji: '🥣',
        name: 'Yaourt gourmand express',
        time: '5 min',
        difficulty: RecipeDifficulty.beginner,
        description:
            'Une idée ultra rapide pour utiliser les yaourts avant leur date.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Yaourt nature',
            keywords: ['yaourt'],
            requiredAmount: 1,
            requiredUnit: 'unité',
          ),
          RecipeIngredient(
            label: 'Pain',
            keywords: ['pain'],
            requiredAmount: 1,
            requiredUnit: 'tranche',
          ),
          RecipeIngredient(
            label: 'Tomates',
            keywords: ['tomate'],
            requiredAmount: 1,
            requiredUnit: 'unité',
          ),
        ],
        steps: [
          'Verse le yaourt dans un bol.',
          'Ajoute ce que tu as sous la main pour compléter le repas.',
          'Sers frais, en collation ou en accompagnement léger.',
        ],
      ),
    );


    return recipes;
  }


  static List<RecipeIngredientMatch> matchIngredients(
    RecipeSuggestion recipe,
    List<FoodItem> foods,
  ) {
    final foodNames = foods.map((food) => food.name.toLowerCase()).toList();

    return recipe.requiredIngredients.map((ingredient) {
      for (final food in foods) {
        final name = food.name.toLowerCase();
        if (ingredient.keywords.any((keyword) => name.contains(keyword))) {
          final hasEnough =
            normalizeUnitForDisplay(food.unit) ==
              normalizeUnitForDisplay(ingredient.requiredUnit) &&
            food.amount >= ingredient.requiredAmount;

          return RecipeIngredientMatch(
            ingredient: ingredient,
            isAvailable: hasEnough,
            matchedFoodName: food.name,
            matchedFoodId: food.id,
            matchedFoodAmount: food.amount,
            matchedFoodUnit: food.unit,
            matchedFoodAmountLabel: food.amountLabel,
          );
        }
      }

      return RecipeIngredientMatch(
        ingredient: ingredient,
        isAvailable: false,
      );
    }).toList();
  }

  static List<String> matchedFoodIds(
    RecipeSuggestion recipe,
    List<FoodItem> foods,
  ) {
    return matchIngredients(recipe, foods)
        .where((match) => match.isAvailable && match.matchedFoodId != null)
        .map((match) => match.matchedFoodId!)
        .toSet()
        .toList();
  }

  static Map<String, double> consumptionAmounts(
    RecipeSuggestion recipe,
    List<FoodItem> foods,
  ) {
    final result = <String, double>{};

    for (final match in matchIngredients(recipe, foods)) {
      if (!match.isAvailable || match.matchedFoodId == null) continue;
      result[match.matchedFoodId!] = match.ingredient.requiredAmount.toDouble();
    }

    return result;
  }


  static List<ShoppingItem> missingShoppingItems(
    RecipeSuggestion recipe,
    List<FoodItem> foods,
  ) {
    return matchIngredients(recipe, foods)
        .where((match) => !match.isAvailable)
        .map((match) {
      final ingredient = match.ingredient;
      return ShoppingItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${ingredient.label}',
        name: ingredient.label,
        amount: match.missingAmount > 0
            ? match.missingAmount
            : ingredient.requiredAmount,
        unit: ingredient.requiredUnit,
      );
    }).toList();
  }

  static List<RecipeSuggestion> _filterForProfile(
    List<RecipeSuggestion> recipes,
    ProfileData? profile,
  ) {
    if (profile == null) return recipes;

    return recipes.where((recipe) {
      if (profile.cookingLevel == CookingLevel.beginner &&
          recipe.difficulty == RecipeDifficulty.intermediate) {
        return false;
      }

      if (recipe.requiresOven && !profile.hasOven) return false;
      if (recipe.requiresAirfryer && !profile.hasAirfryer) return false;
      if (recipe.requiresMicrowave && !profile.hasMicrowave) return false;

      return true;
    }).toList();
  }

  static List<RecipeSuggestion> _sortForProfile(
    List<RecipeSuggestion> recipes,
    ProfileData? profile,
    List<FoodItem> foods,
  ) {
    final sorted = [...recipes];

    if (profile == null) return sorted;

    if (profile.goal == ProfileGoal.saveTime) {
      sorted.sort((a, b) => a.estimatedMinutes.compareTo(b.estimatedMinutes));
      return sorted;
    }

    if (profile.goal == ProfileGoal.reduceWaste) {
      sorted.sort((a, b) {
        final urgencyA = _recipeUrgencyScore(a, foods);
        final urgencyB = _recipeUrgencyScore(b, foods);
        return urgencyB.compareTo(urgencyA);
      });
      return sorted;
    }

    if (profile.cookingLevel == CookingLevel.beginner) {
      sorted.sort((a, b) => a.estimatedMinutes.compareTo(b.estimatedMinutes));
    }

    return sorted;
  }

  static int _recipeUrgencyScore(RecipeSuggestion recipe, List<FoodItem> foods) {
    var score = 0;

    for (final match in matchIngredients(recipe, foods)) {
      if (!match.isAvailable || match.matchedFoodId == null) continue;

      final food = foods.firstWhere((item) => item.id == match.matchedFoodId);
      final days = ExpiryHelper.daysUntilExpiry(food.expiryDate);

      if (days <= 0) {
        score += 100;
      } else if (days == 1) {
        score += 60;
      } else if (days < 3) {
        score += 30;
      } else {
        score += 5;
      }
    }

    return score;
  }

  static String normalizeUnitForDisplay(String unit) {
  return unit
      .trim()
      .toLowerCase()
      .replaceAll('unités', 'unité')
      .replaceAll('tranches', 'tranche');
}

  static bool _hasAny(List<String> foodNames, List<String> keywords) {
    return keywords.any(
      (keyword) => foodNames.any((name) => name.contains(keyword)),
    );
  }
}

// ---------------------------------------------------------------------------
// Composants UI
// ---------------------------------------------------------------------------


class _ProfileRecipeBanner extends StatelessWidget {
  const _ProfileRecipeBanner({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adapté à ton profil : ${profile.cookingLevel.label.toLowerCase()}, '
              '${profile.goal.label.toLowerCase()}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.store,
    required this.shoppingListStore,
    required this.favoriteRecipesStore,
    required this.recipeNotesStore,
  });

  final RecipeSuggestion recipe;
  final FridgeStore store;
  final ShoppingListStore shoppingListStore;
  final FavoriteRecipesStore favoriteRecipesStore;
  final RecipeNotesStore recipeNotesStore;

  void _showRecipeDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _RecipeDetailSheet(
          recipe: recipe,
          store: store,
          shoppingListStore: shoppingListStore,
          favoriteRecipesStore: favoriteRecipesStore,
          recipeNotesStore: recipeNotesStore,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foods = store.foods;
    final matches = RecipeCatalog.matchIngredients(recipe, foods);
    final availableCount = matches.where((item) => item.isAvailable).length;
    final isFavorite = favoriteRecipesStore.isFavorite(recipe.name);

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _showRecipeDetails(context),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        recipe.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Avec ton frigo · $availableCount/${matches.length}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.time,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: isFavorite
                              ? 'Retirer des favoris'
                              : 'Ajouter aux favoris',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? const Color(0xFFE53935)
                                : colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => favoriteRecipesStore.toggleFavorite(recipe.name),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Ingrédients',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: matches
                      .map(
                        (match) => _IngredientChip(
                          label: match.chipLabel,
                          isAvailable: match.isAvailable,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => _showRecipeDetails(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Voir la recette'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({
    required this.label,
    required this.isAvailable,
  });

  final String label;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isAvailable ? const Color(0xFF43A047) : const Color(0xFFE53935);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CookedChoice { cancel, keep, remove }

class _RecipeDetailSheet extends StatelessWidget {
  const _RecipeDetailSheet({
    required this.recipe,
    required this.store,
    required this.shoppingListStore,
    required this.favoriteRecipesStore,
    required this.recipeNotesStore,
  });

  final RecipeSuggestion recipe;
  final FridgeStore store;
  final ShoppingListStore shoppingListStore;
  final FavoriteRecipesStore favoriteRecipesStore;
  final RecipeNotesStore recipeNotesStore;

  void _addMissingToShoppingList(BuildContext context) {
    final missingItems = RecipeCatalog.missingShoppingItems(recipe, store.foods);
    if (missingItems.isEmpty) return;

    shoppingListStore.addItems(missingItems);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text('Ingrédients ajoutés à la liste de courses'),
      ),
    );
  }

  Future<void> _onCooked(BuildContext sheetContext) async {
    final foods = store.foods;
    final availableMatches = RecipeCatalog.matchIngredients(recipe, foods)
        .where((match) => match.isAvailable)
        .toList();
    final consumptionAmounts = RecipeCatalog.consumptionAmounts(recipe, foods);

    final choice = await showDialog<_CookedChoice>(
      context: sheetContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ingrédients utilisés'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Veux-tu retirer du frigo les ingrédients utilisés ?',
              ),
              if (availableMatches.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableMatches
                      .map(
                        (match) => Chip(
                          label: Text(match.fridgeDisplayLabel),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _CookedChoice.cancel),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _CookedChoice.keep),
              child: const Text('Non, garder les aliments'),
            ),
            FilledButton(
              onPressed: consumptionAmounts.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, _CookedChoice.remove),
              child: const Text('Oui, retirer du frigo'),
            ),
          ],
        );
      },
    );

    if (choice == null || choice == _CookedChoice.cancel) return;

    if (choice == _CookedChoice.remove) {
      store.consumeFoodAmounts(consumptionAmounts);
    }

    if (sheetContext.mounted) Navigator.pop(sheetContext);

    if (!sheetContext.mounted) return;

    final message = choice == _CookedChoice.remove
        ? 'Bon appétit ! Les quantités utilisées ont été retirées du frigo.'
        : 'Bon appétit ! « ${recipe.name} » est noté.';

    ScaffoldMessenger.of(sheetContext).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foods = store.foods;
    final matches = RecipeCatalog.matchIngredients(recipe, foods);
    final available = matches.where((item) => item.isAvailable).toList();
    final missing = matches.where((item) => !item.isAvailable).toList();
    final isFavorite = favoriteRecipesStore.isFavorite(recipe.name);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recipe.emoji, style: const TextStyle(fontSize: 40)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    recipe.time,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Avec ton frigo',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: isFavorite
                              ? 'Retirer des favoris'
                              : 'Ajouter aux favoris',
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? const Color(0xFFE53935)
                                : colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => favoriteRecipesStore.toggleFavorite(recipe.name),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      recipe.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Depuis ton frigo',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (available.isEmpty)
                      Text(
                        'Aucun ingrédient disponible pour l’instant.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: available
                            .map(
                              (match) => _IngredientChip(
                                label: match.fridgeDisplayLabel,
                                isAvailable: true,
                              ),
                            )
                            .toList(),
                      ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Ingrédients manquants',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: missing
                            .map(
                              (match) => _IngredientChip(
                                label: match.chipLabel,
                                isAvailable: false,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        onPressed: () => _addMissingToShoppingList(context),
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Ajouter les manquants à ma liste de courses'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _RecipeNotesCard(
                      recipeName: recipe.name,
                      recipeNotesStore: recipeNotesStore,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Étapes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...recipe.steps.asMap().entries.map(
                      (entry) => _RecipeStepTile(
                        stepNumber: entry.key + 1,
                        text: entry.value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: FilledButton.icon(
                onPressed: () => _onCooked(context),
                icon: const Icon(Icons.restaurant_rounded),
                label: const Text('J’ai cuisiné'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _RecipeNotesCard extends StatefulWidget {
  const _RecipeNotesCard({
    required this.recipeName,
    required this.recipeNotesStore,
  });

  final String recipeName;
  final RecipeNotesStore recipeNotesStore;

  @override
  State<_RecipeNotesCard> createState() => _RecipeNotesCardState();
}

class _RecipeNotesCardState extends State<_RecipeNotesCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.recipeNotesStore.noteFor(widget.recipeName),
    );
    _controller.addListener(_onNoteChanged);
  }

  @override
  void didUpdateWidget(covariant _RecipeNotesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipeName != widget.recipeName) {
      final nextNote = widget.recipeNotesStore.noteFor(widget.recipeName);
      if (_controller.text != nextNote) {
        _controller.text = nextNote;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onNoteChanged)
      ..dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    widget.recipeNotesStore.updateNote(widget.recipeName, _controller.text);
  }

  void _clearNote() {
    _controller.clear();
    widget.recipeNotesStore.deleteNote(widget.recipeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mes notes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  if (value.text.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return IconButton(
                    tooltip: 'Effacer la note',
                    onPressed: _clearNote,
                    icon: const Icon(Icons.close_rounded),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Ex : mettre moins de crème, ajouter du poivre...',
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeStepTile extends StatelessWidget {
  const _RecipeStepTile({
    required this.stepNumber,
    required this.text,
  });

  final int stepNumber;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNumber',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecipesView extends StatelessWidget {
  const _EmptyRecipesView({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_outlined,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Pas encore d’idées',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoute des aliments pour générer des idées de recettes',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMatchingRecipesView extends StatelessWidget {
  const _NoMatchingRecipesView({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune recette trouvée',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoute d’autres aliments ou scanne un ticket pour obtenir de nouvelles idées.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
