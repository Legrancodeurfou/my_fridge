# My Fridge - Guide de test interne V1

## Objectif

Cette version sert à vérifier les parcours essentiels de My Fridge sur Web et
Android avant une bêta plus large. Le nom, l'icône et la charte graphique sont
encore provisoires : les retours doivent surtout porter sur la stabilité, la
compréhension des écrans et la fiabilité des données.

## Prérequis

- Une connexion Internet pour Google, Supabase, les sauvegardes et le scan IA.
- Un compte Google de test.
- Sur Android : autoriser la caméra si elle est utilisée. La galerie reste
  disponible si cette autorisation est refusée.
- Un ticket de caisse lisible, sans information sensible inutile.

L'application reste utilisable localement sans connexion. Les changements cloud
seront synchronisés lorsque le service est disponible et qu'une nouvelle
modification locale déclenche la synchronisation.

## Parcours recommandé

1. Ouvrir l'application et parcourir l'Accueil.
2. Ajouter deux aliments au Frigo avec des quantités et des dates différentes,
   dont un aliment expirant aujourd'hui ou demain.
3. Scanner un ticket depuis la caméra ou la galerie.
4. Corriger les noms, quantités ou unités détectés, supprimer une ligne
   incorrecte, puis valider l'ajout au frigo.
5. Consulter les recettes proposées et vérifier les ingrédients disponibles,
   manquants et bientôt périmés.
6. Ajouter les ingrédients manquants aux Courses, puis utiliser l'action
   « Voir les courses ».
7. Tester « J'ai cuisiné » et confirmer la consommation des ingrédients.
8. Dans Profil, se connecter avec Google et lire attentivement le choix cloud :
   récupérer les données cloud, garder les données locales ou décider plus tard.
9. Créer une sauvegarde cloud, la retrouver dans la liste, puis tester une
   restauration seulement avec des données de test.
10. Activer « Rappels de péremption » et vérifier l'aperçu affiché.

## Fonctionnalités à tester

- Ajout, modification, consommation et suppression d'aliments.
- Dates de péremption et mise en avant des aliments urgents non expirés.
- Caméra, galerie, aperçu du ticket et validation manuelle.
- Historique des scans.
- Recettes, favoris, notes et logique anti-gaspillage.
- Ajout sans doublon évident dans la liste de courses.
- Connexion et déconnexion Google.
- Synchronisation cloud et fonctionnement local hors connexion.
- Création, actualisation et restauration des sauvegardes cloud.
- Persistance des préférences après redémarrage.

## Checklist courte

- [ ] **Auth** : connexion Google, email affiché et déconnexion.
- [ ] **Frigo** : ajout, modification, consommation, suppression et péremption.
- [ ] **Scan** : image lisible, correction des résultats et ajout au frigo.
- [ ] **Recettes** : recommandations, ingrédients manquants et « J'ai cuisiné ».
- [ ] **Courses** : ajout depuis une recette, absence de doublon et cases cochées.
- [ ] **Profil** : prénom et préférences conservés après redémarrage.
- [ ] **Cloud backup** : création et affichage parmi les trois dernières.
- [ ] **Restauration** : confirmation, sauvegarde de sécurité et données restaurées.
- [ ] **Android caméra/galerie** : autorisation acceptée, refusée et galerie utilisable.

## Points à surveiller

- Message peu clair, bouton ambigu, texte coupé ou débordement sur petit écran.
- Écran bloqué, chargement sans fin ou fermeture inattendue.
- Produit détecté avec un nom, une quantité, une unité ou une date incohérente.
- Donnée locale perdue après fermeture ou passage hors connexion.
- Synchronisation lancée alors que le choix cloud est encore « Plus tard ».
- Différence inattendue entre les données Web, Android et Supabase.
- Sauvegarde absente, restauration partielle ou données remplacées sans confirmation.

## Scan et données envoyées à l'IA

Lors d'une analyse, l'image choisie est encodée et envoyée à une fonction
Netlify, qui la transmet au service Gemini. L'objectif est uniquement d'extraire
les produits alimentaires visibles sur le ticket. La clé Gemini reste côté
Netlify et n'est pas incluse dans l'application.

Éviter de scanner un ticket contenant des informations personnelles ou
financières non nécessaires au test. Aucun produit n'est ajouté au frigo avant
la validation manuelle.

## Limites connues

- La synchronisation suit une logique « dernier appareil gagnant » sans fusion
  des modifications concurrentes.
- Après une erreur réseau, une nouvelle modification locale peut être nécessaire
  pour relancer automatiquement la synchronisation.
- Le scan dépend du réseau, de Netlify et de Gemini ; les résultats doivent
  toujours être vérifiés.
- Seules les trois sauvegardes cloud les plus récentes sont conservées.
- Le branding Android et Web est provisoire.
- Les rappels de péremption sont en Phase 1 : l'option et l'aperçu fonctionnent,
  mais **aucune notification système réelle n'est envoyée**.

## En cas de bug

1. Ne pas réinitialiser les données immédiatement.
2. Noter la plateforme, le modèle du téléphone et la version Android ou le
   navigateur utilisé.
3. Décrire les étapes exactes, le résultat attendu et le résultat observé.
4. Ajouter une capture d'écran ou une courte vidéo si possible.
5. Préciser l'état du réseau et si le compte Google était connecté.
6. Pour un problème cloud, indiquer le choix effectué dans l'onboarding et
   l'heure approximative du problème, sans partager de clé ni de secret.

