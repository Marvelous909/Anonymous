import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.39.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email, code, companyName } = await req.json();

    // Initialize Supabase client with service role
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    );

    // Send verification email using your email service
    // This is a placeholder - you'll need to implement actual email sending
    // using a service like SendGrid, AWS SES, etc.
    const emailContent = `
      Hei ${companyName}!

      Takk for at du registrerte deg på Elfag Ressursdeling.
      Din verifiseringskode er: ${code}

      Vennlig hilsen,
      Elfag Ressursdeling
    `;

    console.log('Would send email:', {
      to: email,
      subject: 'Verifiser din bedrift - Elfag Ressursdeling',
      content: emailContent
    });

    return new Response(
      JSON.stringify({ message: 'Verification email sent' }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    );
  }
});