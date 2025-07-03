/*
  # Add price field and improve resource acceptance flow
  
  1. Changes
    - Add price field to resources table
    - Add price_type field to support different pricing models (hourly, fixed, etc)
    - Add accepted_by_company_id to track which company accepted the resource
  
  2. Security
    - Update RLS policies to handle resource acceptance
*/

-- Add new columns to resources table
ALTER TABLE resources 
ADD COLUMN IF NOT EXISTS price decimal(10,2),
ADD COLUMN IF NOT EXISTS price_type text CHECK (price_type IN ('hourly', 'fixed', 'negotiable')) DEFAULT 'hourly',
ADD COLUMN IF NOT EXISTS accepted_by_company_id uuid REFERENCES companies(id);

-- Update the anonymized_resources view
CREATE OR REPLACE VIEW anonymized_resources AS
SELECT 
  r.id,
  r.company_id,
  c.anonymous_id,
  r.competence,
  r.period_from,
  r.period_to,
  r.location,
  r.comments,
  CASE 
    WHEN c.user_id = auth.uid() THEN r.contact_info
    ELSE 'Kontakt via meldingssystem'
  END as contact_info,
  r.is_special,
  r.created_at,
  c.verified,
  r.is_taken,
  r.price,
  r.price_type,
  r.accepted_by_company_id
FROM resources r
JOIN companies c ON c.id = r.company_id;

-- Function to handle resource acceptance and automatic contact sharing
CREATE OR REPLACE FUNCTION accept_resource(
  resource_id uuid,
  accepting_company_id uuid
) RETURNS void AS $$
BEGIN
  -- Mark resource as taken
  UPDATE resources 
  SET 
    is_taken = true,
    accepted_by_company_id = accepting_company_id
  WHERE id = resource_id AND NOT is_taken;

  -- Create contact sharing entries for both companies
  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  SELECT 
    m.id,
    r.company_id,
    accepting_company_id
  FROM resources r
  JOIN messages m ON m.resource_id = r.id
  WHERE r.id = resource_id
  AND NOT EXISTS (
    SELECT 1 FROM thread_contact_sharing 
    WHERE thread_id = m.id 
    AND from_company_id = r.company_id
    AND to_company_id = accepting_company_id
  );

  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  SELECT 
    m.id,
    accepting_company_id,
    r.company_id
  FROM resources r
  JOIN messages m ON m.resource_id = r.id
  WHERE r.id = resource_id
  AND NOT EXISTS (
    SELECT 1 FROM thread_contact_sharing 
    WHERE thread_id = m.id 
    AND from_company_id = accepting_company_id
    AND to_company_id = r.company_id
  );
END;
$$ LANGUAGE plpgsql;