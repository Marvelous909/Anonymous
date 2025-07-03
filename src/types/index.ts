export interface Resource {
  id: string;
  company_id: string;
  anonymId: string;
  competence: string;
  period: {
    from: Date;
    to: Date;
  };
  location: string;
  comments: string;
  contactInfo: string;
  isSpecial: boolean;
  is_taken?: boolean;
  price?: number;
  priceType?: 'hourly' | 'fixed' | 'negotiable';
  acceptedByCompanyId?: string;
}

export interface Company {
  id: string;
  name: string;
  anonymousId: string;
  createdAt: Date;
}

export interface Message {
  id: string;
  subject: string;
  content: string;
  created_at: string;
  read_at: string | null;
  from_company: {
    id: string;
    anonymous_id: string;
    real_contact_info?: {
      company_name: string;
      email: string;
      phone: string;
      address: string;
    };
  };
  to_company: {
    id: string;
    anonymous_id: string;
    real_contact_info?: {
      company_name: string;
      email: string;
      phone: string;
      address: string;
    };
  };
  resource: {
    id: string;
    competence: string;
    is_taken?: boolean;
    price?: number;
    price_type?: string;
  };
  thread_id?: string;
}

// Database types
export type Tables = {
  companies: {
    Row: {
      id: string;
      name: string;
      anonymous_id: string;
      created_at: string;
      user_id: string;
    };
    Insert: Omit<Tables['companies']['Row'], 'id' | 'created_at'>;
    Update: Partial<Tables['companies']['Insert']>;
  };
  resources: {
    Row: {
      id: string;
      company_id: string;
      competence: string;
      period_from: string;
      period_to: string;
      location: string;
      comments: string | null;
      contact_info: string;
      created_at: string;
      is_special: boolean;
      is_taken: boolean;
      price: number | null;
      price_type: string;
      accepted_by_company_id: string | null;
    };
    Insert: Omit<Tables['resources']['Row'], 'id' | 'created_at'>;
    Update: Partial<Tables['resources']['Insert']>;
  };
  messages: {
    Row: {
      id: string;
      from_company_id: string;
      to_company_id: string;
      resource_id: string;
      subject: string;
      content: string;
      created_at: string;
      read_at: string | null;
      thread_id: string | null;
    };
    Insert: Omit<Tables['messages']['Row'], 'id' | 'created_at' | 'read_at'>;
    Update: Partial<Omit<Tables['messages']['Row'], 'id' | 'created_at'>>;
  };
};