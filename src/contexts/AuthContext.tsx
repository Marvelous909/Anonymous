import React, { createContext, useContext, useEffect, useState } from 'react';
import { User } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

interface CompanyInfo {
  companyName: string;
  companyEmail: string;
  companyPhone: string;
  companyAddress: string;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, companyInfo: CompanyInfo) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  const signUp = async (email: string, password: string, companyInfo: CompanyInfo) => {
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/login`
      }
    });

    if (authError) throw authError;
    if (!authData.user) throw new Error('No user data returned');

    const verificationCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    // Check if company already exists for this user
    const { data: existingCompany } = await supabase
      .from('companies')
      .select('id')
      .eq('user_id', authData.user.id)
      .maybeSingle();

    if (existingCompany) {
      throw new Error('A company is already registered for this user');
    }

    const { error: companyError } = await supabase
      .from('companies')
      .insert({
        name: companyInfo.companyName,
        anonymous_id: `bedrift_${Math.random().toString(36).slice(2, 7)}`,
        user_id: authData.user.id,
        verification_code: verificationCode,
        real_contact_info: {
          company_name: companyInfo.companyName,
          email: companyInfo.companyEmail,
          phone: companyInfo.companyPhone,
          address: companyInfo.companyAddress
        }
      });

    if (companyError) {
      await supabase.auth.admin.deleteUser(authData.user.id);
      throw companyError;
    }

    // Send verification email using Edge Function
    const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-verification`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`
      },
      body: JSON.stringify({
        email: companyInfo.companyEmail,
        code: verificationCode,
        companyName: companyInfo.companyName
      })
    });

    if (!response.ok) {
      throw new Error('Failed to send verification email');
    }
  };

  const signIn = async (email: string, password: string) => {
    console.log(email, password)
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    console.log("error===>", error)
    if (error) throw error;
  };

  const signOut = async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  };

  return (
    <AuthContext.Provider value={{ user, loading, signIn, signUp, signOut }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};