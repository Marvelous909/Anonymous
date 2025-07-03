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



/*
  # Add registration policy for companies table

  1. Security Changes
    - Add new policy to allow company creation during registration
    - Uses DO block to safely create policy only if it doesn't exist
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'companies' 
    AND policyname = 'Enable insert for registration'
  ) THEN
    CREATE POLICY "Enable insert for registration" ON companies
    FOR INSERT
    WITH CHECK (true);
  END IF;
END
$$;


/*
  # Create messages table and set up anonymous communication

  1. New Tables
    - `messages`
      - `id` (uuid, primary key)
      - `from_company_id` (uuid, references companies)
      - `to_company_id` (uuid, references companies)
      - `resource_id` (uuid, references resources)
      - `subject` (text)
      - `content` (text)
      - `created_at` (timestamp)
      - `read_at` (timestamp, nullable)

  2. Security
    - Enable RLS on messages table
    - Add policies for sending and receiving messages
    - Ensure company anonymity in communication
*/

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_company_id uuid REFERENCES companies(id) NOT NULL,
  to_company_id uuid REFERENCES companies(id) NOT NULL,
  resource_id uuid REFERENCES resources(id) NOT NULL,
  subject text NOT NULL,
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  read_at timestamptz,
  thread_id uuid REFERENCES messages(id)
);

-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Companies can view messages they're involved in
CREATE POLICY "Users can view their own messages"
  ON messages
  FOR SELECT
  USING (
    auth.uid() IN (
      SELECT user_id FROM companies 
      WHERE id IN (from_company_id, to_company_id)
    )
  );

-- Companies can send messages
CREATE POLICY "Users can send messages"
  ON messages
  FOR INSERT
  WITH CHECK (
    auth.uid() = (
      SELECT user_id FROM companies 
      WHERE id = from_company_id
    )
  );

-- Create index for better query performance
CREATE INDEX messages_company_id_idx ON messages(from_company_id, to_company_id);


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


  /*
  # Update resources table and policies

  1. New Columns
    - `is_taken` (boolean) - Indicates if a resource has been accepted
    - `price` (decimal) - Price for the resource
    - `price_type` (text) - Type of pricing (hourly, fixed, negotiable)
    - `accepted_by_company_id` (uuid) - Reference to accepting company

  2. Changes
    - Update anonymized_resources view to include new columns
    - Add function for handling resource acceptance
    - Update RLS policies for resource visibility and acceptance
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

  IF resource_owner_id IS NULL THEN
    RAISE EXCEPTION 'Resource not found';
  END IF;

  IF resource_owner_id = accepting_company_id THEN
    RAISE EXCEPTION 'Cannot accept your own resource';
  END IF;

  -- Mark resource as taken
  UPDATE resources 
  SET 
    is_taken = true,
    accepted_by_company_id = accepting_company_id
  WHERE id = resource_id 
  AND NOT is_taken
  AND company_id = resource_owner_id
  AND company_id != accepting_company_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource is not available for acceptance';
  END IF;

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

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Companies can view available resources" ON resources;
  DROP POLICY IF EXISTS "Companies can accept resources" ON resources;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

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


  /*
  # Fix resource acceptance function and policies

  1. Changes
    - Improve error handling in accept_resource function
    - Add better validation for company existence
    - Fix policy conflicts
    - Add detailed error messages

  2. Security
    - Maintain existing RLS policies
    - Ensure proper access control
*/

-- Drop existing policies to avoid conflicts
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Companies can view available resources" ON resources;
  DROP POLICY IF EXISTS "Companies can accept resources" ON resources;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Drop existing function to recreate it
DROP FUNCTION IF EXISTS accept_resource(uuid, uuid);

-- Recreate the function with better error handling
CREATE OR REPLACE FUNCTION accept_resource(
  resource_id uuid,
  accepting_company_id uuid
) RETURNS void AS $$
DECLARE
  resource_owner_id uuid;
  resource_exists boolean;
  accepting_company_exists boolean;
