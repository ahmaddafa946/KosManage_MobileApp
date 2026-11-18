create or replace function public.guard_maintenance_transition()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_is_owner boolean;
begin
  if new.status is distinct from old.status
     or new.resolved_at is distinct from old.resolved_at then
    -- Read the public property row under the caller's RLS policy instead of
    -- calling a helper in the non-exposed private schema. The owner policy
    -- limits this lookup to properties owned by auth.uid().
    select exists (
      select 1
        from public.properties p
       where p.id = old.property_id
         and p.owner_id = auth.uid()
    )
      into v_is_owner;

    if not coalesce(v_is_owner, false) then
      raise exception 'Only property owner can change report status';
    end if;
  end if;

  if new.status = old.status then
    -- Category/description edits do not alter the resolution timestamp.
    new.resolved_at := old.resolved_at;
    return new;
  end if;

  if old.status = 'submitted' and new.status = 'in_progress' then
    new.resolved_at := null;
  elsif old.status = 'in_progress' and new.status = 'resolved' then
    new.resolved_at := now();
  elsif old.status = 'resolved' and new.status = 'closed' then
    new.resolved_at := old.resolved_at;
  else
    raise exception 'Invalid maintenance status transition: % -> %',
      old.status, new.status;
  end if;

  return new;
end;
$function$;

-- Postgres Changes only emits rows for tables in this publication.
-- Publish the owner-facing tables used by the mobile INSERT-only refresher.
alter publication supabase_realtime
  add table
    public.properties,
    public.rooms,
    public.tenants,
    public.payments,
    public.maintenance_reports;
