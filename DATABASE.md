# Database Documentation - Quincaillerie Pro OS

## 1. Relational Schema & Multi-Tenancy

Every business entity table contains `store_id` to guarantee multi-tenant data isolation.

### Core Entities:
1. `profiles`: `id (uuid)`, `full_name`, `phone`, `role` (`owner` | `manager` | `cashier` | `stock_manager`).
2. `stores`: `id (uuid)`, `name`, `address`, `phone`, `owner_id`.
3. `store_members`: `id`, `store_id`, `user_id`, `role`.
4. `products`: `id`, `store_id`, `name`, `barcode`, `category`, `unit`, `buy_price`, `sell_price`, `quantity`, `low_stock_threshold`.
5. `stock_movements`: `id`, `store_id`, `product_id`, `user_id`, `device_id`, `type` (`PURCHASE` | `SALE` | `ADJUSTMENT` | `RETURN`), `quantity`, `created_at`.
6. `sales` & `sale_items`: POS checkout transactions.
7. `suppliers` & `purchase_orders`: Supplier purchasing orders & stock replenishment.
8. `customers`, `customer_debts`, `debt_payments`: Customer credit lines ("Ardoises") and partial payment history.
9. `product_units` & `product_variants`: Unit conversions (Carton = 50 units) and variant matrices.
10. `sync_logs`: Diagnostic log for failed sync operations.

---

## 2. PostgreSQL Row Level Security (RLS)

See complete implementation script: [supabase_rls.sql](file:///c:/Users/mossa/Downloads/quincaillerie_app/quincaillerie_app/supabase_rls.sql)

Security helper function:
```sql
create or replace function public.is_store_member(lookup_store_id text)
returns boolean
language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.store_members
    where store_id::text = lookup_store_id
    and user_id = auth.uid()
  );
$$;
```

All table policies enforce `USING (is_store_member(store_id))` and `WITH CHECK (is_store_member(store_id))`.
