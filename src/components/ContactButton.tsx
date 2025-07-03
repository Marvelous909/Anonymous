import React, { useState } from 'react';
import { MessageSquare, X, Check } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { Resource } from '../types';

interface ContactButtonProps {
  resource: Resource;
  onMessageSent?: () => void;
}

export const ContactButton: React.FC<ContactButtonProps> = ({ resource, onMessageSent }) => {
  const { user } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [sent, setSent] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!message.trim() || !user || !resource.company_id) return;

    try {
      setSending(true);
      setError('');

      // Get the user's company
      const { data: fromCompany, error: fromCompanyError } = await supabase
        .from('companies')
        .select('id')
        .eq('user_id', user.id)
        .single();

      if (fromCompanyError) {
        console.error('Error fetching sender company:', fromCompanyError);
        throw new Error('Kunne ikke finne din bedrift. Vennligst kontakt support.');
      }

      // Prevent sending message to own company
      if (fromCompany.id === resource.company_id) {
        throw new Error('Du kan ikke sende melding til din egen bedrift');
      }

      // Create initial message
      const { data: messageData, error: messageError } = await supabase
        .from('messages')
        .insert({
          from_company_id: fromCompany.id,
          to_company_id: resource.company_id,
          resource_id: resource.id,
          subject: resource.price 
            ? `Aksepterer tilbud: ${resource.competence}`
            : `Forespørsel: ${resource.competence}`,
          content: message.trim()
        })
        .select()
        .single();

      if (messageError) {
        console.error('Error creating message:', messageError);
        throw messageError;
      }

      // If this is an offer acceptance, handle the resource acceptance
      if (resource.price) {
        try {
          await supabase.rpc('accept_resource', {
            p_resource_id: resource.id,
            p_accepting_company_id: fromCompany.id
          });
        } catch (acceptError) {
          console.error('Error accepting resource:', acceptError);
          throw new Error('Kunne ikke akseptere tilbudet. Vennligst prøv igjen senere.');
        }
      }

      setSent(true);
      setMessage('');
      if (onMessageSent) {
        onMessageSent();
      }
      setTimeout(() => {
        setIsOpen(false);
        setSent(false);
      }, 2000);
    } catch (err) {
      console.error('Error sending message:', err);
      setError(err instanceof Error ? err.message : 'Kunne ikke sende melding. Prøv igjen senere.');
    } finally {
      setSending(false);
    }
  };

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        className="flex items-center gap-2 text-sm text-elfag-dark hover:text-opacity-80"
      >
        {resource.price ? (
          <Check className="w-4 h-4" />
        ) : (
          <MessageSquare className="w-4 h-4" />
        )}
        {resource.price ? 'Aksepter tilbud' : 'Kontakt'}
      </button>

      {isOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg max-w-lg w-full">
            <div className="p-4 border-b border-gray-200 flex justify-between items-center">
              <h3 className="text-lg font-semibold">
                {resource.price ? 'Aksepter tilbud' : 'Send melding'}: {resource.competence}
              </h3>
              <button
                onClick={() => setIsOpen(false)}
                className="text-gray-500 hover:text-gray-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-4">
              {error && (
                <div className="mb-4 bg-red-50 border border-red-400 text-red-700 px-4 py-3 rounded">
                  {error}
                </div>
              )}

              {sent ? (
                <div className="bg-green-50 border border-green-400 text-green-700 px-4 py-3 rounded">
                  {resource.price ? 'Tilbud akseptert!' : 'Melding sendt!'} Lukker...
                </div>
              ) : (
                <>
                  {resource.price && (
                    <div className="mb-4 bg-elfag-light bg-opacity-20 p-4 rounded">
                      <h4 className="font-semibold mb-2">Tilbudsinformasjon:</h4>
                      <p>Pris: {resource.price} kr{resource.priceType === 'hourly' ? '/time' : ''}</p>
                      <p className="mt-2 text-sm text-gray-600">
                        Ved å akseptere dette tilbudet vil kontaktinformasjon automatisk deles mellom partene.
                      </p>
                    </div>
                  )}

                  <div className="mb-4">
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      {resource.price ? 'Melding til tilbyder' : 'Din melding'}
                    </label>
                    <textarea
                      value={message}
                      onChange={(e) => setMessage(e.target.value)}
                      rows={4}
                      className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                      placeholder={resource.price ? 'Skriv en melding om når du ønsker å starte...' : 'Skriv din melding her...'}
                      required
                    />
                  </div>

                  <div className="flex justify-end gap-3">
                    <button
                      type="button"
                      onClick={() => setIsOpen(false)}
                      className="px-4 py-2 border border-gray-300 rounded text-gray-700 hover:bg-gray-50"
                    >
                      Avbryt
                    </button>
                    <button
                      type="submit"
                      disabled={sending || !message.trim()}
                      className="px-4 py-2 bg-elfag-dark text-white rounded hover:bg-opacity-90 disabled:opacity-50"
                    >
                      {sending ? 'Sender...' : resource.price ? 'Aksepter tilbud' : 'Send melding'}
                    </button>
                  </div>
                </>
              )}
            </form>
          </div>
        </div>
      )}
    </>
  );
};