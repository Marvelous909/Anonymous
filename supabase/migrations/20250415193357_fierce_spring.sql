/*
  # Add is_taken column to resources table

  1. Changes
    - Add `is_taken` column to resources table with default value false
    - Update anonymized_resources view to include is_taken column

  2. Security
    - No changes to RLS policies needed
*/

-- Add is_taken column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'resources' AND column_name = 'is_taken'
  ) THEN
    ALTER TABLE resources ADD COLUMN is_taken boolean DEFAULT false;
  END IF;
END $$;

-- Drop and recreate the anonymized_resources view to include the new column
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
  r.contact_info,
  r.is_special,
  r.created_at,
  c.verified,
  r.is_taken
FROM resources r
JOIN companies c ON c.id = r.company_id;



