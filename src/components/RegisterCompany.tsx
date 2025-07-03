import React, { useState } from 'react';
import { CircuitBoard } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface RegisterCompanyProps {
  onRegistered: () => void;
}

export const RegisterCompany: React.FC<RegisterCompanyProps> = ({ onRegistered }) => {
  const { user } = useAuth();
  const [companyName, setCompanyName] = useState('');
  const [companyEmail, setCompanyEmail] = useState('');
  const [companyPhone, setCompanyPhone] = useState('');
  const [companyAddress, setCompanyAddress] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    try {
      setLoading(true);
      setError('');

      const verificationCode = Math.random().toString(36).substring(2, 8).toUpperCase();

      const { error: companyError } = await supabase
        .from('companies')
        .insert({
          name: companyName,
          anonymous_id: `bedrift_${Math.random().toString(36).slice(2, 7)}`,
          user_id: user.id,
          verification_code: verificationCode,
          real_contact_info: {
            company_name: companyName,
            email: companyEmail,
            phone: companyPhone,
            address: companyAddress
          }
        });

      if (companyError) throw companyError;

      // Send verification email
      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-verification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`
        },
        body: JSON.stringify({
          email: companyEmail,
          code: verificationCode,
          companyName: companyName
        })
      });

      if (!response.ok) {
        throw new Error('Failed to send verification email');
      }

      onRegistered();
    } catch (err) {
      console.error('Error registering company:', err);
      setError('Kunne ikke registrere bedrift. Vennligst prøv igjen senere.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white p-6 rounded border-2 border-elfag-dark shadow-industrial">
      <div className="flex items-center gap-3 mb-6">
        <CircuitBoard className="w-8 h-8 text-elfag-dark" />
        <h2 className="text-2xl font-bold">Registrer bedrift</h2>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {error && (
          <div className="bg-red-50 border border-red-400 text-red-700 px-4 py-3 rounded">
            {error}
          </div>
        )}

        <div>
          <label htmlFor="companyName" className="block text-sm font-medium text-gray-700">
            Bedriftsnavn
          </label>
          <input
            id="companyName"
            type="text"
            required
            value={companyName}
            onChange={(e) => setCompanyName(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-elfag-light focus:ring focus:ring-elfag-light focus:ring-opacity-50"
          />
        </div>

        <div>
          <label htmlFor="companyEmail" className="block text-sm font-medium text-gray-700">
            Bedriftens e-post
          </label>
          <input
            id="companyEmail"
            type="email"
            required
            value={companyEmail}
            onChange={(e) => setCompanyEmail(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-elfag-light focus:ring focus:ring-elfag-light focus:ring-opacity-50"
          />
        </div>

        <div>
          <label htmlFor="companyPhone" className="block text-sm font-medium text-gray-700">
            Bedriftens telefon
          </label>
          <input
            id="companyPhone"
            type="tel"
            required
            value={companyPhone}
            onChange={(e) => setCompanyPhone(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-elfag-light focus:ring focus:ring-elfag-light focus:ring-opacity-50"
          />
        </div>

        <div>
          <label htmlFor="companyAddress" className="block text-sm font-medium text-gray-700">
            Bedriftens adresse
          </label>
          <input
            id="companyAddress"
            type="text"
            required
            value={companyAddress}
            onChange={(e) => setCompanyAddress(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-elfag-light focus:ring focus:ring-elfag-light focus:ring-opacity-50"
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-elfag-dark hover:bg-opacity-90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-elfag-light disabled:opacity-50"
        >
          {loading ? 'Registrerer...' : 'Registrer bedrift'}
        </button>
      </form>
    </div>
  );
};