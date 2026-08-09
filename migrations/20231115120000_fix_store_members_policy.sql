-- Migration to fix infinite recursion in store_members policy

-- Create the is_store_owner function
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

-- Update the policy to use the new function
ALTER POLICY "Store owners can manage memberships"
ON public.store_members
FOR ALL
USING (
  public.is_store_owner(store_id::text)
  OR user_id = auth.uid()
)
WITH CHECK (
  public.is_store_owner(store_id::text)
  OR user_id = auth.uid()
);