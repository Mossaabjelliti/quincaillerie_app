-- ============================================================================
-- QUINCAILLERIE APP - MULTI-TENANT SAAS DATABASE SCHEMA & RLS POLICIES
-- ============================================================================

-- 1. PROFILES TABLE (Mirrors auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text default '',
  role text not null default 'owner', -- 'owner' | 'manager' | 'cashier' | 'stock_manager'
  created_at timestamptz default now()
);

-- Trigger to auto-create profile on user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.phone, ''),
    coalesce(new.raw_user_meta_data->>'role', 'owner')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. STORES TABLE
create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text default '',
  phone text default '',
  owner_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);

-- 3. STORE MEMBERS TABLE (Multi-tenant membership & RBAC)
create table if not exists public.store_members (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references public.stores(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'manager', 'cashier', 'stock_manager')),
  created_at timestamptz default now(),
  unique(store_id, user_id)
);

-- Helper function: Check if current authenticated user belongs to store
create or replace function public.is_store_member(lookup_store_id text)
returns boolean
language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.store_members
    where store_id::text = lookup_store_id
    and user_id = auth.uid()
  );
$$;

-- 4. PRODUCTS TABLE
create table if not exists public.products (
  id text primary key,
  store_id text not null,
  name text not null,
  barcode text not null,
  category text default '',
  unit text not null default 'piece',
  buy_price numeric default 0,
  sell_price numeric default 0,
  quantity numeric default 0,
  low_stock_threshold numeric default 5,
  updated_at timestamptz default now(),
  unique (store_id, barcode)
);

-- 5. STOCK MOVEMENTS TABLE (Event-based inventory)
create table if not exists public.stock_movements (
  id text primary key,
  product_id text references public.products(id) on delete cascade,
  store_id text not null,
  user_id text not null,
  device_id text default '',
  type text not null check (type in ('PURCHASE', 'SALE', 'ADJUSTMENT', 'RETURN', 'stockIn', 'stockOut')),
  quantity numeric not null,
  note text default '',
  created_at timestamptz default now()
);

-- 6. SALES TABLE
create table if not exists public.sales (
  id text primary key,
  store_id text not null,
  user_id text not null,
  customer_id text default '',
  total numeric not null,
  payment_method text not null check (payment_method in ('cash', 'check', 'credit')),
  created_at timestamptz default now()
);

-- 7. SALE ITEMS TABLE
create table if not exists public.sale_items (
  id text primary key,
  sale_id text references public.sales(id) on delete cascade,
  product_id text references public.products(id) on delete cascade,
  quantity numeric not null,
  unit_price numeric not null,
  subtotal numeric not null
);

-- 8. SUPPLIERS TABLE
create table if not exists public.suppliers (
  id text primary key,
  store_id text not null,
  name text not null,
  phone text default '',
  address text default '',
  email text default '',
  notes text default '',
  created_at timestamptz default now()
);

-- 9. PURCHASES TABLE
create table if not exists public.purchase_orders (
  id text primary key,
  store_id text not null,
  supplier_id text references public.suppliers(id) on delete cascade,
  created_by text not null,
  total numeric not null default 0,
  payment_status text not null default 'PAID', -- 'PAID' | 'PARTIAL' | 'PENDING'
  created_at timestamptz default now()
);

-- 10. PURCHASE ITEMS TABLE
create table if not exists public.purchase_items (
  id text primary key,
  purchase_id text references public.purchase_orders(id) on delete cascade,
  product_id text references public.products(id) on delete cascade,
  quantity numeric not null,
  buy_price numeric not null,
  subtotal numeric not null
);

-- 11. CUSTOMERS TABLE
create table if not exists public.customers (
  id text primary key,
  store_id text not null,
  name text not null,
  phone text default '',
  address text default '',
  notes text default '',
  created_at timestamptz default now()
);

