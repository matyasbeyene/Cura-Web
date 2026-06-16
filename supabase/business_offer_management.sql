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

alter table public.offers add column if not exists offer_type text not null default 'study';
alter table public.offers add column if not exists redemption_code text;
alter table public.offers add column if not exists starts_at timestamptz;
alter table public.offers add column if not exists ends_at timestamptz;

alter table public.offers drop constraint if exists offers_type_check;
alter table public.offers add constraint offers_type_check
  check (offer_type in ('study', 'promotion'))
  not valid;

alter table public.offers drop constraint if exists offers_required_minutes_check;
alter table public.offers add constraint offers_required_minutes_check
  check (
    required_minutes is null
    or (
      offer_type = 'study'
      and required_minutes between 1 and 100000
    )
    or (
      offer_type = 'promotion'
      and required_minutes = 0
    )
  )
  not valid;

alter table public.offers drop constraint if exists offers_redemption_code_check;
alter table public.offers add constraint offers_redemption_code_check
  check (
    redemption_code is null
    or length(trim(redemption_code)) between 1 and 80
  )
  not valid;

alter table public.offers drop constraint if exists offers_window_check;
alter table public.offers add constraint offers_window_check
  check (starts_at is null or ends_at is null or starts_at < ends_at)
  not valid;

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

revoke select on public.offers from authenticated;
grant select (
  id,
  business_id,
  title,
  description,
  offer_type,
  required_minutes,
  is_active,
  starts_at,
  ends_at,
  created_at,
  updated_at
) on public.offers to authenticated;
grant insert, update, delete on public.offers to authenticated;
