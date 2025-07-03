import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { Message } from '../types';
import { Lock, Unlock } from 'lucide-react';

interface MessageThreadProps {
  message: Message;
  onReply: (content: string) => Promise<void>;
}

export const MessageThread: React.FC<MessageThreadProps> = ({ message, onReply }) => {
  const [isSharing, setIsSharing] = useState(false);
  const [contactShared, setContactShared] = useState(false);

  const handleShareContact = async () => {
    try {
      setIsSharing(true);
      const { error } = await supabase
        .from('thread_contact_sharing')
        .insert({
          thread_id: message.id,
          from_company_id: message.from_company.id,
          to_company_id: message.to_company.id
        });

      if (error) throw error;
      setContactShared(true);
    } catch (error) {
      console.error('Error sharing contact:', error);
    } finally {
      setIsSharing(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="text-xl font-semibold">{message.subject}</h3>
        {!contactShared && (
          <button
            onClick={handleShareContact}
            disabled={isSharing}
            className="flex items-center gap-2 text-sm text-elfag-dark hover:text-opacity-80"
          >
            <Lock className="w-4 h-4" />
            Del kontaktinfo
          </button>
        )}
        {contactShared && (
          <div className="flex items-center gap-2 text-sm text-green-600">
            <Unlock className="w-4 h-4" />
            Kontaktinfo delt
          </div>
        )}
      </div>
      
      {/* Rest of the message thread UI */}
    </div>
  );
};