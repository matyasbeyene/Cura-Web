-- Cura Web business dashboard alignment.
--
-- The web dashboard assumes one business per authenticated owner UID. Apply
-- this to the shared Cura Supabase project so the database shape matches the
-- frontend contract.

create unique index if not exists businesses_owner_id_unique
  on public.businesses (owner_id)
  where owner_id is not null;

do $$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'business_dashboard_summary'
      and pg_get_function_identity_arguments(p.oid) =
        'p_business_id uuid, p_start_date date, p_end_date date'
  ) then
    raise exception
      'Missing public.business_dashboard_summary(p_business_id uuid, p_start_date date, p_end_date date)';
  end if;
end $$;
