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

-- Helper function: Check if current authenticated user is an owner of store
-- (SECURITY DEFINER avoids 42P17 infinite recursion that the self-referential
--  EXISTS subquery in the original policy caused on store_members)
create or replace function public.is_store_owner(lookup_store_id text)
returns boolean
language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.store_members
    where store_id::text = lookup_store_id
    and user_id = auth.uid()
    and role = 'owner'
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

-- The Flutter client has used these catalog fields since the first offline
-- release. `if not exists` keeps this script safe for both new and existing
-- projects; without it product upserts fail at runtime on older deployments.
alter table public.products add column if not exists brand text default '';
alter table public.products add column if not exists supplier_id text default '';
alter table public.products add column if not exists image_url text default '';

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
  subtotal numeric not null,
  product_name text not null default '',
  unit_label text not null default ''
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

-- 12. INVOICES TABLE (1:1 with sales; sale remains source of truth)
create table if not exists public.invoices (
  id text primary key,
  store_id text not null,
  sale_id text unique references public.sales(id) on delete cascade,
  invoice_number text not null,
  status text not null default 'ISSUED', -- 'DRAFT' | 'ISSUED' | 'PAID' | 'VOID'
  issued_at timestamptz not null,
  created_at timestamptz default now(),
  unique (store_id, invoice_number)
);
create index if not exists invoices_store_id_idx on public.invoices (store_id);
create index if not exists invoices_sale_id_idx on public.invoices (sale_id);

-- 13. CUSTOMER DEBTS TABLE
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

-- 14. DEBT PAYMENTS TABLE
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

-- 15. PRODUCT UNITS TABLE
create table if not exists public.product_units (
  id text primary key,
  store_id text not null,
  product_id text references public.products(id) on delete cascade,
  unit_name text not null, -- e.g. 'Carton'
  conversion_factor numeric not null default 1, -- e.g. 50 pieces per carton
  selling_price numeric default 0
);

