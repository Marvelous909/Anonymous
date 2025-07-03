import React, { useState, useEffect } from 'react';
import { ResourceTable } from './ResourceTable';
import { AddResourceForm } from './AddResourceForm';
import { Inbox } from './Inbox';
import { RegisterCompany } from './RegisterCompany';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import type { Resource } from '../types';

type Tab = 'marketplace' | 'my-offers' | 'my-requests';

export const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>('marketplace');
  const [resources, setResources] = useState<Resource[]>([]);
  const [myOffers, setMyOffers] = useState<Resource[]>([]);
  const [myRequests, setMyRequests] = useState<Resource[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasCompany, setHasCompany] = useState(true);
  const [userCompanyId, setUserCompanyId] = useState<string | null>(null);

  // Set up real-time subscription for resources
  useEffect(() => {
    if (!user) return;

    const subscription = supabase
      .channel('resources_channel')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'resources'
        },
        () => {
          loadAllResources();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [user, userCompanyId]); // Add userCompanyId as dependency

  useEffect(() => {
    if (user) {
      loadUserCompany();
    }
  }, [user]);

  const loadUserCompany = async () => {
    try {
      setLoading(true);
      const { data: company, error } = await supabase
        .from('companies')
        .select('id')
        .eq('user_id', user?.id)
        .single();

      if (error) throw error;

      if (!company) {
        setHasCompany(false);
        setUserCompanyId(null);
        return;
      }

      setUserCompanyId(company.id);
      setHasCompany(true);
      await loadAllResources(); // Load resources after company is loaded
    } catch (error) {
      console.error('Error loading user company:', error);
      setError('Kunne ikke laste bedriftsinformasjon');
    } finally {
      setLoading(false);
    }
  };

  const transformResources = (data: any[]) => 
    data
      .filter(resource => resource.company_id)
      .map(resource => ({
        ...resource,
        id: resource.id,
        company_id: resource.company_id,
        anonymId: resource.anonymous_id,
        period: {
          from: new Date(resource.period_from),
          to: new Date(resource.period_to)
        },
        isSpecial: resource.is_special,
        is_taken: resource.is_taken,
        price: resource.price,
        priceType: resource.price_type,
        acceptedByCompanyId: resource.accepted_by_company_id
      }));

  const loadAllResources = async () => {
    if (!userCompanyId) return;
    
    try {
      setLoading(true);
      const currentDate = new Date().toISOString();
      
      // Load marketplace resources
      const { data: marketplaceData, error: marketplaceError } = await supabase
        .from('anonymized_resources')
        .select('*')
        .gte('period_to', currentDate)
        .eq('is_taken', false)
        .order('created_at', { ascending: false });

      if (marketplaceError) throw marketplaceError;

      // Load my offers (resources I've posted)
      const { data: myOffersData, error: myOffersError } = await supabase
        .from('anonymized_resources')
        .select('*')
        .eq('company_id', userCompanyId)
        .order('created_at', { ascending: false });

      if (myOffersError) throw myOffersError;

      // Load my requests (resources I've requested or accepted)
      const { data: myRequestsData, error: myRequestsError } = await supabase
        .from('anonymized_resources')
        .select('*')
        .eq('accepted_by_company_id', userCompanyId)
        .order('created_at', { ascending: false });

      if (myRequestsError) throw myRequestsError;

      setResources(transformResources(marketplaceData || []));
      setMyOffers(transformResources(myOffersData || []));
      setMyRequests(transformResources(myRequestsData || []));
      setError(null);
    } catch (error) {
      console.error('Error loading resources:', error);
      setError('Kunne ikke laste ressurser. Vennligst prøv igjen senere.');
    } finally {
      setLoading(false);
    }
  };

  const handleAddResource = async (newResource: Omit<Resource, 'id' | 'company_id'>) => {
    if (!user || !userCompanyId) return;

    try {
      setError(null);
      const { error } = await supabase
        .from('resources')
        .insert({
          company_id: userCompanyId,
          competence: newResource.competence,
          period_from: newResource.period.from.toISOString(),
          period_to: newResource.period.to.toISOString(),
          location: newResource.location,
          comments: newResource.comments,
          contact_info: newResource.contactInfo,
          is_special: newResource.isSpecial,
          is_taken: false,
          price: newResource.price,
          price_type: newResource.priceType
        });

      if (error) throw error;
      await loadAllResources();
    } catch (error) {
      console.error('Error adding resource:', error);
      setError('Kunne ikke legge til ressurs. Vennligst prøv igjen senere.');
    }
  };

  const handleCompanyRegistered = () => {
    setHasCompany(true);
    setError(null);
    loadUserCompany();
  };

  const handleMessageSent = () => {
    loadAllResources();
  };

  const renderTabContent = () => {
    if (loading) {
      return (
        <div className="text-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-elfag-dark mx-auto"></div>
        </div>
      );
    }

    if (error) {
      return (
        <div className="bg-red-50 border border-red-400 text-red-700 px-4 py-3 rounded">
          {error}
        </div>
      );
    }

    switch (activeTab) {
      case 'marketplace':
        return (
          <>
            <ResourceTable 
              title="TILGJENGELIG BEMANNING" 
              resources={resources.filter(r => !r.isSpecial)}
              onMessageSent={handleMessageSent}
            />
            <ResourceTable 
              title="SPESIALKOMPETANSE TIL UTLÅN" 
              resources={resources.filter(r => r.isSpecial)}
              onMessageSent={handleMessageSent}
            />
          </>
        );
      case 'my-offers':
        return (
          <ResourceTable 
            title="MINE UTLÅN" 
            resources={myOffers}
            onMessageSent={handleMessageSent}
            showStatus
            showActions
          />
        );
      case 'my-requests':
        return (
          <ResourceTable 
            title="MINE FORESPØRSLER" 
            resources={myRequests}
            onMessageSent={handleMessageSent}
            showStatus
            showActions
          />
        );
    }
  };

  return (
    <div className="space-y-8">
      <div className="bg-white p-6 rounded border-2 border-elfag-dark shadow-industrial">
        <h1 className="text-2xl font-bold mb-4">Innleie av Arbeidskraft</h1>
        <p className="text-gray-700 mb-4">
          Som Elfag-bedrift kan du enkelt dele og finne tilgjengelige fagarbeidere. 
          Dette verktøyet er designet for å forenkle prosessen med å dele ressurser 
          mellom Elfag-medlemmer.
        </p>
        <div className="bg-elfag-light bg-opacity-20 p-4 rounded">
          <h2 className="font-bold mb-2">Viktig informasjon:</h2>
          <ul className="list-disc list-inside space-y-2">
            <li>All kommunikasjon er anonym inntil begge parter er enige om å dele kontaktinformasjon</li>
            <li>Du kan enkelt administrere dine egne ressurser og meldinger</li>
            <li>Avtaler og kontrakter utformes direkte mellom partene</li>
            <li>Ressurser fjernes automatisk når perioden er utløpt eller avtale er inngått</li>
          </ul>
        </div>
      </div>

      {!hasCompany ? (
        <RegisterCompany onRegistered={handleCompanyRegistered} />
      ) : (
        <>
          <Inbox onMessageUpdate={loadAllResources} />

          <AddResourceForm onAdd={handleAddResource} />

          <div className="bg-white rounded border-2 border-elfag-dark shadow-industrial">
            <div className="border-b border-elfag-dark">
              <nav className="flex">
                <button
                  onClick={() => setActiveTab('marketplace')}
                  className={`px-6 py-3 text-sm font-medium ${
                    activeTab === 'marketplace'
                      ? 'bg-elfag-light text-elfag-dark'
                      : 'text-gray-500 hover:text-elfag-dark hover:bg-elfag-light hover:bg-opacity-50'
                  }`}
                >
                  Markedsplass
                </button>
                <button
                  onClick={() => setActiveTab('my-offers')}
                  className={`px-6 py-3 text-sm font-medium ${
                    activeTab === 'my-offers'
                      ? 'bg-elfag-light text-elfag-dark'
                      : 'text-gray-500 hover:text-elfag-dark hover:bg-elfag-light hover:bg-opacity-50'
                  }`}
                >
                  Mine utlån
                </button>
                <button
                  onClick={() => setActiveTab('my-requests')}
                  className={`px-6 py-3 text-sm font-medium ${
                    activeTab === 'my-requests'
                      ? 'bg-elfag-light text-elfag-dark'
                      : 'text-gray-500 hover:text-elfag-dark hover:bg-elfag-light hover:bg-opacity-50'
                  }`}
                >
                  Mine forespørsler
                </button>
              </nav>
            </div>
            <div className="p-4">
              {renderTabContent()}
            </div>
          </div>
        </>
      )}
    </div>
  );
};