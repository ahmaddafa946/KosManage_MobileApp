-- PROPOSAL ONLY. Not applied.
-- Goal: link tenant login accounts without using email as identity.
-- Flow: owner creates auth user for tenant, then sets tenants.profile_id
-- to that user's id (auth.users.id = profiles.id = tenants.profile_id).
-- App already reads in that order: auth.currentUser.id -> profiles.id
-- -> tenants.profile_id (with email only as legacy fallback).
-- No schema change needed. No data deletion.
-- Before running: replace placeholders with real ids, keep one active
-- tenant per room (enforced by existing trigger).

-- Example (replace UUIDs):
-- update public.tenants
-- set profile_id = '<auth_user_id_of_tenant>'
-- where id = '<tenant_row_id>'
--   and status = 'active';
select 1;
