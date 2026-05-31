import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Bonjour Esteban 👋',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Voici le résumé de ton frigo aujourd’hui.',
            style: TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 24),

          Card(
            child: ListTile(
              leading: const Icon(Icons.kitchen, size: 32),
              title: const Text('5 aliments dans le frigo'),
              subtitle: const Text('Ton inventaire est à jour'),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.warning, size: 32),
              title: const Text('2 produits expirent bientôt'),
              subtitle: const Text('À consommer en priorité'),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant_menu, size: 32),
              title: const Text('3 recettes disponibles'),
              subtitle: const Text('Basées sur ce que tu as déjà'),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.kitchen),
            label: const Text('Voir mon frigo'),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scanner un ticket'),
          ),
        ],
      ),
    );
  }
}