import 'package:flutter/material.dart';

import '../data/fridge_store.dart';
import '../models/food.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key, required this.store});

  final FridgeStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _RecipesContent(store: store),
    );
  }
}

class _RecipesContent extends StatelessWidget {
  const _RecipesContent({required this.store});

  final FridgeStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foods = store.foods;
    final recipes = RecipeCatalog.suggestFor(foods);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Recettes'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
      ),
      body: foods.isEmpty
          ? const _EmptyRecipesView()
          : recipes.isEmpty
              ? const _NoMatchingRecipesView()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
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
                    const SizedBox(height: 20),
                    ...recipes.map(
                      (recipe) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecipeCard(
                          recipe: recipe,
                          store: store,
                        ),
                      ),
                    ),
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
  });

  final String label;
  final List<String> keywords;
}

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.emoji,
    required this.name,
    required this.time,
    required this.description,
    required this.requiredIngredients,
    required this.steps,
  });

  final String emoji;
  final String name;
  final String time;
  final String description;
  final List<RecipeIngredient> requiredIngredients;
  final List<String> steps;

  List<String> get ingredients =>
      requiredIngredients.map((item) => item.label).toList();
}

class RecipeIngredientMatch {
  const RecipeIngredientMatch({
    required this.ingredient,
    required this.isAvailable,
    this.matchedFoodName,
    this.matchedFoodId,
    this.matchedFoodQuantity,
    this.matchedFoodAmountLabel,
  });

  final RecipeIngredient ingredient;
  final bool isAvailable;
  final String? matchedFoodName;
  final String? matchedFoodId;
  final int? matchedFoodQuantity;
  final String? matchedFoodAmountLabel;

  /// Libellé affiché pour un ingrédient présent dans le frigo (ex. « Pâtes 500 g »).
  String get fridgeDisplayLabel {
    if (matchedFoodName == null) return ingredient.label;
    return matchedFoodAmountLabel == null
        ? matchedFoodName!
        : '$matchedFoodName $matchedFoodAmountLabel';
  }

  String get chipLabel =>
      isAvailable && matchedFoodId != null ? fridgeDisplayLabel : ingredient.label;
}

abstract final class RecipeCatalog {
  static List<RecipeSuggestion> suggestFor(List<FoodItem> foods) {
    if (foods.isEmpty) return [];

    final names = foods.map((food) => food.name.toLowerCase()).toList();
    final recipes = <RecipeSuggestion>[];

    void addIf(bool condition, RecipeSuggestion recipe) {
      if (condition &&
          recipes.length < 3 &&
          !recipes.any((item) => item.name == recipe.name)) {
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
          ),
          RecipeIngredient(
            label: 'Crème fraîche',
            keywords: ['crème', 'creme'],
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
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
          RecipeIngredient(label: 'Jambon', keywords: ['jambon']),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
          ),
          RecipeIngredient(label: 'Pain', keywords: ['pain']),
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
          RecipeIngredient(label: 'Salade', keywords: ['salade']),
          RecipeIngredient(label: 'Tomates', keywords: ['tomate']),
          RecipeIngredient(label: 'Œufs', keywords: ['œuf', 'oeuf']),
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
          RecipeIngredient(label: 'Œufs', keywords: ['œuf', 'oeuf']),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
          ),
          RecipeIngredient(
            label: 'Crème fraîche',
            keywords: ['crème', 'creme'],
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
          ),
          RecipeIngredient(label: 'Tomates', keywords: ['tomate']),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
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
        description: 'Un gratin réconfortant avec tes produits laitiers.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Pommes de terre',
            keywords: ['pomme de terre', 'pommes de terre'],
          ),
          RecipeIngredient(
            label: 'Crème fraîche',
            keywords: ['crème', 'creme'],
          ),
          RecipeIngredient(
            label: 'Emmental',
            keywords: ['emmental', 'fromage'],
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
        description: 'Idéal pour consommer ta viande en priorité.',
        requiredIngredients: [
          RecipeIngredient(
            label: 'Steak haché',
            keywords: ['steak', 'haché', 'hache', 'viande'],
          ),
          RecipeIngredient(label: 'Tomates', keywords: ['tomate']),
          RecipeIngredient(
            label: 'Pâtes',
            keywords: ['pâte', 'pate', 'pâtes', 'pates'],
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

    return recipes.take(3).toList();
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
          return RecipeIngredientMatch(
            ingredient: ingredient,
            isAvailable: true,
            matchedFoodName: food.name,
            matchedFoodId: food.id,
            matchedFoodQuantity: food.quantity,
            matchedFoodAmountLabel: food.amountLabel,
          );
        }
      }

      final hasMatch = ingredient.keywords.any(
        (keyword) => foodNames.any((name) => name.contains(keyword)),
      );

      return RecipeIngredientMatch(
        ingredient: ingredient,
        isAvailable: hasMatch,
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

  static bool _hasAny(List<String> foodNames, List<String> keywords) {
    return keywords.any(
      (keyword) => foodNames.any((name) => name.contains(keyword)),
    );
  }
}

// ---------------------------------------------------------------------------
// Composants UI
// ---------------------------------------------------------------------------

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.store,
  });

  final RecipeSuggestion recipe;
  final FridgeStore store;

  void _showRecipeDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _RecipeDetailSheet(
          recipe: recipe,
          store: store,
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
  });

  final RecipeSuggestion recipe;
  final FridgeStore store;

  Future<void> _onCooked(BuildContext sheetContext) async {
    final foods = store.foods;
    final availableMatches = RecipeCatalog.matchIngredients(recipe, foods)
        .where((match) => match.isAvailable)
        .toList();
    final foodIdsToRemove = RecipeCatalog.matchedFoodIds(recipe, foods);

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
              onPressed: foodIdsToRemove.isEmpty
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
      store.consumeFoodsByIds(foodIdsToRemove);
    }

    if (sheetContext.mounted) Navigator.pop(sheetContext);

    if (!sheetContext.mounted) return;

    final message = choice == _CookedChoice.remove
        ? foodIdsToRemove.length == 1
            ? 'Bon appétit ! 1 unité retirée du frigo.'
            : 'Bon appétit ! ${foodIdsToRemove.length} unités retirées du frigo.'
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
                                label: match.ingredient.label,
                                isAvailable: false,
                              ),
                            )
                            .toList(),
                      ),
                    ],
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
  const _EmptyRecipesView();

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
  const _NoMatchingRecipesView();

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
