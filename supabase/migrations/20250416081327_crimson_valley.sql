/*
  # Fix resource acceptance and messaging

  1. Changes
    - Improve error handling in accept_resource function
    - Ensure messages are created even when no thread exists
    - Fix contact sharing logic
    - Add proper transaction handling

  2. Security
    - Maintain existing RLS policies
    - Keep SECURITY DEFINER setting
*/

-- Drop the existing function first
DROP FUNCTION IF EXISTS accept_resource(uuid, uuid);

-- Recreate the function with improved message handling
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
  v_resource_competence text;
BEGIN
  -- Get the resource owner's company ID and competence
  SELECT r.company_id, r.competence 
  INTO v_resource_owner_id, v_resource_competence
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
  AND (
    (m.from_company_id = p_accepting_company_id AND m.to_company_id = v_resource_owner_id)
    OR 
    (m.from_company_id = v_resource_owner_id AND m.to_company_id = p_accepting_company_id)
  )
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

  -- If no thread exists, create one
  IF v_thread_id IS NULL THEN
    INSERT INTO messages (
      from_company_id,
      to_company_id,
      resource_id,
      subject,
      content
    )
    VALUES (
      p_accepting_company_id,
      v_resource_owner_id,
      p_resource_id,
      'Akseptert: ' || v_resource_competence,
      'Jeg ønsker å akseptere dette tilbudet.'
    )
    RETURNING id INTO v_thread_id;
  END IF;

  -- Create contact sharing entries for both companies
  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  VALUES 
    (v_thread_id, v_resource_owner_id, p_accepting_company_id),
    (v_thread_id, p_accepting_company_id, v_resource_owner_id)
  ON CONFLICT DO NOTHING;

  -- Insert acceptance message
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
END;
$$;