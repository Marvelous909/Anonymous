/*
  # Fix accept_resource function

  1. Changes
    - Drop existing function first
    - Recreate function with proper parameter names
    - Add better error handling
    - Maintain SECURITY DEFINER setting
*/

-- Drop the existing function first
DROP FUNCTION IF EXISTS accept_resource(uuid, uuid);

-- Recreate the function with proper parameter names
CREATE OR REPLACE FUNCTION accept_resource(
  p_resource_id uuid,
  p_accepting_company_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_resource_owner_id uuid;
  v_thread_id uuid;
BEGIN
  -- Get the resource owner's company ID
  SELECT r.company_id INTO v_resource_owner_id
  FROM resources r
  WHERE r.id = p_resource_id;

  IF v_resource_owner_id IS NULL THEN
    RAISE EXCEPTION 'Resource not found';
  END IF;

  IF v_resource_owner_id = p_accepting_company_id THEN
    RAISE EXCEPTION 'Cannot accept your own resource';
  END IF;

  -- Get the existing thread ID if any
  SELECT m.id INTO v_thread_id
  FROM messages m
  WHERE m.resource_id = p_resource_id
  ORDER BY m.created_at ASC
  LIMIT 1;

  -- Update the resource status
  UPDATE resources r
  SET 
    is_taken = true,
    accepted_by_company_id = p_accepting_company_id
  WHERE r.id = p_resource_id
  AND NOT r.is_taken;

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
    (COALESCE(v_thread_id, gen_random_uuid()), v_resource_owner_id, p_accepting_company_id),
    (COALESCE(v_thread_id, gen_random_uuid()), p_accepting_company_id, v_resource_owner_id)
  ON CONFLICT DO NOTHING;

  -- Insert system message about acceptance if we have a thread
  IF v_thread_id IS NOT NULL THEN
    INSERT INTO messages (
      from_company_id,
      to_company_id,
      resource_id,
      subject,
      content,
      thread_id
    )
    VALUES (
      p_accepting_company_id,
      v_resource_owner_id,
      p_resource_id,
      'Tilbud akseptert',
      'Tilbudet er akseptert. Kontaktinformasjon er nå delt mellom partene.',
      v_thread_id
    );
  END IF;
END;
$$;