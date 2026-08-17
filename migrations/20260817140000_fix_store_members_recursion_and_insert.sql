-- ============================================================================
-- Migration: Fix store_members RLS Infinite Recursion (42P17) & Store INSERT (42501)
-- ============================================================================
-- 1. Root Cause of 42P17:
--    PostgreSQL inlines LANGUAGE sql functions during query planning. When inlined,
--    the subquery on store_members triggers the table's own SELECT/ALL policy,
--    causing recursive evaluation.
--    Fix: Replace with LANGUAGE plpgsql functions with explicit search_path = public, pg_temp
--    and SECURITY DEFINER, which prevents SQL query inlining and safely bypasses RLS.
--
-- 2. Root Cause of 42501 on Store Creation:
--    When a user creates a new store, PostgREST evaluates the SELECT policy on the
--    returned row. Since no store_members row exists yet, is_store_member(id) fails.
--    Fix: Allow owner_id = auth.uid() directly in the SELECT policy, and attach an
--    authoritative AFTER INSERT trigger on public.stores to automatically create the
--    initial 'owner' membership.

-- ----------------------------------------------------------------------------
-- 1. Helper Functions (PL/pgSQL + SECURITY DEFINER + Fixed search_path)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_store_member(lookup_store_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.store_members
    WHERE store_id::text = lookup_store_id
      AND user_id = auth.uid()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.is_store_member(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_store_member(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_store_owner(lookup_store_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.store_members
    WHERE store_id::text = lookup_store_id
      AND user_id = auth.uid()
      AND role = 'owner'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.is_store_owner(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_store_owner(text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. Authoritative Store Creation Trigger
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_store()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.store_members (id, store_id, user_id, role)
  VALUES (gen_random_uuid(), NEW.id, NEW.owner_id, 'owner')
  ON CONFLICT (store_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_store() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_store() TO authenticated;

DROP TRIGGER IF EXISTS on_store_created ON public.stores;
CREATE TRIGGER on_store_created
  AFTER INSERT ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_store();

-- ----------------------------------------------------------------------------
-- 3. Stores Table RLS Policies
-- ----------------------------------------------------------------------------
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can read store" ON public.stores;
DROP POLICY IF EXISTS "Users can create stores" ON public.stores;
DROP POLICY IF EXISTS "Users can insert own store" ON public.stores;
DROP POLICY IF EXISTS "Store owners can update store" ON public.stores;
DROP POLICY IF EXISTS "Store members and owners can read store" ON public.stores;

CREATE POLICY "Store members and owners can read store" ON public.stores
  FOR SELECT
  USING (owner_id = auth.uid() OR public.is_store_member(id::text));

CREATE POLICY "Users can insert own store" ON public.stores
  FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Store owners can update store" ON public.stores
  FOR UPDATE
  USING (auth.uid() = owner_id OR public.is_store_owner(id::text))
  WITH CHECK (auth.uid() = owner_id OR public.is_store_owner(id::text));

-- ----------------------------------------------------------------------------
-- 4. Store Members Table RLS Policies
-- ----------------------------------------------------------------------------
ALTER TABLE public.store_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can read memberships" ON public.store_members;
DROP POLICY IF EXISTS "Store owners can manage memberships" ON public.store_members;
DROP POLICY IF EXISTS "Store owners can insert memberships" ON public.store_members;
DROP POLICY IF EXISTS "Store owners can update memberships" ON public.store_members;
DROP POLICY IF EXISTS "Store owners can delete memberships" ON public.store_members;

CREATE POLICY "Store members can read memberships" ON public.store_members
  FOR SELECT
  USING (user_id = auth.uid() OR public.is_store_member(store_id::text));

CREATE POLICY "Store owners can insert memberships" ON public.store_members
  FOR INSERT
  WITH CHECK (
    public.is_store_owner(store_id::text)
    OR user_id = auth.uid()
    OR auth.uid() = (SELECT owner_id FROM public.stores WHERE id = store_members.store_id)
  );

CREATE POLICY "Store owners can update memberships" ON public.store_members
  FOR UPDATE
  USING (public.is_store_owner(store_id::text))
  WITH CHECK (public.is_store_owner(store_id::text));

CREATE POLICY "Store owners can delete memberships" ON public.store_members
  FOR DELETE
  USING (public.is_store_owner(store_id::text));
