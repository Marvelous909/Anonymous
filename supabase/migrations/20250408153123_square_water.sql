/*
  # Add company verification and contact sharing features
  
  1. New Columns
    - Add verification status to companies table
    - Add contact sharing preferences
    - Add real contact information
  
  2. Security
    - Update RLS policies for new columns
*/

-- Add new columns to companies table
ALTER TABLE companies 
ADD COLUMN IF NOT EXISTS verified boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS verification_code text,
ADD COLUMN IF NOT EXISTS verification_sent_at timestamptz,
ADD COLUMN IF NOT EXISTS real_contact_info jsonb DEFAULT jsonb_build_object(
  'company_name', '',
  'email', '',
  'phone', '',
  'address', ''
);

-- Add contact sharing table for threads
CREATE TABLE IF NOT EXISTS thread_contact_sharing (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid REFERENCES messages(id) NOT NULL,
  from_company_id uuid REFERENCES companies(id) NOT NULL,
  to_company_id uuid REFERENCES companies(id) NOT NULL,
  shared_at timestamptz DEFAULT now(),
  UNIQUE(thread_id, from_company_id, to_company_id)
);

-- Enable RLS
ALTER TABLE thread_contact_sharing ENABLE ROW LEVEL SECURITY;

-- Companies can view contact sharing for their threads
CREATE POLICY "Companies can view their contact sharing"
  ON thread_contact_sharing
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM companies
      WHERE user_id = auth.uid()
      AND id IN (from_company_id, to_company_id)
    )
  );

-- Companies can create contact sharing
CREATE POLICY "Companies can create contact sharing"
  ON thread_contact_sharing
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM companies
      WHERE user_id = auth.uid()
      AND id = from_company_id
    )
  );

-- Update the anonymized_resources view to include verification status
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
  c.verified
FROM resources r
JOIN companies c ON c.id = r.company_id;