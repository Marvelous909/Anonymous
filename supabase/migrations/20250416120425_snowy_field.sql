-- Drop the is_contact_shared function as it's not needed
DROP FUNCTION IF EXISTS is_contact_shared;

-- Update the accept_resource function to handle contact sharing correctly
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

  -- Get the first message in the thread for this resource
  SELECT id INTO v_message_id
  FROM messages
  WHERE resource_id = p_resource_id
  ORDER BY created_at ASC
  LIMIT 1;

  -- Create contact sharing records for both companies using the first message as thread_id
  INSERT INTO thread_contact_sharing 
    (thread_id, from_company_id, to_company_id)
  VALUES 
    (v_message_id, v_resource_company_id, p_accepting_company_id),
    (v_message_id, p_accepting_company_id, v_resource_company_id)
  ON CONFLICT (thread_id, from_company_id, to_company_id) DO NOTHING;
END;
$$;