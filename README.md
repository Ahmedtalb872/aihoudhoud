# alhudhud (Captain app)

This is the captain/driver app for الهدهد. It shares its Supabase backend
(auth + database) with a separate customer-facing app, but this codebase only
implements the captain-side screens and flows — there is no customer login
or booking UI here.

## Supabase setup (authentication + database)

Auth (email + password) and the database schema live in Supabase.

1. Create a project at [supabase.com](https://supabase.com).
2. Run the SQL in `supabase/migrations/0001_init.sql` in the Supabase SQL editor
   (or `supabase db push` if you use the Supabase CLI). It creates the tables,
   the `handle_new_user` trigger that provisions a `profiles` row on sign-up,
   and the Row Level Security policies.
3. Copy `env.json.example` to `env.json` and fill in your project's URL and
   anon/public key (Project Settings -> API). Never commit `env.json` or use
   the `service_role` key inside the app.
4. Run the app with the config file:
   ```bash
   flutter run --dart-define-from-file=env.json
   ```

Without `env.json`, the app still builds and runs, but any screen that hits
Supabase (login, register) will show an Arabic error asking you to configure it.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
