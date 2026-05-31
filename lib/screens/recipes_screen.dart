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
      builder: (context, _) => _RecipesContent(
        foods: store.foods,
      ),
    );
  }
}

class _RecipesContent extends StatelessWidget {
  const _RecipesContent({required this.foods});

  final List<FoodItem> foods;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                    child: _RecipeCard(recipe: recipe),
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

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.emoji,
    required this.name,
    required this.time,
    required this.ingredients,
    required this.description,
  });

  final String emoji;
  final String name;
  final String time;
  final List<String> ingredients;
  final String description;
}

abstract final class RecipeCatalog {
  static List<RecipeSuggestion> suggestFor(List<FoodItem> foods) {
    if (foods.isEmpty) return [];

    final names = foods.map((food) => food.name.toLowerCase()).toList();
    final recipes = <RecipeSuggestion>[];

    void addIf(bool condition, RecipeSuggestion recipe) {
      if (condition && recipes.length < 3 && !recipes.any((r) => r.name == recipe.name)) {
        recipes.add(recipe);
      }
    }

    addIf(
      _hasAny(names, ['pâte', 'pate', 'pâtes', 'pates']),
      const RecipeSuggestion(
        emoji: '🍝',
        name: 'Pâtes à la crème',
        time: '20 min',
        ingredients: ['Pâtes', 'Crème fraîche', 'Emmental'],
        description:
            'Des pâtes onctueuses avec la crème et le fromage déjà dans ton frigo.',
      ),
    );

    addIf(
      _hasAny(names, ['jambon']),
      const RecipeSuggestion(
        emoji: '🥪',
        name: 'Croque jambon express',
        time: '12 min',
        ingredients: ['Jambon', 'Emmental', 'Pain'],
        description:
            'Un classique rapide pour utiliser ton jambon avant la date limite.',
      ),
    );

    addIf(
      _hasAny(names, ['salade']),
      const RecipeSuggestion(
        emoji: '🥗',
        name: 'Salade fraîche du frigo',
        time: '10 min',
        ingredients: ['Salade', 'Tomates', 'Œufs'],
        description:
            'Une salade légère et croquante avec les produits frais disponibles.',
      ),
    );

    addIf(
      _hasAny(names, ['œuf', 'oeuf', 'œufs', 'oeufs']),
      const RecipeSuggestion(
        emoji: '🍳',
        name: 'Omelette fromage',
        time: '10 min',
        ingredients: ['Œufs', 'Emmental', 'Crème fraîche'],
        description: 'Parfaite pour un repas express avec tes produits laitiers.',
      ),
    );

    addIf(
      _hasAny(names, ['tomate', 'tomates']),
      const RecipeSuggestion(
        emoji: '🍅',
        name: 'Pâtes tomate fromage',
        time: '15 min',
        ingredients: ['Pâtes', 'Tomates', 'Emmental'],
        description: 'Un plat simple qui combine tes ingrédients du quotidien.',
      ),
    );

    addIf(
      _hasAny(names, ['lait', 'yaourt']),
      const RecipeSuggestion(
        emoji: '🥣',
        name: 'Gratin crémeux',
        time: '25 min',
        ingredients: ['Pommes de terre', 'Crème fraîche', 'Emmental'],
        description: 'Un gratin réconfortant avec tes produits laitiers.',
      ),
    );

    addIf(
      _hasAny(names, ['steak', 'viande', 'haché', 'hache']),
      const RecipeSuggestion(
        emoji: '🥩',
        name: 'Bolognaise express',
        time: '18 min',
        ingredients: ['Steak haché', 'Tomates', 'Pâtes'],
        description: 'Idéal pour consommer ta viande en priorité.',
      ),
    );

    return recipes.take(3).toList();
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
  const _RecipeCard({required this.recipe});

  final RecipeSuggestion recipe;

  void _showRecipeDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipeDetailSheet(recipe: recipe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                              'Avec ton frigo',
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
                  children: recipe.ingredients
                      .map(
                        (ingredient) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ingredient,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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

class _RecipeDetailSheet extends StatelessWidget {
  const _RecipeDetailSheet({required this.recipe});

  final RecipeSuggestion recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(recipe.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: colorScheme.primary),
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
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Avec ton frigo',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                recipe.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ingrédients',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...recipe.ingredients.map(
                (ingredient) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(ingredient),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
