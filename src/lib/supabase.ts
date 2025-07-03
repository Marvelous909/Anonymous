import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/database';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  realtime: {
    params: {
      eventsPerSecond: 10
    }
  }
});

export const getCompanyForUser = async (userId: string) => {
  const { data, error } = await supabase
    .from('companies')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw error;
  return data;
};

export const getCompanyById = async (companyId: string) => {
  const { data, error } = await supabase
    .from('companies')
    .select('id, name, anonymous_id')
    .eq('id', companyId)
    .maybeSingle();

  if (error) throw error;
  return data;
};

export const acceptResource = async (resourceId: string, acceptingCompanyId: string) => {
  const { error } = await supabase
    .rpc('accept_resource', {
      p_resource_id: resourceId,
      p_accepting_company_id: acceptingCompanyId
    });

  if (error) throw error;
};