# Auth Google Supabase - My Fridge

Ce patch ajoute :

- `lib/services/auth_service.dart`
- un bouton **Se connecter avec Google** dans `Profil`
- l'affichage de l'email connecté
- la création/mise à jour de la ligne `users` dans Supabase

## À configurer dans Supabase

Dans Supabase :

1. Va dans **Authentication → Providers → Google**.
2. Active Google.
3. Ajoute le Client ID et Client Secret Google.
4. Vérifie les redirect URLs côté Google Cloud / Supabase.

Pour tester sur Netlify, ajoute ton URL Netlify dans les redirect URLs autorisées :

```text
https://my-fridge111.netlify.app
https://my-fridge111.netlify.app/**
```

Si tu testes en local, ajoute aussi :

```text
http://localhost:*
```

## Important

Le bouton peut être visible dans l'app même si Google Provider n'est pas encore configuré.
Dans ce cas, Supabase renverra une erreur de connexion.