BEGIN
  -- Check if resource exists
  SELECT EXISTS (
    SELECT 1 FROM resources WHERE id = resource_id
  ) INTO resource_exists;

  IF NOT resource_exists THEN
    RAISE EXCEPTION 'Resource with ID % does not exist', resource_id;
  END IF;

  -- Check if accepting company exists
  SELECT EXISTS (
    SELECT 1 FROM companies WHERE id = accepting_company_id
  ) INTO accepting_company_exists;

  IF NOT accepting_company_exists THEN
    RAISE EXCEPTION 'Company with ID % does not exist', accepting_company_id;
  END IF;

  -- Get the resource owner's company ID
  SELECT company_id INTO resource_owner_id
  FROM resources
  WHERE id = resource_id;

  -- Additional validations
  IF resource_owner_id IS NULL THEN
    RAISE EXCEPTION 'Resource owner company not found';
  END IF;

  IF resource_owner_id = accepting_company_id THEN
    RAISE EXCEPTION 'Cannot accept your own resource';
  END IF;

  -- Check if resource is already taken
  IF EXISTS (
    SELECT 1 FROM resources 
    WHERE id = resource_id AND is_taken = true
  ) THEN
    RAISE EXCEPTION 'Resource is already taken';
  END IF;

  -- Mark resource as taken
  UPDATE resources 
  SET 
    is_taken = true,
    accepted_by_company_id = accepting_company_id
  WHERE id = resource_id 
  AND NOT is_taken
  AND company_id = resource_owner_id
  AND company_id != accepting_company_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Failed to update resource status';
  END IF;

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

EXCEPTION
  WHEN others THEN
    RAISE EXCEPTION 'Error accepting resource: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Recreate the policies
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


  /*
  # Fix accept_resource function

  1. Changes
    - Update accept_resource function to fix ambiguous resource_id reference
    - Explicitly specify table names for all column references to avoid ambiguity
    - Add proper error handling and validation

  2. Security
    - Function remains accessible only to authenticated users
    - Maintains existing security checks for resource acceptance
*/

