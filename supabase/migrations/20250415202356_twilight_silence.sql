/*
  # Fix resource acceptance function and policies

  1. Changes
    - Improve error handling in accept_resource function
    - Add better validation for company existence
    - Fix policy conflicts
    - Add detailed error messages

  2. Security
    - Maintain existing RLS policies
    - Ensure proper access control
*/

-- Drop existing policies to avoid conflicts
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Companies can view available resources" ON resources;
  DROP POLICY IF EXISTS "Companies can accept resources" ON resources;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Drop existing function to recreate it
DROP FUNCTION IF EXISTS accept_resource(uuid, uuid);

-- Recreate the function with better error handling
CREATE OR REPLACE FUNCTION accept_resource(
  resource_id uuid,
  accepting_company_id uuid
) RETURNS void AS $$
DECLARE
  resource_owner_id uuid;
  resource_exists boolean;
  accepting_company_exists boolean;
BEGIN
  -- Check if resource exists
  SELECT EXISTS (
    SELECT 1 FROM resources WHERE id = resource_id
  ) INTO resource_exists;

  IF NOT resource_exists THEN
    RAISE EXCEPTION 'Resource with ID % does not exist', resource_id;
  END IF;

  -- Check if accepting company exists
  SELECT EXISTS (
    SELECT 1 FROM companies WHERE id = accepting_company_id
  ) INTO accepting_company_exists;

  IF NOT accepting_company_exists THEN
    RAISE EXCEPTION 'Company with ID % does not exist', accepting_company_id;
  END IF;

  -- Get the resource owner's company ID
  SELECT company_id INTO resource_owner_id
  FROM resources
  WHERE id = resource_id;

  -- Additional validations
  IF resource_owner_id IS NULL THEN
    RAISE EXCEPTION 'Resource owner company not found';
  END IF;

  IF resource_owner_id = accepting_company_id THEN
    RAISE EXCEPTION 'Cannot accept your own resource';
  END IF;

  -- Check if resource is already taken
  IF EXISTS (
    SELECT 1 FROM resources 
    WHERE id = resource_id AND is_taken = true
  ) THEN
    RAISE EXCEPTION 'Resource is already taken';
  END IF;

  -- Mark resource as taken
  UPDATE resources 
  SET 
    is_taken = true,
    accepted_by_company_id = accepting_company_id
  WHERE id = resource_id 
  AND NOT is_taken
  AND company_id = resource_owner_id
  AND company_id != accepting_company_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Failed to update resource status';
  END IF;

  -- Create contact sharing entries for both companies
  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  SELECT DISTINCT
    m.id,
    resource_owner_id,
    accepting_company_id
  FROM messages m
  WHERE m.resource_id = resource_id
  ON CONFLICT DO NOTHING;

  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  SELECT DISTINCT
    m.id,
    accepting_company_id,
    resource_owner_id
  FROM messages m
  WHERE m.resource_id = resource_id
  ON CONFLICT DO NOTHING;

  -- Insert system message about acceptance
  INSERT INTO messages (
    from_company_id,
    to_company_id,
    resource_id,
    subject,
    content,
    thread_id
  )
  SELECT
    accepting_company_id,
    resource_owner_id,
    resource_id,
    'Tilbud akseptert',
    'Tilbudet er akseptert. Kontaktinformasjon er nå delt mellom partene.',
    m.id
  FROM messages m
  WHERE m.resource_id = resource_id
  LIMIT 1;

EXCEPTION
  WHEN others THEN
    RAISE EXCEPTION 'Error accepting resource: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Recreate the policies
CREATE POLICY "Companies can view available resources"
  ON resources
  FOR SELECT
  TO authenticated
  USING (
    NOT is_taken OR 
    company_id IN (
      SELECT id FROM companies WHERE user_id = auth.uid()
    ) OR
    accepted_by_company_id IN (
      SELECT id FROM companies WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Companies can accept resources"
  ON resources
  FOR UPDATE
  TO authenticated
  USING (
    NOT is_taken AND
    company_id != (
      SELECT id FROM companies WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    accepted_by_company_id IN (
      SELECT id FROM companies WHERE user_id = auth.uid()
    )
  );