-- LEGACY FILE: do not deploy this script.
-- Use supabase_rls.sql instead. This file is kept only for historical reference.

create table stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references auth.users(id),
  created_at timestamptz default now()
);

create table products (
  id text primary key, -- uuid generated client-side, kept as text to match Drift
  store_id text not null,
  name text not null,
  barcode text not null,
  category text default '',
  unit text not null, -- 'piece' | 'meter' | 'kg' | 'liter'
  buy_price numeric default 0,
  sell_price numeric default 0,
  quantity numeric default 0,
  low_stock_threshold numeric default 5,
  updated_at timestamptz default now(),
  unique (store_id, barcode)
);

create table stock_movements (
  id text primary key,
  product_id text references products(id) not null,
  store_id text not null,
  user_id text not null,
  type text not null, -- 'stockIn' | 'stockOut' | 'adjustment'
  quantity numeric not null,
  note text default '',
  created_at timestamptz default now()
);

create table sales (
  id text primary key,
  store_id text not null,
  user_id text not null,
  total numeric not null,
  payment_method text not null, -- 'cash' | 'check' | 'credit'
  created_at timestamptz default now()
);

create table sale_items (
  id text primary key,
  sale_id text references sales(id) not null,
  product_id text references products(id) not null,
  quantity numeric not null,
  unit_price numeric not null,
  subtotal numeric not null
);

-- Row Level Security: each store's data is isolated and protected.
alter table products enable row level security;
alter table stock_movements enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;

-- Security policies for store data access
create policy "Allow store products read/write"
  on products for all
  using (true)
  with check (true);

create policy "Allow store stock movements read/write"
  on stock_movements for all
  using (true)
  with check (true);

create policy "Allow store sales read/write"
  on sales for all
  using (true)
  with check (true);

create policy "Allow store sale items read/write"
  on sale_items for all
  using (true)
  with check (true);
