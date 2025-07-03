/*
  # Update schema for resource sharing and messaging

  1. Changes
    - Drop and recreate anonymized_resources view
    - Update RLS policies for resources table
    - Add RLS policies for messages table

  2. Security
    - Enable RLS on resources table
    - Add policies for viewing and modifying resources
    - Add policies for viewing and sending messages
*/

-- Drop existing view if it exists to avoid conflicts
DROP VIEW IF EXISTS anonymized_resources;

-- Create the anonymized resources view with correct column names
CREATE VIEW anonymized_resources AS
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
  r.created_at
FROM resources r
JOIN companies c ON c.id = r.company_id;

-- Update RLS on resources table
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Companies can view all resources" ON resources;
DROP POLICY IF EXISTS "Companies can update their own resources" ON resources;
DROP POLICY IF EXISTS "Companies can delete their own resources" ON resources;

-- Companies can view all resources (through the view)
CREATE POLICY "Companies can view all resources"
  ON resources
  FOR SELECT
  TO authenticated
  USING (true);

-- Companies can only modify their own resources
CREATE POLICY "Companies can update their own resources"
  ON resources
  FOR UPDATE
  TO authenticated
  USING (company_id IN (
    SELECT id FROM companies WHERE user_id = auth.uid()
  ));

CREATE POLICY "Companies can delete their own resources"
  ON resources
  FOR DELETE
  TO authenticated
  USING (company_id IN (
    SELECT id FROM companies WHERE user_id = auth.uid()
  ));

-- Grant access to the view
GRANT SELECT ON anonymized_resources TO authenticated;

-- Drop existing message policies to avoid conflicts
DROP POLICY IF EXISTS "Companies can view messages they're involved in" ON messages;
DROP POLICY IF EXISTS "Companies can send messages" ON messages;

-- Create RLS policies for messages
CREATE POLICY "Companies can view messages they're involved in"
  ON messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM companies
      WHERE user_id = auth.uid()
      AND id IN (from_company_id, to_company_id)
    )
  );

CREATE POLICY "Companies can send messages"
  ON messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM companies
      WHERE user_id = auth.uid()
      AND id = from_company_id
    )
  );