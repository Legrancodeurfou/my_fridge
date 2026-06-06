# My Fridge - Instructions for Codex

You are working on a Flutter web/mobile MVP called My Fridge.

## Project context

The app helps users manage their fridge, scan receipts, track expiration dates, suggest recipes, manage shopping lists, and sync data with Supabase.

Current stack:
- Flutter
- SharedPreferences for local persistence
- Supabase for Auth and cloud tables
- Google Auth via Supabase
- Netlify for Flutter Web deployment and serverless functions
- Gemini API via Netlify function for receipt analysis

Main tabs:
- Home
- Fridge
- Scan
- Recipes
- Shopping list
- Profile

Important existing behavior:
- Local storage must keep working even when Supabase is unavailable.
- Never remove existing local SharedPreferences behavior unless explicitly asked.
- Cloud sync should be additive and safe.
- Prefer manual sync first, then auto-sync after validation.
- Avoid destructive migrations unless explicitly requested.

## Coding rules

- Make minimal, high-confidence changes.
- Do not rewrite unrelated screens.
- Do not change UI design unless the task asks for it.
- Preserve French UI labels.
- Keep the app beginner-friendly and MVP-oriented.
- When adding Supabase sync, keep local-first behavior.
- Never hardcode secrets.
- Never expose API keys in Flutter client code.
- Use Netlify functions or Supabase Edge Functions for secret server-side calls.

## Supabase

Existing tables:
- users
- foods
- shopping_items
- scan_history
- favorite_recipes
- recipe_notes

Auth:
- Google Auth works through Supabase.
- The app receives the connected user's email in Profile.
- Fridge cloud sync already exists.

Important:
- Supabase URL must be the project root URL only, not /rest/v1.
- Netlify injects SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define.
- Do not use service_role key in Flutter.

## Testing expectations

After code changes, run:
- flutter analyze

When relevant, also run:
- flutter build web

If an error appears, fix it before finishing.

## Output format

At the end of each task, summarize:
- files changed
- what was implemented
- how to test manually
- any risks or follow-up steps