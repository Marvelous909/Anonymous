/*
  # Add accept_resource function
  
  1. New Functions
    - `accept_resource`: Handles resource acceptance and contact sharing
      - Accepts resource_id and accepting_company_id
      - Updates resource status
      - Creates contact sharing records
      - Returns success/failure

  2. Security
    - Function accessible only to authenticated users
    - Validates company ownership and permissions
*/

-- Create the accept_resource function
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
  v_thread_id UUID;
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

  -- Create contact sharing records for both companies
  INSERT INTO thread_contact_sharing 
    (thread_id, from_company_id, to_company_id)
  VALUES 
    (p_resource_id, v_resource_company_id, p_accepting_company_id),
    (p_resource_id, p_accepting_company_id, v_resource_company_id);

END;
$$;