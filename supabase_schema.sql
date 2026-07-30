-- Run this in Supabase Dashboard > SQL Editor when you set up your project.
-- Mirrors the local Drift schema so sync is a straight upsert, no mapping layer.

create table stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references auth.users(id),
  created_at timestamptz default now()
);

create table products (
  id text primary key, -- uuid generated client-side, kept as text to match Drift
  store_id uuid references stores(id) not null,
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
  store_id uuid references stores(id) not null,
  user_id uuid references auth.users(id) not null,
  type text not null, -- 'stockIn' | 'stockOut' | 'adjustment'
  quantity numeric not null,
  note text default '',
  created_at timestamptz default now()
);

create table sales (
  id text primary key,
  store_id uuid references stores(id) not null,
  user_id uuid references auth.users(id) not null,
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

-- Row Level Security: each store's data is only visible to its own users.
-- Set this up properly once you build real auth (Phase 1/2) -- critical
-- before going live, since by default Supabase tables are open via the API.
alter table products enable row level security;
alter table stock_movements enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
