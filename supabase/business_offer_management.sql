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

alter table public.offers add column if not exists offer_type text not null default 'points';
alter table public.offers alter column offer_type set default 'points';
alter table public.offers add column if not exists required_minutes integer default 0;
alter table public.offers alter column required_minutes set default 0;
alter table public.offers add column if not exists redemption_code text;
alter table public.offers add column if not exists discount_kind text;
alter table public.offers add column if not exists discount_value numeric(8,2);
alter table public.offers add column if not exists points_cost integer generated always as (
  case
    when discount_kind = 'dollar' then round(discount_value * 60)::integer
    when discount_kind = 'percent' then round(discount_value * 60)::integer
    else null
  end
) stored;
alter table public.offers add column if not exists starts_at timestamptz;
alter table public.offers add column if not exists ends_at timestamptz;

delete from public.offers o
where coalesce(o.offer_type, '') <> 'points'
   or coalesce(o.required_minutes, 0) <> 0
   or o.discount_kind is null
   or o.discount_value is null;

update public.offers
   set offer_type = 'points',
       required_minutes = 0
 where offer_type is null
    or required_minutes is null;

alter table public.offers drop constraint if exists offers_type_check;
alter table public.offers add constraint offers_type_check
  check (offer_type = 'points')
  not valid;

alter table public.offers drop constraint if exists offers_required_minutes_check;
alter table public.offers add constraint offers_required_minutes_check
  check (required_minutes = 0)
  not valid;

alter table public.offers drop constraint if exists offers_redemption_code_check;
alter table public.offers add constraint offers_redemption_code_check
  check (
    redemption_code is not null
    and length(trim(redemption_code)) between 1 and 80
  )
  not valid;

alter table public.offers drop constraint if exists offers_discount_check;
alter table public.offers add constraint offers_discount_check
  check (
    (
      discount_kind = 'dollar'
      and discount_value > 0
      and discount_value <= 1000
    )
    or (
      discount_kind = 'percent'
      and discount_value > 0
      and discount_value <= 100
    )
  )
  not valid;

alter table public.offers drop constraint if exists offers_points_cost_check;
alter table public.offers add constraint offers_points_cost_check
  check (
    points_cost is not null
    and points_cost > 0
    and points_cost <= 60000
  )
  not valid;

alter table public.offers drop constraint if exists offers_window_check;
alter table public.offers add constraint offers_window_check
  check (starts_at is null or ends_at is null or starts_at < ends_at)
  not valid;

drop index if exists public.offer_redemptions_user_offer_unique;
create unique index if not exists offer_redemptions_user_offer_pending_unique
  on public.offer_redemptions (user_id, offer_id)
  where status = 'pending';

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
  points_cost,
  discount_kind,
  discount_value,
  is_active,
  starts_at,
  ends_at,
  created_at,
  updated_at
) on public.offers to authenticated;
grant insert, update, delete on public.offers to authenticated;
