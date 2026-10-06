-- PROPOSAL ONLY. Not applied. Review before running via Supabase migration.
-- Goal: close tenant isolation gaps found in READ-ONLY audit.
-- No data deletion. No existing policy dropped without replacement.
-- No service-role key involved. App keeps using anon/publishable key.
--
-- Gap 1: rooms has owner-only SELECT, so tenant join via
-- tenants -> rooms is filtered by RLS even for own room.
-- Add tenant-scoped SELECT on rooms through active tenants.profile_id link.
--
-- Gap 2: profiles_update_own allows (id = auth.uid()) with_check same,
-- so tenant could UPDATE own role to owner (privilege escalation).
-- Replace with column-safe update: allow full_name/email only, never role.
-- Requires trigger to block role change even if policy bypassed later.

-- 1) Tenant can SELECT only own active room.
drop policy if exists rooms_select_own_tenant on public.rooms;

create policy rooms_select_own_tenant
on public.rooms
for select
to authenticated
using (
  exists (
    select 1
    from public.tenants t
    where t.room_id = rooms.id
      and t.status = 'active'
      and private.is_own_tenant(t.profile_id)
  )
);

-- 2) Block role escalation: tenant cannot turn own profile into owner.
-- 2a) Replace permissive update policy with non-role columns only.
-- NOTE: Supabase Postgres supports column-level policies only via
-- separate handling; safest portable approach: keep row policy but add
-- trigger below as hard guard. Policy stays row-scoped.
drop policy if exists profiles_update_own on public.profiles;

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- 2b) Hard guard trigger: reject UPDATE that changes role.
create or replace function public.prevent_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.role is distinct from old.role then
    raise exception 'Role change is not allowed';
  end if;
  if new.id is distinct from old.id then
    raise exception 'Profile id change is not allowed';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_role_escalation on public.profiles;

create trigger prevent_role_escalation
  before update on public.profiles
  for each row execute function public.prevent_role_escalation();

-- 3) Tenant payments stay read-only by design:
-- payments has SELECT own + SELECT own_tenant, but INSERT/UPDATE/DELETE
-- only *_own (owner). No tenant payment mutation policy exists.
-- No change needed. This file intentionally adds none.

-- 4) Maintenance tenant policies already scoped to own tenant id.
-- No change needed. Storage photo policies already require
-- property/tenant/report 3-folder path + is_own_tenant.
-- No change needed.
select 1;
