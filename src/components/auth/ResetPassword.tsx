import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { CircuitBoard } from 'lucide-react';
import { supabase } from '../../lib/supabase';

export const ResetPassword: React.FC = () => {
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setLoading(true);
      setMessage(null);

      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/update-password`,
      });

      if (error) throw error;

      setMessage({
        type: 'success',
        text: 'Tilbakestillingslenke er sendt til din e-post. Sjekk innboksen din.'
      });
    } catch (error) {
      console.error('Reset password error:', error);
      setMessage({
        type: 'error',
        text: 'Kunne ikke sende tilbakestillingslenke. Prøv igjen senere.'
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="flex justify-center">
          <CircuitBoard className="w-12 h-12 text-elfag-dark" />
        </div>
        <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
          Tilbakestill passord
        </h2>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-4 shadow-industrial sm:rounded-lg sm:px-10">
          <form className="space-y-6" onSubmit={handleSubmit}>
            {message && (
              <div className={`p-4 rounded ${
                message.type === 'success' 
                  ? 'bg-green-50 border border-green-400 text-green-700'
                  : 'bg-red-50 border border-red-400 text-red-700'
              }`}>
                {message.text}
              </div>
            )}
            
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                E-postadresse
              </label>
              <div className="mt-1">
                <input
                  id="email"
                  name="email"
                  type="email"
                  autoComplete="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-elfag-light focus:border-elfag-light"
                />
              </div>
            </div>

            <div>
              <button
                type="submit"
                disabled={loading}
                className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-elfag-dark hover:bg-opacity-90 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-elfag-light disabled:opacity-50"
              >
                {loading ? 'Sender...' : 'Send tilbakestillingslenke'}
              </button>
            </div>

            <div className="text-center">
              <Link
                to="/login"
                className="text-sm text-elfag-dark hover:text-opacity-80"
              >
                Tilbake til innlogging
              </Link>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};