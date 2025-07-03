/*
  # Add resource handling and contact sharing improvements

  1. New Columns
    - Add `is_taken` to resources table
    - Add `price` and `price_type` to resources table
    - Add `accepted_by_company_id` to resources table

  2. Functions
    - Create function to handle resource acceptance
    - Automatically share contact info when resource is accepted

  3. Security
    - Update RLS policies for new columns
    - Add policies for resource acceptance
*/

-- Add new columns to resources table if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'resources' AND column_name = 'is_taken'
  ) THEN
    ALTER TABLE resources ADD COLUMN is_taken boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'resources' AND column_name = 'price'
  ) THEN
    ALTER TABLE resources ADD COLUMN price decimal(10,2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'resources' AND column_name = 'price_type'
  ) THEN
    ALTER TABLE resources ADD COLUMN price_type text CHECK (price_type IN ('hourly', 'fixed', 'negotiable')) DEFAULT 'hourly';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'resources' AND column_name = 'accepted_by_company_id'
  ) THEN
    ALTER TABLE resources ADD COLUMN accepted_by_company_id uuid REFERENCES companies(id);
  END IF;
END $$;

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

-- Function to handle resource acceptance
CREATE OR REPLACE FUNCTION accept_resource(
  resource_id uuid,
  accepting_company_id uuid
) RETURNS void AS $$
DECLARE
  resource_owner_id uuid;
BEGIN
  -- Get the resource owner's company ID
  SELECT company_id INTO resource_owner_id
  FROM resources
  WHERE id = resource_id;

  -- Mark resource as taken
  UPDATE resources 
  SET 
    is_taken = true,
    accepted_by_company_id = accepting_company_id
  WHERE id = resource_id 
  AND NOT is_taken
  AND company_id != accepting_company_id;

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
END;
$$ LANGUAGE plpgsql;

-- Update RLS policies
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;

-- Companies can view all resources that aren't taken
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

-- Companies can accept resources
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