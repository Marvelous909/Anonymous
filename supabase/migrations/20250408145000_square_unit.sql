/*
  # Initial Schema Setup

  1. New Tables
    - `companies`
      - `id` (uuid, primary key)
      - `name` (text, company name)
      - `anonymous_id` (text, public identifier)
      - `created_at` (timestamp)
    
    - `resources`
      - `id` (uuid, primary key)
      - `company_id` (uuid, references companies)
      - `competence` (text)
      - `period_from` (timestamp)
      - `period_to` (timestamp)
      - `location` (text)
      - `comments` (text)
      - `contact_info` (text)
      - `created_at` (timestamp)
      - `is_special` (boolean)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create companies table
CREATE TABLE companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  anonymous_id text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  user_id uuid REFERENCES auth.users(id)
);

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Companies policies
CREATE POLICY "Users can view their own company"
  ON companies
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own company"
  ON companies
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Create resources table
CREATE TABLE resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid REFERENCES companies(id),
  competence text NOT NULL,
  period_from timestamptz NOT NULL,
  period_to timestamptz NOT NULL,
  location text NOT NULL,
  comments text,
  contact_info text NOT NULL,
  created_at timestamptz DEFAULT now(),
  is_special boolean DEFAULT false
);

ALTER TABLE resources ENABLE ROW LEVEL SECURITY;

-- Resources policies
CREATE POLICY "Companies can view all resources"
  ON resources
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Companies can insert their own resources"
  ON resources
  FOR INSERT
  TO authenticated
  WITH CHECK (company_id IN (
    SELECT id FROM companies WHERE user_id = auth.uid()
  ));

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

-- Create view for anonymized resources
CREATE VIEW public.anonymized_resources AS
SELECT 
  r.id,
  c.anonymous_id,
  r.competence,
  r.period_from,
  r.period_to,
  r.location,
  r.comments,
  CASE 
    WHEN c.user_id = auth.uid() THEN r.contact_info
    ELSE 'Kontakt via systemet'
  END as contact_info,
  r.is_special
FROM resources r
JOIN companies c ON r.company_id = c.id;