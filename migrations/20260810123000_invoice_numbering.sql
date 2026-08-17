-- ============================================================================
-- Migration: Store-scoped atomic invoice numbering
-- ============================================================================
-- Adds the public.store_sequences counter table and the SECURITY DEFINER
-- function next_invoice_number() that atomically allocates per-store invoice
-- numbers with the INV-YYYY-0001 format.
--
-- The invoices table itself (id, store_id, sale_id, invoice_number, status,
-- issued_at, created_at) is part of the Step 1 schema. This migration does not
-- recreate it; it only guarantees (idempotently) the required indexes / RLS /
-- format CHECK and adds the numbering layer.
--
-- Concurrency guarantees:
--   * Numbers are allocated in a single INSERT ... ON CONFLICT DO UPDATE,
--     which row-locks the (store_id, year) counter. Concurrent allocations
--     serialize on that row lock and never observe the same value twice.
--   * NEVER MAX()+1: the counter is a stored last_value that is incremented,
--     never derived from a scan of the invoices table.
--   * Per-store + per-year scope: the primary key (store_id, year) lets two
--     stores maintain independent, identical sequences, and the sequence
--     restarts each calendar year.
--   * The year always comes from the server clock (extract(year from now())),
--     so a client can never supply or influence the allocated number.
--   * Rolled-back allocations leave gaps. Gaps are intentional: invoice
--     numbers must never be reused.

-- ----------------------------------------------------------------------------
-- 1. Guarantee the invoices table is RLS-protected (existing pattern)
-- ----------------------------------------------------------------------------
alter table public.invoices enable row level security;

create policy if not exists "Store members invoices policy" on public.invoices
  for all
  using (public.is_store_member(store_id))
  with check (public.is_store_member(store_id));

-- ----------------------------------------------------------------------------
-- 2. Guarantee the required invoices indexes/constraints (matches Drift model)
--    invoices_store_id_idx            -> non-unique (store_id)
--    invoices_sale_id_idx             -> unique (sale_id)  [FK, 1:1 with sales]
--    invoices_store_number_idx        -> unique (store_id, invoice_number)
-- ----------------------------------------------------------------------------
create index if not exists invoices_store_id_idx on public.invoices (store_id);
create unique index if not exists invoices_sale_id_idx on public.invoices (sale_id);
create unique index if not exists invoices_store_number_idx on public.invoices (store_id, invoice_number);

-- ----------------------------------------------------------------------------
-- 3. Enforce the INV-YYYY-NNNN format server-side (defense-in-depth)
-- ----------------------------------------------------------------------------
-- The authoritative number comes from next_invoice_number(); the CHECK
-- guarantees no row with an out-of-format number can ever be persisted.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'invoices_invoice_number_format_check'
      and conrelid = 'public.invoices'::regclass
  ) then
    alter table public.invoices
      add constraint invoices_invoice_number_format_check
      check (invoice_number ~ '^INV-[0-9]{4}-[0-9]{4,}$');
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 4. Per-store invoice counters
-- ----------------------------------------------------------------------------
create table if not exists public.store_sequences (
  store_id text not null,
  year integer not null,
  last_value bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (store_id, year),
  constraint store_sequences_year_check check (year between 2000 and 9999),
  constraint store_sequences_last_value_non_negative check (last_value >= 0)
);

comment on table public.store_sequences is
  'Atomic per-store, per-year invoice counters. Clients must never read or write this table directly; allocate via public.next_invoice_number().';

-- ----------------------------------------------------------------------------
-- 5. Atomic number allocation (SECURITY DEFINER)
-- ----------------------------------------------------------------------------
create or replace function public.next_invoice_number(p_store_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_year integer := extract(year from now())::integer;
  v_seq  bigint;
begin
  if p_store_id is null or p_store_id = '' then
    raise exception 'Store id is required';
  end if;

  if not public.is_store_member(p_store_id) then
    raise exception 'Not authorized for store %', p_store_id using errcode = '42501';
  end if;

  -- Single atomic statement: on first use the counter row is inserted with 1,
  -- on every later use the stored last_value is incremented. Concurrent
  -- transactions block on the (store_id, year) row lock until the winner
  -- commits, then continue from the committed value -- no duplicates, no
  -- MAX+1 scans, no client-supplied numbers.
  insert into public.store_sequences (store_id, year, last_value, updated_at)
  values (p_store_id, v_year, 1, now())
  on conflict (store_id, year)
  do update set
    last_value = public.store_sequences.last_value + 1,
    updated_at = now()
  returning last_value
  into v_seq;

  return format('INV-%s-%s', v_year, lpad(v_seq::text, 4, '0'));
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. RLS & privileges
-- ----------------------------------------------------------------------------
-- RLS is enabled with NO policies on store_sequences on purpose: the counter
-- rows are only ever touched by the SECURITY DEFINER function above. Members
-- are authorized inside the function with the same is_store_member() check
-- used by every other policy, so the existing store-membership security
-- pattern is preserved without exposing the counter to clients.
alter table public.store_sequences enable row level security;

-- Explicitly deny any direct client DML/read on the counter table.
revoke all on table public.store_sequences from anon;
revoke all on table public.store_sequences from authenticated;
revoke all on table public.store_sequences from public;

-- The allocation function is the only sanctioned path (same revoke/grant
-- convention used for checkout_sale / receive_purchase).
revoke all on function public.next_invoice_number(text) from public;
grant execute on function public.next_invoice_number(text) to authenticated;