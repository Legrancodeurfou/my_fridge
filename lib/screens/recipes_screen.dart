import 'package:flutter/material.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipes = [
      {
        'emoji': '🍝',
        'name': 'Pâtes tomate fromage',
        'time': '15 min',
        'ingredients': 'Pâtes, tomates, emmental',
      },
      {
        'emoji': '🍳',
        'name': 'Omelette fromage',
        'time': '10 min',
        'ingredients': 'Œufs, emmental',
      },
      {
        'emoji': '🥗',
        'name': 'Salade express',
        'time': '8 min',
        'ingredients': 'Tomates, œufs, fromage',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recettes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Idées avec ton frigo',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          ...recipes.map((recipe) {
            return Card(
              child: ListTile(
                leading: Text(
                  recipe['emoji']!,
                  style: const TextStyle(fontSize: 32),
                ),
                title: Text(recipe['name']!),
                subtitle: Text('${recipe['time']} • ${recipe['ingredients']}'),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          }),
        ],
      ),
    );
  }
}