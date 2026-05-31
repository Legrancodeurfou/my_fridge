import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),

          const SizedBox(height: 16),

          const Center(
            child: Text(
              'Esteban',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('Niveau de cuisine'),
              subtitle: const Text('Intermédiaire'),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Objectif'),
              subtitle: const Text('Limiter le gaspillage'),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.family_restroom),
              title: const Text('Famille'),
              subtitle: const Text('1 membre connecté'),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
            ),
          ),
        ],
      ),
    );
  }
}