-- 16. PRODUCT VARIANTS TABLE
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
alter table public.invoices enable row level security;
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
    public.is_store_owner(store_id::text)
    or user_id = auth.uid()
  )
  with check (
    public.is_store_owner(store_id::text)
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

-- Invoices
create policy "Store members invoices policy" on public.invoices
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

-- ==========================================================================
-- ATOMIC BUSINESS TRANSACTIONS
-- ==========================================================================
-- These RPCs are deliberately the only cloud write path for newly created
-- sales and supplier receipts. They are idempotent by document id, validate
-- store access from auth.uid(), and commit all related rows together.

create or replace function public.checkout_sale(
  p_sale jsonb,
  p_items jsonb,
  p_debt jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id text := p_sale->>'store_id';
  v_sale_id text := p_sale->>'id';
  v_line jsonb;
  v_product_id text;
  v_quantity numeric;
  v_stock numeric;
  v_total numeric := 0;
begin
  if v_store_id is null or v_sale_id is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Invalid sale payload';
  end if;
  if not public.is_store_member(v_store_id) then
    raise exception 'Not authorized for store %', v_store_id using errcode = '42501';
  end if;

  -- A previous successful call committed the entire document, so a retry is safe.
  if exists (select 1 from public.sales where id = v_sale_id) then
    return jsonb_build_object('id', v_sale_id, 'status', 'already_committed');
  end if;

  -- Lock the relevant catalog rows before calculating balances, preventing two
  -- terminals from accepting the same last unit concurrently.
  perform 1
  from public.products
  where store_id = v_store_id
    and id in (select value->>'product_id' from jsonb_array_elements(p_items))
  for update;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := v_line->>'product_id';
    v_quantity := (v_line->>'quantity')::numeric;
    if v_product_id is null or v_quantity is null or v_quantity <= 0 then
      raise exception 'Invalid sale item';
    end if;

    select coalesce(sum(case
      when type in ('PURCHASE', 'RETURN', 'stockIn') then quantity
      when type in ('SALE', 'stockOut') then -quantity
      when type = 'ADJUSTMENT' then quantity
      else 0
    end), 0)
    into v_stock
    from public.stock_movements
    where store_id = v_store_id and product_id = v_product_id;

    if v_stock < v_quantity then
      raise exception 'Insufficient stock for product %', v_product_id using errcode = 'P0001';
    end if;

    if (v_line->>'subtotal')::numeric <> (v_line->>'unit_price')::numeric * v_quantity then
      raise exception 'Invalid sale item subtotal';
    end if;
    v_total := v_total + (v_line->>'subtotal')::numeric;
  end loop;

  if v_total <> (p_sale->>'total')::numeric then
    raise exception 'Sale total does not match its items';
  end if;

  insert into public.sales (id, store_id, user_id, customer_id, total, payment_method, created_at)
  values (
    v_sale_id, v_store_id, auth.uid()::text, coalesce(p_sale->>'customer_id', ''),
    v_total, p_sale->>'payment_method', coalesce((p_sale->>'created_at')::timestamptz, now())
  );

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    insert into public.sale_items (id, sale_id, product_id, quantity, unit_price, subtotal, product_name, unit_label)
    values (
      v_line->>'id', v_sale_id, v_line->>'product_id', (v_line->>'quantity')::numeric,
      (v_line->>'unit_price')::numeric, (v_line->>'subtotal')::numeric,
      coalesce(v_line->>'product_name', ''), coalesce(v_line->>'unit_label', '')
    );
    insert into public.stock_movements (id, product_id, store_id, user_id, device_id, type, quantity, note, created_at)
    values (
      v_sale_id || ':' || (v_line->>'product_id'), v_line->>'product_id', v_store_id,
      auth.uid()::text, coalesce(p_sale->>'device_id', ''), 'SALE', (v_line->>'quantity')::numeric,
      'Vente #' || left(v_sale_id, 8), coalesce((p_sale->>'created_at')::timestamptz, now())
    );
  end loop;

  if p_debt is not null then
    if p_sale->>'payment_method' <> 'credit' then raise exception 'Debt requires credit payment'; end if;
    if not exists (select 1 from public.customers where id = p_debt->>'customer_id' and store_id = v_store_id) then
      raise exception 'Customer does not belong to store';
    end if;
    insert into public.customer_debts (id, store_id, customer_id, sale_id, total_amount, paid_amount, remaining_amount, due_date, status, created_at)
    values (
      p_debt->>'id', v_store_id, p_debt->>'customer_id', v_sale_id,
      (p_debt->>'total_amount')::numeric, coalesce((p_debt->>'paid_amount')::numeric, 0),
      (p_debt->>'remaining_amount')::numeric, nullif(p_debt->>'due_date', '')::timestamptz,
      coalesce(p_debt->>'status', 'UNPAID'), coalesce((p_debt->>'created_at')::timestamptz, now())
    );
  elsif p_sale->>'payment_method' = 'credit' then
    raise exception 'Credit sale requires debt payload';
  end if;

  -- Invoice is created atomically with the sale. The number is allocated
  -- server-side by next_invoice_number() (never MAX()+1, never client-supplied).
  -- The invoice id equals the sale id because the relationship is 1:1, which
  -- also makes the whole document idempotent: a retry returns early above.
  insert into public.invoices (id, store_id, sale_id, invoice_number, status, issued_at, created_at)
  values (
    v_sale_id, v_store_id, v_sale_id,
    public.next_invoice_number(v_store_id),
    'ISSUED',
    coalesce((p_sale->>'created_at')::timestamptz, now()),
    now()
  );

  return jsonb_build_object('id', v_sale_id, 'status', 'committed');
end;
$$;

create or replace function public.receive_purchase(p_purchase jsonb, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id text := p_purchase->>'store_id';
  v_purchase_id text := p_purchase->>'id';
  v_line jsonb;
  v_total numeric := 0;
begin
  if v_store_id is null or v_purchase_id is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Invalid purchase payload';
  end if;
  if not public.is_store_member(v_store_id) then
    raise exception 'Not authorized for store %', v_store_id using errcode = '42501';
  end if;
  if exists (select 1 from public.purchase_orders where id = v_purchase_id) then
    return jsonb_build_object('id', v_purchase_id, 'status', 'already_committed');
  end if;
  if not exists (select 1 from public.suppliers where id = p_purchase->>'supplier_id' and store_id = v_store_id) then
    raise exception 'Supplier does not belong to store';
  end if;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    if (v_line->>'quantity')::numeric <= 0 or (v_line->>'buy_price')::numeric < 0 then
      raise exception 'Invalid purchase item';
    end if;
    if not exists (select 1 from public.products where id = v_line->>'product_id' and store_id = v_store_id) then
      raise exception 'Product does not belong to store';
    end if;
    if (v_line->>'subtotal')::numeric <> (v_line->>'quantity')::numeric * (v_line->>'buy_price')::numeric then
      raise exception 'Invalid purchase item subtotal';
    end if;
    v_total := v_total + (v_line->>'subtotal')::numeric;
  end loop;
  if v_total <> (p_purchase->>'total')::numeric then raise exception 'Purchase total does not match its items'; end if;

  insert into public.purchase_orders (id, store_id, supplier_id, created_by, total, payment_status, created_at)
  values (v_purchase_id, v_store_id, p_purchase->>'supplier_id', auth.uid()::text, v_total,
          coalesce(p_purchase->>'payment_status', 'PAID'), coalesce((p_purchase->>'created_at')::timestamptz, now()));
  for v_line in select value from jsonb_array_elements(p_items)
  loop
    insert into public.purchase_items (id, purchase_id, product_id, quantity, buy_price, subtotal)
    values (v_line->>'id', v_purchase_id, v_line->>'product_id', (v_line->>'quantity')::numeric,
            (v_line->>'buy_price')::numeric, (v_line->>'subtotal')::numeric);
    insert into public.stock_movements (id, product_id, store_id, user_id, device_id, type, quantity, note, created_at)
    values (v_purchase_id || ':' || (v_line->>'product_id'), v_line->>'product_id', v_store_id,
            auth.uid()::text, coalesce(p_purchase->>'device_id', ''), 'PURCHASE',
            (v_line->>'quantity')::numeric, 'Réception #' || left(v_purchase_id, 8),
            coalesce((p_purchase->>'created_at')::timestamptz, now()));
  end loop;
  return jsonb_build_object('id', v_purchase_id, 'status', 'committed');
end;
$$;

revoke all on function public.checkout_sale(jsonb, jsonb, jsonb) from public;
revoke all on function public.receive_purchase(jsonb, jsonb) from public;
grant execute on function public.checkout_sale(jsonb, jsonb, jsonb) to authenticated;
grant execute on function public.receive_purchase(jsonb, jsonb) to authenticated;