-- 12. CUSTOMER DEBTS TABLE
create table if not exists public.customer_debts (
  id text primary key,
  store_id text not null,
  customer_id text references public.customers(id) on delete cascade,
  sale_id text default '',
  total_amount numeric not null,
  paid_amount numeric not null default 0,
  remaining_amount numeric not null,
  due_date timestamptz,
  status text not null default 'UNPAID', -- 'UNPAID' | 'PARTIAL' | 'PAID'
  created_at timestamptz default now()
);

-- 13. DEBT PAYMENTS TABLE
create table if not exists public.debt_payments (
  id text primary key,
  store_id text not null,
  debt_id text references public.customer_debts(id) on delete cascade,
  customer_id text references public.customers(id) on delete cascade,
  amount numeric not null,
  payment_method text not null default 'cash',
  note text default '',
  created_at timestamptz default now()
);

-- 14. PRODUCT UNITS TABLE
create table if not exists public.product_units (
  id text primary key,
  store_id text not null,
  product_id text references public.products(id) on delete cascade,
  unit_name text not null, -- e.g. 'Carton'
  conversion_factor numeric not null default 1, -- e.g. 50 pieces per carton
  selling_price numeric default 0
);

-- 15. PRODUCT VARIANTS TABLE
create table if not exists public.product_variants (
  id text primary key,
  store_id text not null,
  product_id text references public.products(id) on delete cascade,
  variant_name text not null, -- e.g. '1.5mm / 10m'
  barcode text default '',
  buy_price numeric default 0,
  sell_price numeric default 0,
  stock_quantity numeric default 0
);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS everywhere
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.store_members enable row level security;
alter table public.products enable row level security;
alter table public.stock_movements enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.suppliers enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_items enable row level security;
alter table public.customers enable row level security;
alter table public.customer_debts enable row level security;
alter table public.debt_payments enable row level security;
alter table public.product_units enable row level security;
alter table public.product_variants enable row level security;

-- Profiles: Users can read/update their own profile
create policy "Users can manage own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- Stores: Store members can read store details; owners can update/delete
create policy "Store members can read store" on public.stores
  for select using (public.is_store_member(id::text));

create policy "Users can create stores" on public.stores
  for insert with check (auth.uid() = owner_id);

create policy "Store owners can update store" on public.stores
  for update using (auth.uid() = owner_id);

-- Store Members: Store members can read member list
create policy "Store members can read memberships" on public.store_members
  for select using (public.is_store_member(store_id::text) or user_id = auth.uid());

create policy "Store owners can manage memberships" on public.store_members
  for all using (
    exists (
      select 1 from public.store_members sm
      where sm.store_id = store_members.store_id
      and sm.user_id = auth.uid()
      and sm.role = 'owner'
    )
    or user_id = auth.uid()
  );

-- Macro generator for Store Data RLS
-- Products
create policy "Store members products policy" on public.products
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Stock Movements
create policy "Store members movements policy" on public.stock_movements
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Sales
create policy "Store members sales policy" on public.sales
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Sale Items (via parent sale store membership)
create policy "Store members sale items policy" on public.sale_items
  for all using (
    exists (
      select 1 from public.sales s
      where s.id = sale_items.sale_id
      and public.is_store_member(s.store_id)
    )
  );

-- Suppliers
create policy "Store members suppliers policy" on public.suppliers
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Purchase Orders
create policy "Store members purchases policy" on public.purchase_orders
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Purchase Items
create policy "Store members purchase items policy" on public.purchase_items
  for all using (
    exists (
      select 1 from public.purchase_orders po
      where po.id = purchase_items.purchase_id
      and public.is_store_member(po.store_id)
    )
  );

-- Customers
create policy "Store members customers policy" on public.customers
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Customer Debts
create policy "Store members debts policy" on public.customer_debts
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Debt Payments
create policy "Store members debt payments policy" on public.debt_payments
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Product Units
create policy "Store members product units policy" on public.product_units
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));

-- Product Variants
create policy "Store members product variants policy" on public.product_variants
  for all using (public.is_store_member(store_id)) with check (public.is_store_member(store_id));
