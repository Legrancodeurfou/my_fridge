# My Fridge - Setup Supabase MVP

Ce patch prépare Supabase sans remplacer le stockage local actuel.

## 1. Créer le projet Supabase

Dans Supabase, crée un nouveau projet.

Récupère ensuite :

```text
Project URL
anon public key
```

Ne copie jamais la `service_role key` dans Flutter.

## 2. Créer les tables

Dans Supabase :

```text
SQL Editor → New query
```

Colle le contenu de :

```text
supabase/schema.sql
```

Puis clique `Run`.

## 3. Ajouter le package Flutter

Dans ton projet local :

```bash
flutter pub add supabase_flutter
```

## 4. Ajouter les fichiers Dart

Ajoute :

```text
lib/services/supabase_service.dart
lib/services/cloud_foods_service.dart
```

## 5. Plus tard : initialiser Supabase dans main.dart

On ne le branche pas encore automatiquement pour éviter de casser l'app locale.

Quand on sera prêt, on ajoutera dans `main()` :

```dart
WidgetsFlutterBinding.ensureInitialized();
await SupabaseService.initialize();
runApp(const MyApp());
```

Et on lancera l'app avec :

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://TON-PROJET.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TON_ANON_KEY
```

## 6. Ce qui est prêt

Tables :

```text
users
foods
shopping_items
scan_history
favorite_recipes
recipe_notes
```

Sécurité :

```text
RLS activé sur toutes les tables
Chaque user ne peut lire/modifier que ses propres données
```

## 7. Prochaine étape

Après ce setup :

```text
Auth Google Supabase → créer user cloud → synchroniser FridgeStore avec foods
```
