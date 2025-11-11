import { ReactNode, useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import { auth } from '../config/firebase';
import { 
  LayoutDashboard, 
  Camera, 
  FileText, 
  CheckCircle, 
  Users, 
  UserCog,
  QrCode,
  LogOut,
  Menu,
  X,
  Moon,
  Sun
} from 'lucide-react';
import toast from 'react-hot-toast';

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [darkMode, setDarkMode] = useState(() => {
    const saved = localStorage.getItem('darkMode');
    return saved ? JSON.parse(saved) : false;
  });

  useEffect(() => {
    if (darkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [darkMode]);

  const toggleDarkMode = () => {
    const newMode = !darkMode;
    setDarkMode(newMode);
    localStorage.setItem('darkMode', JSON.stringify(newMode));
  };

  const handleSignOut = async () => {
    try {
      await signOut(auth);
      toast.success('Çıkış yapıldı');
      navigate('/signin');
    } catch (error: any) {
      toast.error('Çıkış yapılırken hata oluştu: ' + error.message);
    }
  };

  const menuItems = [
    { path: '/', icon: LayoutDashboard, label: 'Ana Sayfa' },
    { path: '/equipment', icon: Camera, label: 'Ekipmanlar' },
    { path: '/rentals', icon: FileText, label: 'Kiralama' },
    { path: '/deliveries', icon: CheckCircle, label: 'Teslim Alım' },
    { path: '/customers', icon: Users, label: 'Müşteriler' },
    { path: '/employees', icon: UserCog, label: 'Çalışanlar' },
    { path: '/qr-scanner', icon: QrCode, label: 'QR Tara' },
  ];

  const isActive = (path: string) => location.pathname === path;

  return (
    <div className="flex h-screen bg-gray-50 dark:bg-black">
      {/* Sidebar */}
      <aside
        className={`fixed lg:static inset-y-0 left-0 z-50 w-64 bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-800 transform transition-transform duration-300 ease-in-out ${
          sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        }`}
      >
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-800">
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 bg-black dark:bg-white rounded flex items-center justify-center">
                <span className="text-white dark:text-black font-bold text-sm">MF</span>
              </div>
              <span className="font-bold text-lg dark:text-white">MF-ETS</span>
            </div>
            <button
              onClick={() => setSidebarOpen(false)}
              className="lg:hidden text-gray-500 dark:text-gray-400"
            >
              <X size={24} />
            </button>
          </div>

          {/* Navigation */}
          <nav className="flex-1 p-4 space-y-2 overflow-y-auto">
            {menuItems.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={() => setSidebarOpen(false)}
                  className={`flex items-center space-x-3 px-4 py-3 rounded-lg transition-colors ${
                    isActive(item.path)
                      ? 'bg-black dark:bg-white text-white dark:text-black'
                      : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800'
                  }`}
                >
                  <Icon size={20} />
                  <span className="font-medium">{item.label}</span>
                </Link>
              );
            })}
          </nav>

          {/* Footer */}
          <div className="p-4 border-t border-gray-200 dark:border-gray-800 space-y-2">
            <button
              onClick={toggleDarkMode}
              className="w-full flex items-center space-x-3 px-4 py-3 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            >
              {darkMode ? <Sun size={20} /> : <Moon size={20} />}
              <span className="font-medium">{darkMode ? 'Açık Tema' : 'Koyu Tema'}</span>
            </button>
            <button
              onClick={handleSignOut}
              className="w-full flex items-center space-x-3 px-4 py-3 rounded-lg text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
            >
              <LogOut size={20} />
              <span className="font-medium">Çıkış Yap</span>
            </button>
          </div>
        </div>
      </aside>

      {/* Overlay for mobile */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Main content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Top bar */}
        <header className="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex items-center justify-between">
          <button
            onClick={() => setSidebarOpen(true)}
            className="lg:hidden text-gray-500 dark:text-gray-400"
          >
            <Menu size={24} />
          </button>
          <div className="flex-1" />
          <div className="text-sm text-gray-600 dark:text-gray-400">
            {auth.currentUser?.email}
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  );
}

