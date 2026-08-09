-- Migration to fix infinite recursion (42P17) in store_members policy
-- The original policy used a self-referential EXISTS subquery on store_members,
-- which caused infinite recursion under RLS. This migration replaces it with
-- a SECURITY DEFINER function is_store_owner() (same pattern as is_store_member())
-- and rewrites the policy to use it in both USING and WITH CHECK.

-- Create the is_store_owner function (same pattern as is_store_member)
CREATE OR REPLACE FUNCTION public.is_store_owner(lookup_store_id text)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.store_members
    WHERE store_id::text = lookup_store_id
    AND user_id = auth.uid()
    AND role = 'owner'
  );
$$;

-- Drop the old recursive policy and recreate it using the function
DROP POLICY IF EXISTS "Store owners can manage memberships" ON public.store_members;

CREATE POLICY "Store owners can manage memberships" ON public.store_members
  FOR ALL
  USING (
    public.is_store_owner(store_id::text)
    OR user_id = auth.uid()
  )
  WITH CHECK (
    public.is_store_owner(store_id::text)
    OR user_id = auth.uid()
  );
