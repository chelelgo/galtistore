-- =====================================================================
-- GALTI MINI-MART · Supabase schema (run once in SQL Editor → New query)
-- =====================================================================

-- 1. TABLES -----------------------------------------------------------
create table if not exists public.products (
  id          text primary key,
  name        text not null,
  barcode     text,
  price       numeric(12,2) not null check (price >= 0),
  was_price   numeric(12,2) not null default 0,
  stock       integer not null default 0 check (stock >= 0),
  unit        text default 'PCS',
  aisle       text not null,
  description text,
  image_url   text,                       -- null = use default photo, '' = no photo
  hidden      boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists products_updated_idx on public.products (updated_at, id);
create index if not exists products_barcode_idx on public.products (barcode);

create table if not exists public.settings (key text primary key, value jsonb not null);
create table if not exists public.promos   (code text primary key, percent numeric not null check (percent between 0 and 100), active boolean not null default true);
create table if not exists public.admins   (email text primary key);

create table if not exists public.orders (
  code          text primary key,
  customer_name text not null,
  phone         text not null,
  area          text not null,
  note          text,
  pay_method    text not null,
  slot          text,
  items         jsonb not null,          -- [[name, qty, price, product_id], ...]
  subtotal      numeric(12,2) not null,
  discount      numeric(12,2) not null default 0,
  fee           numeric(12,2) not null default 0,
  total         numeric(12,2) not null,
  status        integer not null default 0 check (status between 0 and 4), -- 0 received,1 packing,2 on the way,3 delivered,4 cancelled
  rider         text,
  created_at    timestamptz not null default now()
);
create index if not exists orders_created_idx on public.orders (created_at desc);

create table if not exists public.sales (
  id         text primary key,
  items      jsonb not null,
  total      numeric(12,2) not null,
  pay_method text not null,
  cashier    text,
  created_at timestamptz not null default now()
);

-- keep products.updated_at fresh (the storefront syncs by this column)
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists products_touch on public.products;
create trigger products_touch before update on public.products for each row execute function public.touch_updated_at();

-- 2. DEFAULT SETTINGS --------------------------------------------------
insert into public.settings (key, value) values
  ('zones',  '[{"name":"Elgonview","fee":99},{"name":"Elgonview Phase 2","fee":99},{"name":"Pioneer","fee":129},{"name":"Kapsoya","fee":129},{"name":"West Indies","fee":129},{"name":"Annex","fee":129},{"name":"Eldoret CBD","fee":199}]'),
  ('free',   '2000'),
  ('riders', '[]'),
  ('wa',     '"254700000000"'),
  ('hours',  '"6:30 AM – 10 PM"')
on conflict (key) do nothing;
insert into public.promos (code, percent) values ('GALTI10', 10) on conflict (code) do nothing;

-- 3. ADMIN CHECK ------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins a where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

-- 4. ROW LEVEL SECURITY ------------------------------------------------
alter table public.products enable row level security;
alter table public.settings enable row level security;
alter table public.promos   enable row level security;
alter table public.admins   enable row level security;
alter table public.orders   enable row level security;
alter table public.sales    enable row level security;

drop policy if exists "products public read"  on public.products;
drop policy if exists "products admin write"  on public.products;
create policy "products public read" on public.products for select using (true);
create policy "products admin write" on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "settings public read"  on public.settings;
drop policy if exists "settings admin write"  on public.settings;
create policy "settings public read" on public.settings for select using (true);
create policy "settings admin write" on public.settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "promos admin" on public.promos;
create policy "promos admin" on public.promos for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "orders admin read"   on public.orders;
drop policy if exists "orders admin update" on public.orders;
create policy "orders admin read"   on public.orders for select to authenticated using (public.is_admin());
create policy "orders admin update" on public.orders for update to authenticated using (public.is_admin()) with check (public.is_admin());
-- (no insert policy: customers can only create orders through place_order() below)

drop policy if exists "sales admin" on public.sales;
create policy "sales admin" on public.sales for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- admins table: RLS on with no policies = invisible to the API (only is_admin() reads it)

-- 5. PLACE ORDER (public) · prices, stock, fee and promo are decided HERE, not in the browser
create or replace function public.place_order(
  p_name text, p_phone text, p_area text, p_note text, p_pay text, p_slot text, p_items jsonb, p_promo text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  it jsonb; pr public.products%rowtype; q int; sub numeric := 0; lines jsonb := '[]'::jsonb;
  disc numeric := 0; fee numeric := 0; free numeric := 2000; zf numeric; pct numeric; v_code text; total numeric; ph text;
begin
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'INVALID_NAME'; end if;
  ph := regexp_replace(coalesce(p_phone,''), '[\s-]', '', 'g');
  if ph !~ '^(\+?254|0)[17][0-9]{8}$' then raise exception 'INVALID_PHONE'; end if;
  if p_pay not in ('M-Pesa','Cash','Card') then raise exception 'INVALID_PAYMENT'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 80 then raise exception 'INVALID_ITEMS'; end if;

  for it in select * from jsonb_array_elements(p_items) loop
    q := (it ->> 'qty')::int;
    if q is null or q < 1 or q > 200 then raise exception 'INVALID_QTY'; end if;
    select * into pr from public.products where id = it ->> 'id' and not hidden for update;
    if not found then raise exception 'UNKNOWN_PRODUCT:%', it ->> 'id'; end if;
    if pr.stock < q then raise exception 'OUT_OF_STOCK:%', pr.name; end if;
    update public.products set stock = stock - q where id = pr.id;
    sub := sub + pr.price * q;
    lines := lines || jsonb_build_array(jsonb_build_array(pr.name, q, pr.price, pr.id));
  end loop;

  select pr2.percent into pct from public.promos pr2 where pr2.code = upper(trim(coalesce(p_promo,''))) and pr2.active;
  disc := round(sub * coalesce(pct,0) / 100);
  select (st.value #>> '{}')::numeric into free from public.settings st where st.key = 'free';
  select (e ->> 'fee')::numeric into zf from jsonb_array_elements((select st.value from public.settings st where st.key = 'zones')) e where e ->> 'name' = p_area limit 1;
  fee := case when sub - disc >= coalesce(free, 2000) then 0 else coalesce(zf, 199) end;
  total := sub - disc + fee;

  loop
    v_code := 'G' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.orders o2 where o2.code = v_code);
  end loop;

  insert into public.orders (code, customer_name, phone, area, note, pay_method, slot, items, subtotal, discount, fee, total)
  values (v_code, trim(p_name), ph, p_area, nullif(trim(coalesce(p_note,'')),''), p_pay, p_slot, lines, sub, disc, fee, total);

  return jsonb_build_object('code', v_code, 'subtotal', sub, 'discount', disc, 'fee', fee, 'total', total);
end $$;

-- 6. TRACK ORDER (public, status only: no personal data leaves the database)
create or replace function public.track_order(p_code text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('status', status) from public.orders where code = upper(trim(p_code));
$$;

-- 7. ADMIN: set order status (cancelling puts the stock back)
create or replace function public.set_order_status(p_code text, p_status int) returns void
language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype; l jsonb;
begin
  if not public.is_admin() then raise exception 'FORBIDDEN'; end if;
  if p_status not between 0 and 4 then raise exception 'INVALID_STATUS'; end if;
  select * into o from public.orders where code = p_code for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.status = 4 then raise exception 'ALREADY_CANCELLED'; end if;
  if p_status = 4 then
    for l in select * from jsonb_array_elements(o.items) loop
      update public.products set stock = stock + (l ->> 1)::int where id = l ->> 3;
    end loop;
  end if;
  update public.orders set status = p_status where code = p_code;
end $$;

-- 8. ADMIN: POS sale (decrements stock, records the sale)
create or replace function public.pos_sale(p_items jsonb, p_pay text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare it jsonb; pr public.products%rowtype; q int; total numeric := 0; lines jsonb := '[]'::jsonb; sid text;
begin
  if not public.is_admin() then raise exception 'FORBIDDEN'; end if;
  if p_pay not in ('Cash','M-Pesa','Card') then raise exception 'INVALID_PAYMENT'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'INVALID_ITEMS'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    q := (it ->> 'qty')::int;
    if q is null or q < 1 then raise exception 'INVALID_QTY'; end if;
    select * into pr from public.products where id = it ->> 'id' for update;
    if not found then raise exception 'UNKNOWN_PRODUCT:%', it ->> 'id'; end if;
    if pr.stock < q then raise exception 'OUT_OF_STOCK:%', pr.name; end if;
    update public.products set stock = stock - q where id = pr.id;
    total := total + pr.price * q;
    lines := lines || jsonb_build_array(jsonb_build_array(pr.name, q, pr.price, pr.id));
  end loop;
  sid := 'S' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
  insert into public.sales (id, items, total, pay_method, cashier) values (sid, lines, total, p_pay, auth.jwt() ->> 'email');
  return jsonb_build_object('id', sid, 'total', total);
end $$;

revoke execute on function public.set_order_status(text,int) from public, anon;
revoke execute on function public.pos_sale(jsonb,text)       from public, anon;
grant  execute on function public.place_order(text,text,text,text,text,text,jsonb,text) to anon, authenticated;
grant  execute on function public.track_order(text) to anon, authenticated;
grant  execute on function public.is_admin() to anon, authenticated;
grant  execute on function public.set_order_status(text,int) to authenticated;
grant  execute on function public.pos_sale(jsonb,text)       to authenticated;

-- 9. REALTIME (live stock + live orders in the back office)
do $$ begin
  begin alter publication supabase_realtime add table public.products; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.orders;   exception when duplicate_object then null; end;
end $$;

-- 10. PRODUCT PHOTO STORAGE (public read, only admins can upload)
insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true) on conflict (id) do nothing;
drop policy if exists "product images public read" on storage.objects;
drop policy if exists "product images admin insert" on storage.objects;
drop policy if exists "product images admin update" on storage.objects;
drop policy if exists "product images admin delete" on storage.objects;
create policy "product images public read"  on storage.objects for select using (bucket_id = 'product-images');
create policy "product images admin insert" on storage.objects for insert to authenticated with check (bucket_id = 'product-images' and public.is_admin());
create policy "product images admin update" on storage.objects for update to authenticated using (bucket_id = 'product-images' and public.is_admin());
create policy "product images admin delete" on storage.objects for delete to authenticated using (bucket_id = 'product-images' and public.is_admin());

-- 11. MAKE YOURSELF AN ADMIN · replace with the email you log in with, then run this line
-- insert into public.admins (email) values ('you@example.com');
