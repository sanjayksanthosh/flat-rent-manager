# Flat Rent Manager

Flutter app for managing buildings, flats, tenants, leases and rent collection,
backed by Supabase (Postgres + PostgREST).

## Authentication

The app does **not** use Supabase Auth and does not use email addresses.
Users sign in with a **username and password** that are verified inside the
database.

How it fits together:

| Piece | What it does |
| --- | --- |
| `public.app_users` | Username, bcrypt hash, role (`admin`/`user`), active flag, lockout counters |
| `public.app_sessions` | One row per sign-in. Stores only the SHA-256 of the token |
| `public.app_login(username, password)` | Verifies the hash, opens a session, returns the raw token |
| `x-app-token` header | The app sends the token on every request |
| `app.session_user_id()` | Turns the header back into a user id for RLS |
| RLS policies | `user_id = app.session_user_id()` on every data table |

Other behaviour:

- Usernames are case-insensitive (`Admin` == `admin`).
- Passwords: anything the admin types — no length or complexity rules. Only a
  completely blank password is refused.
- 5 failed attempts lock the account for 15 minutes.
- Sessions last 7 days and slide forward while in use.
- Changing a password signs every other device out.
- `app_users` and `app_sessions` are not readable through the REST API at all.

### First run

Run the two SQL files in order in the Supabase **SQL editor**. Both are
idempotent, so re-running them is harmless.

1. **`supabase_1_auth.sql`** — creates `app_users`, `app_sessions`, the `app.*`
   helpers and the `app_*` RPCs. Does not touch your existing data tables.
   Expected output: `Success. No rows returned`.
2. **`supabase_2_migrate.sql`** — rewrites `user_id` to `bigint` on the data
   tables, installs the token-based RLS policies, seeds the admin user and
   verifies everything exists.
   Expected output: `NOTICE: Schema ready: 1 user(s), 0 session(s). Sign in with username "admin".`
3. Sign in with **`admin` / `admin123`**. The app immediately asks you to change it.
4. Create further users from **Users → Add User** (admin only).

`supabase_schema.sql` is both steps combined into one file, for a fresh
database. `supabase_schema.legacy.sql` is the old email/Supabase-Auth schema,
kept only for reference.

The connection details live in `lib/supabase_config.dart`.

## Development

```bash
flutter pub get
flutter run
flutter analyze
```
