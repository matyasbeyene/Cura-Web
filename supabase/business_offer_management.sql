-- Cura Web business offer management alignment.
--
-- Apply this after the shared rewards schema. It keeps the web dashboard's
-- offer editor aligned with the canonical businesses -> offers model.

do $$
begin
  if to_regclass('public.businesses') is null then
    raise exception 'Missing public.businesses table';
  end if;

  if to_regclass('public.offers') is null then
    raise exception 'Missing public.offers table';
  end if;
end $$;

alter table public.offers enable row level security;

drop policy if exists "Read active offers" on public.offers;
create policy "Read active offers"
  on public.offers for select to authenticated
  using (
    is_active = true
    or exists (
      select 1
        from public.businesses b
       where b.id = offers.business_id
         and b.owner_id = (select auth.uid())
    )
  );

drop policy if exists "Owner writes own offers" on public.offers;

drop policy if exists "Owner inserts own offers" on public.offers;
create policy "Owner inserts own offers"
  on public.offers for insert to authenticated
  with check (
    exists (
      select 1
        from public.businesses b
       where b.id = offers.business_id
         and b.owner_id = (select auth.uid())
    )
  );

drop policy if exists "Owner updates own offers" on public.offers;
create policy "Owner updates own offers"
  on public.offers for update to authenticated
  using (
    exists (
      select 1
        from public.businesses b
       where b.id = offers.business_id
         and b.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
        from public.businesses b
       where b.id = offers.business_id
         and b.owner_id = (select auth.uid())
    )
  );

drop policy if exists "Owner deletes own offers" on public.offers;
create policy "Owner deletes own offers"
  on public.offers for delete to authenticated
  using (
    exists (
      select 1
        from public.businesses b
       where b.id = offers.business_id
         and b.owner_id = (select auth.uid())
    )
  );

grant select, insert, update, delete on public.offers to authenticated;
