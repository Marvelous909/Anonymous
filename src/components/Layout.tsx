import React from 'react';
import { CircuitBoard, LogOut } from 'lucide-react';
import { Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export const Layout: React.FC = () => {
  const { signOut } = useAuth();
  const navigate = useNavigate();

  const handleSignOut = async () => {
    try {
      await signOut();
      navigate('/login');
    } catch (error) {
      console.error('Error signing out:', error);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-elfag-dark text-white px-6 py-4 border-b-4 border-elfag-light">
        <div className="container mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <CircuitBoard className="w-8 h-8 text-elfag-light" />
            <h1 className="text-2xl font-bold">Elfag Ressursdeling</h1>
          </div>
          <button
            onClick={handleSignOut}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white hover:bg-elfag-light hover:bg-opacity-20 rounded-md transition-colors"
          >
            <LogOut className="w-4 h-4" />
            Logg ut
          </button>
        </div>
      </header>
      
      <main className="container mx-auto px-6 py-8">
        <Outlet />
      </main>
      
      <footer className="bg-elfag-dark text-white px-6 py-4 mt-auto">
        <div className="container mx-auto text-sm">
          © {new Date().getFullYear()} Elfag - Ressursdelingsportal
        </div>
      </footer>
    </div>
  );
};