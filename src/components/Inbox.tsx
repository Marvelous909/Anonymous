import React, { useEffect, useState } from 'react';
import { Mail, Send, Lock, Unlock, Loader, Check } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { Message } from '../types';

interface InboxProps {
  onMessageUpdate?: () => void;
}

export const Inbox: React.FC<InboxProps> = ({ onMessageUpdate }) => {
  const { user } = useAuth();
  const [messages, setMessages] = useState<Message[]>([]);
  const [selectedMessage, setSelectedMessage] = useState<Message | null>(null);
  const [selectedThread, setSelectedThread] = useState<Message[]>([]);
  const [reply, setReply] = useState('');
  const [loading, setLoading] = useState(false);
  const [loadingThread, setLoadingThread] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasCompany, setHasCompany] = useState(true);
  const [contactShared, setContactShared] = useState<Record<string, boolean>>({});
  const [userCompanyId, setUserCompanyId] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    loadUserCompany();
  }, [user]);

  useEffect(() => {
    if (!userCompanyId) return;

    // Subscribe to messages - both sent and received
    const messagesChannel = supabase.channel('messages_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'messages',
        filter: `from_company_id=eq.${userCompanyId}`,
      }, () => {
        loadMessages();
      })
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'messages',
        filter: `to_company_id=eq.${userCompanyId}`,
      }, () => {
        loadMessages();
      })
      .subscribe();

    // Subscribe to contact sharing
    const sharingChannel = supabase.channel('contact_sharing_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'thread_contact_sharing',
        filter: `from_company_id=eq.${userCompanyId}`,
      }, () => {
        loadContactSharing();
      })
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'thread_contact_sharing',
        filter: `to_company_id=eq.${userCompanyId}`,
      }, () => {
        loadContactSharing();
      })
      .subscribe();

    // Initial data load
    loadMessages();
    loadContactSharing();

    return () => {
      messagesChannel.unsubscribe();
      sharingChannel.unsubscribe();
    };
  }, [userCompanyId]);

  // When selected message changes, load its thread
  useEffect(() => {
    if (selectedMessage) {
      loadThread(selectedMessage.thread_id || selectedMessage.id);
    }
  }, [selectedMessage]);

  const loadUserCompany = async () => {
    if (!user) return;

    try {
      const { data: company, error } = await supabase
        .from('companies')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

      if (error) throw error;

      if (!company) {
        setHasCompany(false);
        setUserCompanyId(null);
        return;
      }

      setUserCompanyId(company.id);
      setHasCompany(true);
    } catch (error) {
      console.error('Error loading user company:', error);
      setError('Kunne ikke laste bedriftsinformasjon. Vennligst prøv igjen senere.');
    }
  };

  const loadContactSharing = async () => {
    if (!userCompanyId) return;

    try {
      const { data: sharingData, error: sharingError } = await supabase
        .from('thread_contact_sharing')
        .select('thread_id, from_company_id, to_company_id')
        .or(`from_company_id.eq.${userCompanyId},to_company_id.eq.${userCompanyId}`);

      if (sharingError) throw sharingError;

      const sharedThreads = sharingData.reduce((acc: Record<string, boolean>, curr) => {
        acc[curr.thread_id] = true;
        return acc;
      }, {});

      setContactShared(sharedThreads);
    } catch (error) {
      console.error('Error loading contact sharing:', error);
    }
  };

  const loadMessages = async () => {
    if (!userCompanyId) return;

    try {
      setLoading(true);
      const { data: messages, error } = await supabase
        .from('messages')
        .select(`
          id,
          subject,
          content,
          created_at,
          read_at,
          thread_id,
          from_company:from_company_id(
            id, 
            anonymous_id,
            real_contact_info
          ),
          to_company:to_company_id(
            id, 
            anonymous_id,
            real_contact_info
          ),
          resource:resource_id(
            id, 
            competence,
            is_taken,
            price,
            price_type
          )
        `)
        .or(`from_company_id.eq.${userCompanyId},to_company_id.eq.${userCompanyId}`)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const validMessages = messages.filter(
        (msg) => msg.from_company && msg.to_company && msg.resource
      );

      // Group messages by thread and get the latest message from each thread
      const threadMap = new Map();
      validMessages.forEach(msg => {
        const threadId = msg.thread_id || msg.id;
        if (!threadMap.has(threadId) || new Date(msg.created_at) > new Date(threadMap.get(threadId).created_at)) {
          threadMap.set(threadId, msg);
        }
      });

      const latestMessages = Array.from(threadMap.values());
      setMessages(latestMessages);

      // If there's a selected message, ensure it stays selected after refresh
      if (selectedMessage) {
        const updatedSelectedMessage = latestMessages.find(
          msg => msg.id === selectedMessage.id || msg.thread_id === selectedMessage.id
        );
        if (updatedSelectedMessage) {
          setSelectedMessage(updatedSelectedMessage);
        }
      }

      // Notify parent component if needed
      if (onMessageUpdate) {
        onMessageUpdate();
      }
    } catch (error) {
      console.error('Error loading messages:', error);
      setError('Kunne ikke laste meldinger. Vennligst prøv igjen senere.');
    } finally {
      setLoading(false);
    }
  };

  const loadThread = async (messageId: string) => {
    try {
      setLoadingThread(true);
      const { data: messages, error } = await supabase
        .from('messages')
        .select(`
          id,
          subject,
          content,
          created_at,
          read_at,
          thread_id,
          from_company:from_company_id(
            id, 
            anonymous_id,
            real_contact_info
          ),
          to_company:to_company_id(
            id, 
            anonymous_id,
            real_contact_info
          ),
          resource:resource_id(
            id, 
            competence,
            is_taken,
            price,
            price_type
          )
        `)
        .or(`id.eq.${messageId},thread_id.eq.${messageId}`)
        .order('created_at', { ascending: true });

      if (error) throw error;

      const validMessages = messages.filter(
        (msg) => msg.from_company && msg.to_company && msg.resource
      );

      setSelectedThread(validMessages);

      // Mark unread messages as read
      const unreadMessages = validMessages.filter(msg => 
        !msg.read_at && 
        msg.to_company.id === userCompanyId
      );

      if (unreadMessages.length > 0) {
        await Promise.all(
          unreadMessages.map(msg =>
            supabase
              .from('messages')
              .update({ read_at: new Date().toISOString() })
              .eq('id', msg.id)
          )
        );
      }
    } catch (error) {
      console.error('Error loading thread:', error);
      setError('Kunne ikke laste meldingstråd. Vennligst prøv igjen senere.');
    } finally {
      setLoadingThread(false);
    }
  };

  const handleReply = async () => {
    if (!selectedMessage || !reply.trim() || !userCompanyId) return;

    try {
      const threadId = selectedMessage.thread_id || selectedMessage.id;
      const toCompanyId = selectedMessage.from_company.id === userCompanyId
        ? selectedMessage.to_company.id
        : selectedMessage.from_company.id;

      const { error } = await supabase
        .from('messages')
        .insert({
          from_company_id: userCompanyId,
          to_company_id: toCompanyId,
          resource_id: selectedMessage.resource.id,
          subject: `Re: ${selectedMessage.subject}`,
          content: reply,
          thread_id: threadId
        });

      if (error) throw error;

      setReply('');
      loadMessages();
      loadThread(threadId);
      
      if (onMessageUpdate) {
        onMessageUpdate();
      }
    } catch (error) {
      console.error('Error sending reply:', error);
      setError('Kunne ikke sende svar. Vennligst prøv igjen senere.');
    }
  };

  const handleShareContact = async (messageId: string) => {
    if (!selectedMessage || !userCompanyId) return;

    try {
      // First, share contact info
      const { error: sharingError } = await supabase
        .from('thread_contact_sharing')
        .insert({
          thread_id: messageId,
          from_company_id: userCompanyId,
          to_company_id: selectedMessage.from_company.id === userCompanyId
            ? selectedMessage.to_company.id
            : selectedMessage.from_company.id
        });

      if (sharingError) throw sharingError;

      // Then, send a system message about contact sharing
      const { error: messageError } = await supabase
        .from('messages')
        .insert({
          from_company_id: userCompanyId,
          to_company_id: selectedMessage.from_company.id === userCompanyId
            ? selectedMessage.to_company.id
            : selectedMessage.from_company.id,
          resource_id: selectedMessage.resource.id,
          subject: 'Kontaktinformasjon delt',
          content: 'Kontaktinformasjon er nå delt mellom partene.',
          thread_id: messageId
        });

      if (messageError) throw messageError;

      // Refresh the UI
      loadContactSharing();
      loadMessages();
      loadThread(messageId);
    } catch (error) {
      console.error('Error sharing contact:', error);
      setError('Kunne ikke dele kontaktinformasjon. Prøv igjen senere.');
    }
  };

  const handleMarkAsTaken = async (resourceId: string) => {
    try {
      const { error } = await supabase
        .from('resources')
        .update({ is_taken: true })
        .eq('id', resourceId);

      if (error) throw error;

      // Refresh messages to update UI
      loadMessages();
      if (onMessageUpdate) {
        onMessageUpdate();
      }
    } catch (error) {
      console.error('Error marking resource as taken:', error);
      setError('Kunne ikke markere ressursen som tatt. Prøv igjen senere.');
    }
  };

  const getDisplayName = (message: Message, isFromUser: boolean) => {
    const company = isFromUser ? message.from_company : message.to_company;
    const isShared = contactShared[message.thread_id || message.id];
    
    if (isFromUser) return 'Du';
    if (isShared && company.real_contact_info) {
      return company.real_contact_info.company_name;
    }
    return company.anonymous_id;
  };

  if (!hasCompany) {
    return (
      <div className="bg-white border-2 border-elfag-dark rounded shadow-industrial p-4">
        <div className="bg-yellow-50 border border-yellow-400 text-yellow-700 px-4 py-3 rounded">
          Du må registrere en bedrift før du kan bruke meldingsfunksjonen.
          Vennligst kontakt support for assistanse.
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white border-2 border-elfag-dark rounded shadow-industrial">
      <div className="bg-elfag-light p-3">
        <h2 className="text-xl font-bold text-elfag-dark flex items-center gap-2">
          <Mail className="w-5 h-5" />
          Meldinger
        </h2>
      </div>

      {error && (
        <div className="p-4">
          <div className="bg-red-50 border border-red-400 text-red-700 px-4 py-3 rounded">
            {error}
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 h-[600px]">
        {/* Message List */}
        <div className="border-r border-gray-200 overflow-y-auto">
          {loading ? (
            <div className="flex items-center justify-center p-8">
              <Loader className="w-6 h-6 animate-spin text-elfag-dark" />
              <span className="ml-2">Laster meldinger...</span>
            </div>
          ) : messages.length === 0 ? (
            <div className="p-4 text-center text-gray-500">Ingen meldinger</div>
          ) : (
            <div className="divide-y">
              {messages.map((message) => {
                const isUnread = !message.read_at && message.to_company.id === userCompanyId;
                const isSelected = selectedMessage?.id === message.id || 
                                 selectedMessage?.thread_id === message.id ||
                                 message.thread_id === selectedMessage?.id;
                const displayName = getDisplayName(
                  message,
                  message.from_company.id === userCompanyId
                );
                
                return (
                  <button
                    key={message.id}
                    onClick={() => setSelectedMessage(message)}
                    className={`w-full p-4 text-left hover:bg-gray-50 ${
                      isSelected ? 'bg-gray-50' : ''
                    } ${isUnread ? 'font-semibold bg-elfag-light bg-opacity-10' : ''}`}
                  >
                    <div className="flex justify-between items-start mb-1">
                      <span className="text-sm">
                        {message.from_company.id === userCompanyId
                          ? `Til: ${getDisplayName(message, false)}`
                          : `Fra: ${displayName}`}
                      </span>
                      <span className="text-xs text-gray-500">
                        {new Date(message.created_at).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="text-sm truncate">{message.subject}</div>
                    {isUnread && (
                      <div className="mt-1">
                        <span className="inline-block px-2 py-1 text-xs bg-elfag-light bg-opacity-20 rounded-full">
                          Ny melding
                        </span>
                      </div>
                    )}
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Message Content */}
        <div className="col-span-2 flex flex-col h-full">
          {selectedMessage ? (
            <div className="flex flex-col h-full p-4">
              <div className="flex justify-between items-center mb-4">
                <div>
                  <h3 className="text-xl font-semibold">
                    {selectedMessage.subject}
                  </h3>
                  {selectedMessage.resource.is_taken && (
                    <div className="mt-1 text-sm text-green-600 flex items-center gap-1">
                      <Check className="w-4 h-4" />
                      Avtale inngått
                    </div>
                  )}
                </div>
                <div className="flex items-center gap-4">
                  {!selectedMessage.resource.is_taken && contactShared[selectedMessage.thread_id || selectedMessage.id] && (
                    <button
                      onClick={() => handleMarkAsTaken(selectedMessage.resource.id)}
                      className="flex items-center gap-2 text-sm text-green-600 hover:text-green-700"
                    >
                      <Check className="w-4 h-4" />
                      Marker som avtalt
                    </button>
                  )}
                  {!contactShared[selectedMessage.thread_id || selectedMessage.id] && (
                    <button
                      onClick={() => handleShareContact(selectedMessage.thread_id || selectedMessage.id)}
                      className="flex items-center gap-2 text-sm text-elfag-dark hover:text-opacity-80"
                    >
                      <Lock className="w-4 h-4" />
                      Del kontaktinfo
                    </button>
                  )}
                  {contactShared[selectedMessage.thread_id || selectedMessage.id] && (
                    <div className="flex items-center gap-2 text-sm text-green-600">
                      <Unlock className="w-4 h-4" />
                      Kontaktinfo delt
                    </div>
                  )}
                </div>
              </div>

              <div className="flex-1 overflow-y-auto mb-4 space-y-4">
                {loadingThread ? (
                  <div className="flex items-center justify-center p-8">
                    <Loader className="w-6 h-6 animate-spin text-elfag-dark" />
                    <span className="ml-2">Laster meldingstråd...</span>
                  </div>
                ) : (
                  selectedThread.map((message) => {
                    const isFromUser = message.from_company.id === userCompanyId;
                    const isContactMessage = message.subject === 'Kontaktinformasjon delt';
                    const showContactInfo = contactShared[selectedMessage.thread_id || selectedMessage.id] && 
                                         message.from_company.real_contact_info &&
                                         !isContactMessage;
                    
                    return (
                      <div
                        key={message.id}
                        className={`p-4 rounded ${
                          isContactMessage 
                            ? 'bg-green-50 text-center' 
                            : isFromUser
                              ? 'bg-elfag-light bg-opacity-10 ml-8'
                              : 'bg-gray-50 mr-8'
                        }`}
                      >
                        <div className="flex justify-between text-sm text-gray-500 mb-2">
                          <div>
                            <p className="font-medium">
                              {getDisplayName(message, isFromUser)}
                            </p>
                          </div>
                          <span>
                            {new Date(message.created_at).toLocaleString()}
                          </span>
                        </div>
                        <div className="whitespace-pre-wrap">{message.content}</div>
                        {showContactInfo && (
                          <div className="mt-2 p-2 bg-green-50 rounded text-sm">
                            <p className="font-semibold">Kontaktinformasjon:</p>
                            <p>{message.from_company.real_contact_info.company_name}</p>
                            <p>{message.from_company.real_contact_info.email}</p>
                            <p>{message.from_company.real_contact_info.phone}</p>
                            <p>{message.from_company.real_contact_info.address}</p>
                          </div>
                        )}
                      </div>
                    );
                  })
                )}
              </div>

              {!selectedMessage.resource.is_taken && (
                <div className="border-t pt-4 mt-auto">
                  <h4 className="font-semibold mb-2">Svar</h4>
                  <textarea
                    value={reply}
                    onChange={(e) => setReply(e.target.value)}
                    className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                    rows={4}
                    placeholder="Skriv ditt svar her..."
                  />
                  <div className="flex justify-end mt-2">
                    <button
                      onClick={handleReply}
                      disabled={!reply.trim()}
                      className="flex items-center gap-2 bg-elfag-dark text-white px-4 py-2 rounded hover:bg-opacity-90 disabled:opacity-50"
                    >
                      <Send className="w-4 h-4" />
                      Send svar
                    </button>
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="h-full flex items-center justify-center text-gray-500">
              Velg en melding for å lese
            </div>
          )}
        </div>
      </div>
    </div>
  );
};