import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { CircuitBoard } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';

export const Register: React.FC = () => {
  const [email, setEmail] = useState('araayuki65@gmail.com');
  const [password, setPassword] = useState('123456789');
  const [companyName, setCompanyName] = useState('Marvelous');
  const [companyEmail, setCompanyEmail] = useState('marvelous.dev.tech9@gmail.com');
  const [companyPhone, setCompanyPhone] = useState('+6283412378830');
  const [companyAddress, setCompanyAddress] = useState('Indonisia, Jakaruta');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();
  const { signUp } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setError('');
      setLoading(true);
      await signUp(email, password, {
        companyName,
        companyEmail,
        companyPhone,
        companyAddress
      });
      navigate('/');
    } catch (err) {
      setError('Kunne ikke opprette konto. Prøv igjen senere.');
      console.error('Registration error:', err);
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
          Registrer ny bedrift
        </h2>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-4 shadow-industrial sm:rounded-lg sm:px-10">
          <form className="space-y-6" onSubmit={handleSubmit}>
            {error && (
              <div className="bg-red-50 border border-red-400 text-red-700 px-4 py-3 rounded">
                {error}
              </div>
            )}

            <div>
              <label htmlFor="companyName" className="block text-sm font-medium text-gray-700">
                Bedriftsnavn
              </label>
              <div className="mt-1">
                <input
                  id="companyName"
                  name="companyName"
                  type="text"
                  required
                  value={companyName}
                  onChange={(e) => setCompanyName(e.target.value)}
                  className="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-elfag-light focus:border-elfag-light"
                />
              </div>
            </div>

            <div>
              <label htmlFor="companyEmail" className="block text-sm font-medium text-gray-700">
                Bedriftens e-post
              </label>
              <div className="mt-1">
                <input
                  id="companyEmail"
                  name="companyEmail"
                  type="email"
                  required
                  value={companyEmail}
                  onChange={(e) => setCompanyEmail(e.target.value)}
                  className="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-elfag-light focus:border-elfag-light"
                />
              </div>
            </div>

            <div>
              <label htmlFor="companyPhone" className="block text-sm font-medium text-gray-700">
                Bedriftens telefon
              </label>
              <div className="mt-1">
                <input
                  id="companyPhone"
                  name="companyPhone"
                  type="tel"
                  required
                  value={companyPhone}
                  onChange={(e) => setCompanyPhone(e.target.value)}
                  className="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-elfag-light focus:border-elfag-light"
                />
              </div>
            </div>

            <div>
              <label htmlFor="companyAddress" className="block text-sm font-medium text-gray-700">
                Bedriftens adresse
              </label>
              <div className="mt-1">
                <input
                  id="companyAddress"
                  name="companyAddress"
                  type="text"
                  required
                  value={companyAddress}
                  onChange={(e) => setCompanyAddress(e.target.value)}
                  className="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-elfag-light focus:border-elfag-light"
                />
              </div>
            </div>
            
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                Brukers e-postadresse
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
              <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                Passord
              </label>
              <div className="mt-1">
                <input
                  id="password"
                  name="password"
                  type="password"
                  autoComplete="new-password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
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
                {loading ? 'Registrerer...' : 'Registrer'}
              </button>
            </div>
          </form>

          <div className="mt-6">
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-gray-300" />
              </div>
              <div className="relative flex justify-center text-sm">
                <span className="px-2 bg-white text-gray-500">
                  Eller
                </span>
              </div>
            </div>

            <div className="mt-6">
              <Link
                to="/login"
                className="w-full flex justify-center py-2 px-4 border border-elfag-dark rounded-md shadow-sm text-sm font-medium text-elfag-dark hover:bg-gray-50"
              >
                Logg inn med eksisterende konto
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};