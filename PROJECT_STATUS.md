# My Fridge - État du projet

## Fonctionnalités actuelles

- Gestion du frigo : ajout, modification, consommation, suppression et suivi des dates d'expiration.
- Liste de courses avec quantités, unités, fusion des besoins compatibles et statut coché.
- Scan de tickets ou produits, avec analyse Gemini via une fonction Netlify et mode de démonstration de secours.
- Historique des scans, limité localement aux 30 derniers éléments.
- Suggestions de recettes selon le contenu du frigo.
- Recettes favorites et notes personnelles.
- Conversions simples entre `g`/`kg`, `ml`/`cl`/`l`, `unité`/`unités` et `tranche`/`tranches`.
- Profil utilisateur, préférences de cuisine et aperçu des rappels de péremption.
- Connexion Google, synchronisation Supabase, restauration globale et sauvegardes cloud.
- Informations de transparence sur le scan IA et les données dans Scan et Profil.

## Architecture technique

- Application Flutter avec Material 3.
- État local basé sur des `ChangeNotifier`.
- Persistance hors connexion avec `SharedPreferences`.
- Supabase pour l'authentification, les données cloud, RLS et les RPC PostgreSQL.
- Netlify/Gemini pour l'analyse distante des tickets.
- `main.dart` charge les stores, construit la navigation et orchestre les synchronisations automatiques.
- Déploiement web de production assuré par Netlify.
- Builds Web et Android debug validés.

## Stores locaux

- `FridgeStore` : aliments du frigo.
- `ShoppingListStore` : liste de courses.
- `ScanHistoryStore` : historique des scans.
- `FavoriteRecipesStore` : recettes favorites.
- `RecipeNotesStore` : notes associées aux recettes.
- `ProfileStore` : nom, préférences utilisateur, activation locale des rappels et dernière ouverture de l'application.

Les stores restent utilisables sans Supabase et sauvegardent leurs données dans `SharedPreferences`.

## Services cloud

- `SupabaseService` : initialisation conditionnelle avec `SUPABASE_URL` et `SUPABASE_ANON_KEY`.
- `AuthService` : connexion Google, déconnexion et état d'onboarding cloud.
- `CloudFoodsService`
- `CloudShoppingListService`
- `CloudScanHistoryService`
- `CloudFavoriteRecipesService`
- `CloudRecipeNotesService`
- `CloudBackupService` : création, liste, restauration et rétention des sauvegardes.

## Tables Supabase

- `users`
- `foods`
- `shopping_items`
- `scan_history`
- `favorite_recipes`
- `recipe_notes`
- `cloud_backups`

Les tables utilisent RLS afin qu'un utilisateur ne puisse accéder qu'à ses propres lignes.

## RPC Supabase

- `replace_user_foods`
- `replace_user_shopping_items`
- `replace_user_scan_history`
- `replace_user_favorite_recipes`
- `replace_user_recipe_notes`
- `create_cloud_backup`
- `restore_cloud_backup`
- `prune_cloud_backups`

Les RPC de remplacement installées effectuent suppression et réinsertion dans une transaction PostgreSQL, utilisent `auth.uid()` et acceptent les listes vides. Leur définition est versionnée dans `supabase/migrations`.

## Security status

- Gitleaks a analysé 62 commits sans détecter de secret.
- Les secrets de production sont gérés avec les variables d'environnement Netlify.
- Aucune clé Gemini n'est intégrée dans l'application Flutter ; `GEMINI_API_KEY` est utilisée uniquement par la fonction Netlify.
- Aucune clé Supabase `service_role` n'est présente dans le projet.
- La clé Supabase anon/publishable est utilisée uniquement comme clé publique côté client.
- RLS est activée sur les tables Supabase afin d'isoler les données par utilisateur.
- La fonction Netlify de scan refuse les méthodes non autorisées, valide le body et l'image, limite leur taille, applique un délai maximal et masque les détails techniques Gemini.

## Authentification Google

Supabase Auth lance le flux OAuth Google. `AuthService` expose l'utilisateur courant et synchronise son profil minimal dans `users`. Lors d'une nouvelle connexion, l'auto-sync est suspendue jusqu'au choix dans l'onboarding :

- récupérer les données cloud ;
- garder les données locales ;
- décider plus tard.

La déconnexion réinitialise cet état pour permettre un nouvel onboarding à la prochaine connexion.

## Synchronisation automatique

Les changements locaux des cinq domaines synchronisés déclenchent un upload complet après un debounce de 1,2 seconde. La sync fonctionne seulement si Supabase est initialisé et si un utilisateur est connecté.

Les erreurs sont capturées sans bloquer l'interface. Les auto-syncs sont suspendues pendant l'onboarding et les restaurations afin d'éviter un écrasement concurrent.

## Sauvegardes et restauration

`cloud_backups` contient un payload JSONB complet regroupant les cinq domaines cloud. Chaque utilisateur conserve au maximum trois sauvegardes.

Le Profil permet :

- de créer une sauvegarde manuelle ;
- de consulter et actualiser les trois dernières sauvegardes ;
- de restaurer une sauvegarde après confirmation ;
- de restaurer toutes les données cloud vers les stores locaux.

Une sauvegarde de sécurité est créée avant chaque restauration. La logique SQL protège temporairement le backup ciblé afin qu'il ne soit pas supprimé par la rétention.

## État de validation V1

- Web fonctionnel.
- Android debug fonctionnel sur téléphone réel.
- `flutter analyze` : 0 diagnostic.
- `flutter test` : 9 tests réussis.
- `flutter build web` : réussi.
- `flutter build apk --debug` : réussi avec les variables fournies par `--dart-define`.

Les tests ciblent notamment le démarrage de l'application, les conversions de mesures et les calculs de quantités pour les recettes et les courses.

## Transparence et confidentialité

- Scan explique avant sélection que l'image du ticket est envoyée à un service d'analyse IA.
- Aucun produit détecté n'est ajouté au frigo sans validation manuelle.
- Profil précise que les données restent locales hors connexion et sont synchronisées au cloud seulement avec un compte connecté.
- Les rappels de péremption sont en Phase 1 : préférence locale et aperçu des aliments urgents, sans notification système réelle.

## Limites actuelles

- Synchronisation de type « dernier appareil gagnant », sans fusion ni gestion de conflits.
- Uploads complets plutôt que différentiels.
- Pas de relance automatique après une erreur réseau sans nouvelle modification locale.
- Une réponse réseau perdue après un commit peut signaler un échec alors que la transaction a réussi.
- L'analyse Gemini dépend de la disponibilité de Netlify et du réseau.
- Les conversions couvrent seulement les familles simples listées plus haut ; elles ne gèrent pas les densités, contenants ou lots séparés par date.
- Les rappels n'envoient encore aucune notification réelle.
- Le nom, l'icône et la charte graphique restent provisoires.
- Les plugins Android devront à terme suivre la migration Flutter vers le mode Kotlin intégré.

## Prochains chantiers possibles

1. Organiser le test interne V1 sur plusieurs appareils et scénarios hors connexion.
2. Améliorer encore la correction manuelle et la fiabilité des résultats du scan.
3. Enrichir les recettes et les suggestions anti-gaspillage.
4. Évaluer une Phase 2 optionnelle de rappels locaux Android, avec une fréquence limitée.
5. Finaliser le nom, l'icône, le splash et la charte graphique avant une bêta plus large.