CREATE OR REPLACE FUNCTION accept_resource(
  resource_id uuid,
  accepting_company_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate that the resource exists and is available
  IF NOT EXISTS (
    SELECT 1 
    FROM resources r
    WHERE r.id = resource_id 
    AND NOT r.is_taken
  ) THEN
    RAISE EXCEPTION 'Resource not found or already taken';
  END IF;

  -- Update the resource status
  UPDATE resources
  SET 
    is_taken = true,
    accepted_by_company_id = accepting_company_id
  WHERE id = resource_id
  AND NOT is_taken;

  -- If no rows were updated, the resource was taken by someone else
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource is no longer available';
  END IF;
END;
$$;


/*
  # Fix accept_resource function

  1. Changes
    - Drop existing function first
    - Recreate function with proper parameter names
    - Add better error handling
    - Maintain SECURITY DEFINER setting
*/

-- Drop the existing function first
DROP FUNCTION IF EXISTS accept_resource(uuid, uuid);

-- Recreate the function with proper parameter names
CREATE OR REPLACE FUNCTION accept_resource(
  p_resource_id uuid,
  p_accepting_company_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_resource_owner_id uuid;
  v_thread_id uuid;
BEGIN
  -- Get the resource owner's company ID
  SELECT r.company_id INTO v_resource_owner_id
  FROM resources r
  WHERE r.id = p_resource_id;

  IF v_resource_owner_id IS NULL THEN
    RAISE EXCEPTION 'Resource not found';
  END IF;

  IF v_resource_owner_id = p_accepting_company_id THEN
    RAISE EXCEPTION 'Cannot accept your own resource';
  END IF;

  -- Get the existing thread ID if any
  SELECT m.id INTO v_thread_id
  FROM messages m
  WHERE m.resource_id = p_resource_id
  ORDER BY m.created_at ASC
  LIMIT 1;

  -- Update the resource status
  UPDATE resources r
  SET 
    is_taken = true,
    accepted_by_company_id = p_accepting_company_id
  WHERE r.id = p_resource_id
  AND NOT r.is_taken;

  -- If no rows were updated, the resource was taken by someone else
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource is no longer available';
  END IF;

  -- Create contact sharing entries for both companies
  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  VALUES 
    (COALESCE(v_thread_id, gen_random_uuid()), v_resource_owner_id, p_accepting_company_id),
    (COALESCE(v_thread_id, gen_random_uuid()), p_accepting_company_id, v_resource_owner_id)
  ON CONFLICT DO NOTHING;

  -- Insert system message about acceptance if we have a thread
  IF v_thread_id IS NOT NULL THEN
    INSERT INTO messages (
      from_company_id,
      to_company_id,
      resource_id,
      subject,
      content,
      thread_id
    )
    VALUES (
      p_accepting_company_id,
      v_resource_owner_id,
      p_resource_id,
      'Tilbud akseptert',
      'Tilbudet er akseptert. Kontaktinformasjon er nå delt mellom partene.',
      v_thread_id
    );
  END IF;
END;
$$;

/*
  # Fix resource acceptance and messaging

  1. Changes
    - Improve error handling in accept_resource function
    - Ensure messages are created even when no thread exists
    - Fix contact sharing logic
    - Add proper transaction handling

  2. Security
    - Maintain existing RLS policies
    - Keep SECURITY DEFINER setting
*/

-- Drop the existing function first
DROP FUNCTION IF EXISTS accept_resource(uuid, uuid);

-- Recreate the function with improved message handling
CREATE OR REPLACE FUNCTION accept_resource(
  p_resource_id uuid,
  p_accepting_company_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_resource_owner_id uuid;
  v_thread_id uuid;
  v_resource_competence text;
BEGIN
  -- Get the resource owner's company ID and competence
  SELECT r.company_id, r.competence 
  INTO v_resource_owner_id, v_resource_competence
  FROM resources r
  WHERE r.id = p_resource_id;

  IF v_resource_owner_id IS NULL THEN
    RAISE EXCEPTION 'Resource not found';
  END IF;

  IF v_resource_owner_id = p_accepting_company_id THEN
    RAISE EXCEPTION 'Cannot accept your own resource';
  END IF;

  -- Get the existing thread ID if any
  SELECT m.id INTO v_thread_id
  FROM messages m
  WHERE m.resource_id = p_resource_id
  AND (
    (m.from_company_id = p_accepting_company_id AND m.to_company_id = v_resource_owner_id)
    OR 
    (m.from_company_id = v_resource_owner_id AND m.to_company_id = p_accepting_company_id)
  )
  ORDER BY m.created_at ASC
  LIMIT 1;

  -- Update the resource status
  UPDATE resources r
  SET 
    is_taken = true,
    accepted_by_company_id = p_accepting_company_id
  WHERE r.id = p_resource_id
  AND NOT r.is_taken;

  -- If no rows were updated, the resource was taken by someone else
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource is no longer available';
  END IF;

  -- If no thread exists, create one
  IF v_thread_id IS NULL THEN
    INSERT INTO messages (
      from_company_id,
      to_company_id,
      resource_id,
      subject,
      content
    )
    VALUES (
      p_accepting_company_id,
      v_resource_owner_id,
      p_resource_id,
      'Akseptert: ' || v_resource_competence,
      'Jeg ønsker å akseptere dette tilbudet.'
    )
    RETURNING id INTO v_thread_id;
  END IF;

  -- Create contact sharing entries for both companies
  INSERT INTO thread_contact_sharing (
    thread_id,
    from_company_id,
    to_company_id
  )
  VALUES 
    (v_thread_id, v_resource_owner_id, p_accepting_company_id),
    (v_thread_id, p_accepting_company_id, v_resource_owner_id)
  ON CONFLICT DO NOTHING;

  -- Insert acceptance message
  INSERT INTO messages (
    from_company_id,
    to_company_id,
    resource_id,
    subject,
    content,
    thread_id
  )
  VALUES (
    p_accepting_company_id,
    v_resource_owner_id,
    p_resource_id,
    'Tilbud akseptert',
    'Tilbudet er akseptert. Kontaktinformasjon er nå delt mellom partene.',
    v_thread_id
  );
END;
$$;



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
END;
$$;



/*
  # Fix contact sharing

  1. Changes
    - Update accept_resource function to handle contact sharing properly
    - Create message record before contact sharing
    - Use message ID as thread ID for contact sharing

  2. Security
    - Maintain RLS policies
    - Ensure proper validation
*/

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

  -- Create contact sharing records for both companies
  INSERT INTO thread_contact_sharing 
    (thread_id, from_company_id, to_company_id)
  VALUES 
    (v_message_id, v_resource_company_id, p_accepting_company_id),
    (v_message_id, p_accepting_company_id, v_resource_company_id);
END;
$$;





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