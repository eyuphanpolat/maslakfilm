import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import { auth } from './config/firebase';
import { Toaster } from 'react-hot-toast';
import SignIn from './pages/SignIn';
import Dashboard from './pages/Dashboard';
import EquipmentList from './pages/EquipmentList';
import EquipmentDetail from './pages/EquipmentDetail';
import Rentals from './pages/Rentals';
import Deliveries from './pages/Deliveries';
import Customers from './pages/Customers';
import Employees from './pages/Employees';
import QRScanner from './pages/QRScanner';
import Layout from './components/Layout';
import LoadingSpinner from './components/LoadingSpinner';

function App() {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    try {
      const unsubscribe = onAuthStateChanged(
        auth,
        (user) => {
          setUser(user);
          setLoading(false);
          setError(null);
        },
        (error) => {
          console.error('Auth state change error:', error);
          setError('Kimlik doğrulama hatası: ' + error.message);
          setLoading(false);
        }
      );

      return () => unsubscribe();
    } catch (error: any) {
      console.error('App initialization error:', error);
      setError('Uygulama başlatılırken hata oluştu: ' + error.message);
      setLoading(false);
    }
  }, []);

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-white dark:bg-black p-4">
        <div className="text-center max-w-md">
          <h1 className="text-2xl font-bold text-red-600 dark:text-red-400 mb-4">Hata</h1>
          <p className="text-gray-900 dark:text-white mb-4">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="px-4 py-2 bg-black dark:bg-white text-white dark:text-black rounded-lg hover:bg-gray-800 dark:hover:bg-gray-200"
          >
            Sayfayı Yenile
          </button>
        </div>
      </div>
    );
  }

  if (loading) {
    return <LoadingSpinner />;
  }

  return (
    <Router>
      <Toaster position="top-right" />
      <Routes>
        <Route path="/signin" element={user ? <Navigate to="/" /> : <SignIn />} />
        <Route
          path="/*"
          element={
            user ? (
              <Layout>
                <Routes>
                  <Route path="/" element={<Dashboard />} />
                  <Route path="/equipment" element={<EquipmentList />} />
                  <Route path="/equipment/:id" element={<EquipmentDetail />} />
                  <Route path="/rentals" element={<Rentals />} />
                  <Route path="/deliveries" element={<Deliveries />} />
                  <Route path="/customers" element={<Customers />} />
                  <Route path="/employees" element={<Employees />} />
                  <Route path="/qr-scanner" element={<QRScanner />} />
                </Routes>
              </Layout>
            ) : (
              <Navigate to="/signin" />
            )
          }
        />
      </Routes>
    </Router>
  );
}

export default App;

