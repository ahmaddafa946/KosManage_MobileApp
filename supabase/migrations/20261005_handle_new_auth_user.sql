-- PROPOSAL ONLY. Not applied. Review before running via Supabase migration.
-- Goal: auto-create public.profiles on auth.users insert.
-- Keeps role default 'owner' for existing business logic.
-- No data deletion. Existing profiles untouched (ON CONFLICT DO NOTHING).
-- No recursion: trigger lives on auth.users, writes public.profiles only.
-- SECURITY DEFINER with fixed search_path so it cannot be hijacked.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, role, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email, 'Pengguna'),
    'owner',
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
