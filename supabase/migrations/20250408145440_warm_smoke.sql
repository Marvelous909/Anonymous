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