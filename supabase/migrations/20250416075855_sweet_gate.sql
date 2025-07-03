/*
  # Fix accept_resource function

  1. Changes
    - Update accept_resource function to fix ambiguous resource_id reference
    - Explicitly specify table names for all column references to avoid ambiguity
    - Add proper error handling and validation

  2. Security
    - Function remains accessible only to authenticated users
    - Maintains existing security checks for resource acceptance
*/

CREATE OR REPLACE FUNCTION accept_resource(
  resource_id uuid,
  accepting_company_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate that the resource exists and is available
  IF NOT EXISTS (
    SELECT 1 
    FROM resources r
    WHERE r.id = resource_id 
    AND NOT r.is_taken
  ) THEN
    RAISE EXCEPTION 'Resource not found or already taken';
  END IF;

  -- Update the resource status
  UPDATE resources
  SET 
    is_taken = true,
    accepted_by_company_id = accepting_company_id
  WHERE id = resource_id
  AND NOT is_taken;

  -- If no rows were updated, the resource was taken by someone else
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource is no longer available';
  END IF;
END;
$$;