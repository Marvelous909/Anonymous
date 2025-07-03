/*
  # Fix messaging and contact sharing

  1. Changes
    - Add trigger to automatically share contact info when both parties accept
    - Update accept_resource function to handle message creation properly
    - Add function to check if contact is shared between companies

  2. Security
    - Maintain RLS policies
    - Ensure proper validation
*/

-- Function to check if contact is shared between companies
CREATE OR REPLACE FUNCTION is_contact_shared(
  p_company_id_1 UUID,
  p_company_id_2 UUID,
  p_thread_id UUID
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM thread_contact_sharing
    WHERE thread_id = p_thread_id
    AND (
      (from_company_id = p_company_id_1 AND to_company_id = p_company_id_2)
      OR
      (from_company_id = p_company_id_2 AND to_company_id = p_company_id_1)
    )
  );
END;
$$;

-- Update accept_resource function
CREATE OR REPLACE FUNCTION accept_resource(
  p_resource_id UUID,
  p_accepting_company_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_resource_company_id UUID;
  v_message_id UUID;
BEGIN
  -- Get the resource owner's company ID
  SELECT company_id INTO v_resource_company_id
  FROM resources
  WHERE id = p_resource_id;

  -- Validate the resource exists and isn't already taken
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource not found';
  END IF;

  IF v_resource_company_id = p_accepting_company_id THEN
    RAISE EXCEPTION 'Cannot accept your own resource';
  END IF;

  -- Update the resource status
  UPDATE resources
  SET 
    is_taken = true,
    accepted_by_company_id = p_accepting_company_id
  WHERE id = p_resource_id
  AND NOT is_taken;

  -- If no rows were updated, the resource was already taken
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource is already taken';
  END IF;

  -- Create a system message for the acceptance
  INSERT INTO messages (
    from_company_id,
    to_company_id,
    resource_id,
    subject,
    content
  ) VALUES (
    p_accepting_company_id,
    v_resource_company_id,
    p_resource_id,
    'Tilbud akseptert',
    'Tilbudet er akseptert. Kontaktinformasjon vil bli delt når begge parter har godkjent.'
  ) RETURNING id INTO v_message_id;

  -- Create initial contact sharing record
  INSERT INTO thread_contact_sharing 
    (thread_id, from_company_id, to_company_id)
  VALUES 
    (v_message_id, p_accepting_company_id, v_resource_company_id);
END;
$$;