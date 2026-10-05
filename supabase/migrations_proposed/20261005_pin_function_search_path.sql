-- PROPOSAL ONLY. Not applied.
-- Goal: pin search_path on existing business functions flagged by advisor.
-- No logic change. Bodies preserved verbatim from live DB definitions.
-- SECURITY DEFINER kept where already set (private helpers untouched).
-- Risk: near zero; only default search_path changes per function.

-- compute_payment_status: pure calculation, safe to pin.
create or replace function public.compute_payment_status(
  p_amount_due numeric, p_amount_paid numeric, p_due_date date,
  p_as_of date default current_date
)
returns text
language plpgsql
immutable
set search_path = public, pg_temp
as $$
begin
  if p_amount_paid >= p_amount_due then
    return 'paid';
  elsif p_as_of > p_due_date then
    return 'overdue';
  elsif p_amount_paid > 0 then
    return 'partial';
  else
    return 'unpaid';
  end if;
end;
$$;

-- payments_set_status: trigger wrapper, pin path.
create or replace function public.payments_set_status()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.status := public.compute_payment_status(
    new.amount_due, new.amount_paid, new.due_date, current_date
  );
  return new;
end;
$$;

-- prevent_delete_occupied_room: guard trigger, pin path.
create or replace function public.prevent_delete_occupied_room()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.tenants t
    where t.room_id = old.id and t.status = 'active'
  ) then
    raise exception 'Cannot delete a room with an active tenant';
  end if;
  return old;
end;
$$;

-- set_updated_at: generic timestamp trigger, pin path.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- sync_room_occupancy_from_tenant: occupancy sync, pin path only.
-- Full body must be copied from live definition at apply time.
-- Listed here as reminder; do NOT apply this file without pasting
-- the verified live body plus `set search_path = public, pg_temp`.

-- validate_payment_relations: relation guard, pin path only.
-- Same note as above: copy live body verbatim at apply time.
