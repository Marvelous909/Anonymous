/*
  # Add resource taken status

  1. Changes
    - Add is_taken column to resources table
    - Update anonymized_resources view to include is_taken status

  2. Security
    - Maintain existing RLS policies
*/

-- Add is_taken column to resources table
ALTER TABLE resources 
ADD COLUMN IF NOT EXISTS is_taken boolean DEFAULT false;

-- Update anonymized_resources view to include is_taken status
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
  r.is_taken
FROM resources r
JOIN companies c ON c.id = r.company_id;