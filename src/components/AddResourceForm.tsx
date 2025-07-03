import React, { useState } from 'react';
import { PlusCircle, X } from 'lucide-react';
import type { Resource } from '../types';

interface AddResourceFormProps {
  onAdd: (resource: Omit<Resource, 'id'>) => void;
}

export const AddResourceForm: React.FC<AddResourceFormProps> = ({ onAdd }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [formData, setFormData] = useState({
    anonymId: '',
    competence: '',
    period: {
      from: '',
      to: ''
    },
    location: '',
    comments: '',
    contactInfo: '',
    isSpecial: false,
    price: '',
    priceType: 'hourly' as const
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onAdd({
      ...formData,
      period: {
        from: new Date(formData.period.from),
        to: new Date(formData.period.to)
      },
      price: formData.price ? parseFloat(formData.price) : undefined
    });
    setFormData({
      anonymId: '',
      competence: '',
      period: { from: '', to: '' },
      location: '',
      comments: '',
      contactInfo: '',
      isSpecial: false,
      price: '',
      priceType: 'hourly'
    });
    setIsOpen(false);
  };

  return (
    <div className="mb-6">
      {!isOpen ? (
        <button
          onClick={() => setIsOpen(true)}
          className="flex items-center gap-2 bg-elfag-dark text-white px-4 py-2 rounded hover:bg-opacity-90 transition-colors"
        >
          <PlusCircle className="w-5 h-5" />
          Registrer tilgjengelig arbeider
        </button>
      ) : (
        <div className="bg-white p-6 rounded border-2 border-elfag-dark shadow-industrial">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-bold">Registrer tilgjengelig arbeider</h2>
            <button
              onClick={() => setIsOpen(false)}
              className="text-gray-500 hover:text-gray-700"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
          
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Bedrift (Anonym ID)
                </label>
                <input
                  type="text"
                  required
                  value={formData.anonymId}
                  onChange={(e) => setFormData({ ...formData, anonymId: e.target.value })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                  placeholder="F.eks. Bedrift A"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Kompetanse
                </label>
                <input
                  type="text"
                  required
                  value={formData.competence}
                  onChange={(e) => setFormData({ ...formData, competence: e.target.value })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                  placeholder="F.eks. Montør/Elektriker"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tilgjengelig fra
                </label>
                <input
                  type="date"
                  required
                  value={formData.period.from}
                  onChange={(e) => setFormData({
                    ...formData,
                    period: { ...formData.period, from: e.target.value }
                  })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tilgjengelig til
                </label>
                <input
                  type="date"
                  required
                  value={formData.period.to}
                  onChange={(e) => setFormData({
                    ...formData,
                    period: { ...formData.period, to: e.target.value }
                  })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Lokasjon
                </label>
                <input
                  type="text"
                  required
                  value={formData.location}
                  onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                  placeholder="F.eks. Oslo"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Kontaktinformasjon
                </label>
                <input
                  type="text"
                  required
                  value={formData.contactInfo}
                  onChange={(e) => setFormData({ ...formData, contactInfo: e.target.value })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                  placeholder="Telefon eller e-post"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Pris
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={formData.price}
                  onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                  placeholder="F.eks. 850"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Pristype
                </label>
                <select
                  value={formData.priceType}
                  onChange={(e) => setFormData({ ...formData, priceType: e.target.value as 'hourly' | 'fixed' | 'negotiable' })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                >
                  <option value="hourly">Per time</option>
                  <option value="fixed">Fast pris</option>
                  <option value="negotiable">Etter avtale</option>
                </select>
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Kommentarer
                </label>
                <textarea
                  value={formData.comments}
                  onChange={(e) => setFormData({ ...formData, comments: e.target.value })}
                  className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-elfag-light focus:border-transparent"
                  rows={3}
                  placeholder="Legg til relevant informasjon om erfaring, spesialkompetanse, etc."
                />
              </div>

              <div className="md:col-span-2">
                <label className="flex items-center space-x-2">
                  <input
                    type="checkbox"
                    checked={formData.isSpecial}
                    onChange={(e) => setFormData({ ...formData, isSpecial: e.target.checked })}
                    className="rounded border-gray-300 text-elfag-dark focus:ring-elfag-light"
                  />
                  <span className="text-sm font-medium text-gray-700">
                    Dette er en spesialkompetanse
                  </span>
                </label>
              </div>
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
                className="px-4 py-2 bg-elfag-dark text-white rounded hover:bg-opacity-90"
              >
                Registrer
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
};