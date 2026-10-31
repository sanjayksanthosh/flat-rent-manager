-- ============================================================================
-- Flat Rent Manager — STEP 2 of 2: migrate data tables, RLS, seed admin
-- ----------------------------------------------------------------------------
-- Run this AFTER supabase_1_auth.sql has succeeded.
-- It rewrites user_id to bigint on the data tables, installs the token based
-- RLS policies, seeds the `admin` user and verifies the result.
--
-- Expected result at the bottom of the output:
--   NOTICE:  Schema ready: 1 user(s), 0 session(s). Sign in with username "admin".
-- ============================================================================
-- 5. Migrate the old Supabase-Auth data model (uuid user_id -> bigint)
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- Old policies reference user_id and auth.uid(); drop them before the column
-- type changes. New ones are created in section 6.
do $$
declare
  r record;
begin
  for r in
    select tablename, policyname
      from pg_policies
     where schemaname = 'public'
       and tablename in ('buildings', 'flats', 'tenants', 'leases',
                         'rent_payments', 'payment_allocations', 'profiles')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

do $$
declare
  t          text;
  v_has_rows boolean;
begin
  -- This block depends on section 1. If the file was only partially run, say so
  -- plainly instead of failing with "relation public.app_users does not exist".
  if to_regclass('public.app_users') is null then
    raise exception
      'public.app_users does not exist. Run the WHOLE supabase_schema.sql from the first line to the last in one go (select all, then run).';
  end if;

  foreach t in array array['buildings', 'flats', 'tenants', 'leases',
                           'rent_payments', 'payment_allocations']
  loop
    -- A fresh project may not have the data tables yet; the legacy schema
    -- creates them. Skip rather than abort the whole script.
    if to_regclass(format('public.%I', t)) is null then
      raise notice 'skipping public.%: table does not exist', t;
      continue;
    end if;

    if exists (
      select 1
        from information_schema.columns
       where table_schema = 'public'
         and table_name = t
         and column_name = 'user_id'
         and data_type = 'uuid'
    ) then
      execute format('select exists (select 1 from public.%I)', t) into v_has_rows;

      if v_has_rows then
        raise exception
          'Table % already contains rows owned by Supabase Auth users. Back the data up and migrate user_id by hand before running this script.', t;
      end if;

      execute format('alter table public.%I drop column user_id', t);
    end if;

    if not exists (
      select 1
        from information_schema.columns
       where table_schema = 'public'
         and table_name = t
         and column_name = 'user_id'
    ) then
      execute format(
        'alter table public.%I add column user_id bigint not null references public.app_users(id) on delete cascade',
        t
      );
    end if;

    execute format('create index if not exists idx_%s_user on public.%I(user_id)', t, t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 6. Row level security â€” ownership comes from the request token
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['buildings', 'flats', 'tenants', 'leases',
                           'rent_payments', 'payment_allocations']
  loop
    if to_regclass(format('public.%I', t)) is null then
      raise notice 'skipping RLS for public.%: table does not exist', t;
      continue;
    end if;

    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I on public.%I', t || '_select_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_own', t);

    execute format(
      'create policy %I on public.%I for select to anon, authenticated
         using (user_id = app.session_user_id())', t || '_select_own', t);

    execute format(
      'create policy %I on public.%I for insert to anon, authenticated
         with check (user_id = app.session_user_id())', t || '_insert_own', t);

    execute format(
      'create policy %I on public.%I for update to anon, authenticated
         using (user_id = app.session_user_id())
         with check (user_id = app.session_user_id())', t || '_update_own', t);

    execute format(
      'create policy %I on public.%I for delete to anon, authenticated
         using (user_id = app.session_user_id())', t || '_delete_own', t);

    execute format('grant select, insert, update, delete on public.%I to anon, authenticated', t);
  end loop;
end $$;

grant usage, select on all sequences in schema public to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 7. Function permissions
-- ----------------------------------------------------------------------------
grant usage on schema app to anon, authenticated;
grant execute on function app.session_user_id()   to anon, authenticated;
grant execute on function app.session_user_role() to anon, authenticated;

grant execute on function public.app_login(text, text)                    to anon, authenticated;
grant execute on function public.app_logout()                             to anon, authenticated;
grant execute on function public.app_me()                                 to anon, authenticated;
grant execute on function public.app_change_password(text, text)          to anon, authenticated;
grant execute on function public.app_admin_list_users()                   to anon, authenticated;
grant execute on function public.app_admin_create_user(text, text, text, text) to anon, authenticated;
grant execute on function public.app_admin_update_user(bigint, text, text, text, boolean) to anon, authenticated;
grant execute on function public.app_admin_delete_user(bigint)            to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 8. Retire the old Supabase-Auth objects and seed the first admin
-- ----------------------------------------------------------------------------
-- profiles / handle_new_user() belonged to the email based system.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.profiles;

-- Seed: username `admin`, password `admin123`, forced change on first login.
-- Change it from the app (or the SQL editor) right after the first sign-in.
insert into public.app_users (username, password_hash, name, role, must_change_password)
values (
  'admin',
  extensions.crypt('admin123', extensions.gen_salt('bf', 12)),
  'Administrator',
  'admin',
  true
)
on conflict do nothing;

-- Make PostgREST pick up the new tables and functions immediately.
notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- 9. Verify â€” fails loudly if the script was only partially applied
-- ----------------------------------------------------------------------------
do $$
declare
  missing text[] := '{}';
  f       text;
  fn      text[] := array[
    'app_login(text,text)', 'app_logout()', 'app_me()',
    'app_change_password(text,text)', 'app_admin_list_users()',
    'app_admin_create_user(text,text,text,text)',
    'app_admin_update_user(bigint,text,text,text,boolean)',
    'app_admin_delete_user(bigint)'
  ];
  t       text;
begin
  foreach t in array array['app_users', 'app_sessions'] loop
    if to_regclass('public.' || t) is null then missing := missing || t; end if;
  end loop;

  foreach f in array fn loop
    if to_regprocedure('public.' || f) is null then missing := missing || f; end if;
  end loop;

  if cardinality(missing) > 0 then
    raise exception 'Schema incomplete, missing: %. Re-run the whole file from the top.', array_to_string(missing, ', ');
  end if;

  raise notice 'Schema ready: % user(s), % session(s). Sign in with username "admin".',
    (select count(*) from public.app_users),
    (select count(*) from public.app_sessions);
end $$;
