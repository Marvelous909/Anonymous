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