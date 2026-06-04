# Supabase init patch

Fichiers :
- lib/main.dart
- lib/services/supabase_service.dart
- netlify.toml

À faire :
1. Remplacer les fichiers dans le projet.
2. Vérifier que les variables Netlify existent :
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
3. Push sur GitHub.
4. Netlify redéploie avec les dart-define.

L'app continue de fonctionner en local même si Supabase n'est pas configuré.
