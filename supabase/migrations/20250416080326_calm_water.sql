/*
  # Fix resource acceptance messaging

  1. Changes
    - Update accept_resource function to properly create system messages
    - Add automatic contact sharing on acceptance
    - Ensure messages are created in the correct thread

  2. Security
    - Maintain SECURITY DEFINER for proper access control
    - Add proper error handling
*/

CREATE OR REPLACE FUNCTION accept_resource(
  resource_id uuid,
  accepting_company_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  resource_owner_id uuid;
  thread_id uuid;
BEGIN
  -- Get the resource owner's company ID
  SELECT company_id INTO resource_owner_id
  FROM resources
  WHERE id = resource_id;

  IF resource_owner_id IS NULL THEN
    RAISE EXCEPTION 'Resource not found';
  END IF;

  -- Get the existing thread ID if any
  SELECT m.id INTO thread_id
  FROM messages m
  WHERE m.resource_id = resource_id
  ORDER BY m.created_at ASC
  LIMIT 1;

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

  -- Create contact sharing entries for both companies
  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  VALUES 
    (COALESCE(thread_id, gen_random_uuid()), resource_owner_id, accepting_company_id),
    (COALESCE(thread_id, gen_random_uuid()), accepting_company_id, resource_owner_id)
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
  VALUES (
    accepting_company_id,
    resource_owner_id,
    resource_id,
    'Tilbud akseptert',
    'Tilbudet er akseptert. Kontaktinformasjon er nå delt mellom partene.',
    thread_id
  );
END;
$$;