import { useEffect, useState } from 'react';
import { collection, query, orderBy, onSnapshot, deleteDoc, doc } from 'firebase/firestore';
import { db, auth } from '../config/firebase';
import { Link, useNavigate } from 'react-router-dom';
import { Plus, Camera, Trash2, QrCode } from 'lucide-react';
import toast from 'react-hot-toast';
import AddEquipmentModal from '../components/AddEquipmentModal';

interface Equipment {
  id: string;
  name: string;
  category: string;
  status: 'ofiste' | 'kiralamada';
  stock: number;
}

export default function EquipmentList() {
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    // Check admin status
    const checkAdmin = async () => {
      const user = auth.currentUser;
      if (!user) return;

      const adminEmails = ['polathakki@gmail.com', 'eyuphanpolatt@gmail.com'];
      const userEmail = user.email?.toLowerCase().trim();
      
      if (userEmail && adminEmails.includes(userEmail)) {
        setIsAdmin(true);
        return;
      }

      // Check Firestore
      const { doc, getDoc } = await import('firebase/firestore');
      const userDoc = await getDoc(doc(db, 'users', user.uid));
      if (userDoc.exists()) {
        const data = userDoc.data();
        setIsAdmin(data.role === 'admin' || data.isAdmin === true);
      }
    };

    checkAdmin();

    // Subscribe to equipment changes
    const q = query(collection(db, 'equipment'), orderBy('name'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const items: Equipment[] = [];
      snapshot.forEach((doc) => {
        items.push({ id: doc.id, ...doc.data() } as Equipment);
      });
      setEquipment(items);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleDelete = async (equipmentId: string, equipmentName: string) => {
    if (!confirm(`${equipmentName} ekipmanını silmek istediğinizden emin misiniz?`)) {
      return;
    }

    try {
      await deleteDoc(doc(db, 'equipment', equipmentId));
      toast.success('Ekipman silindi');
    } catch (error: any) {
      // Hata sessizce log edilir
      console.error('Ekipman silme hatası:', error);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-black dark:border-white"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Ekipmanlar</h1>
          <p className="text-gray-600 dark:text-gray-400">Tüm ekipmanları görüntüleyin ve yönetin</p>
        </div>
        <div className="flex space-x-3">
          <button
            onClick={() => navigate('/qr-scanner')}
            className="flex items-center space-x-2 px-4 py-2 bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
          >
            <QrCode size={20} />
            <span>QR Tara</span>
          </button>
          <button
            onClick={() => setShowAddModal(true)}
            className="flex items-center space-x-2 px-4 py-2 bg-black dark:bg-white text-white dark:text-black rounded-lg hover:bg-gray-800 dark:hover:bg-gray-200 transition-colors"
          >
            <Plus size={20} />
            <span>Ekipman Ekle</span>
          </button>
        </div>
      </div>

      {equipment.length === 0 ? (
        <div className="text-center py-12">
          <Camera className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
            Henüz ekipman yok
          </h3>
          <p className="text-gray-600 dark:text-gray-400 mb-4">
            Yeni ekipman eklemek için yukarıdaki butona tıklayın
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {equipment.map((item) => (
            <Link
              key={item.id}
              to={`/equipment/${item.id}`}
              className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800 hover:shadow-lg transition-shadow"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center space-x-3">
                  <div
                    className={`p-3 rounded-lg ${
                      item.status === 'kiralamada'
                        ? 'bg-orange-100 dark:bg-orange-900/20'
                        : 'bg-green-100 dark:bg-green-900/20'
                    }`}
                  >
                    <Camera
                      className={`w-6 h-6 ${
                        item.status === 'kiralamada'
                          ? 'text-orange-600 dark:text-orange-400'
                          : 'text-green-600 dark:text-green-400'
                      }`}
                    />
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900 dark:text-white">{item.name}</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">{item.category}</p>
                  </div>
                </div>
                {isAdmin && (
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      handleDelete(item.id, item.name);
                    }}
                    className="text-red-600 dark:text-red-400 hover:text-red-800 dark:hover:text-red-300"
                  >
                    <Trash2 size={18} />
                  </button>
                )}
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Durum:</span>
                  <span
                    className={`px-2 py-1 rounded text-xs font-medium ${
                      item.status === 'kiralamada'
                        ? 'bg-orange-100 dark:bg-orange-900/20 text-orange-800 dark:text-orange-300'
                        : 'bg-green-100 dark:bg-green-900/20 text-green-800 dark:text-green-300'
                    }`}
                  >
                    {item.status === 'kiralamada' ? 'Kiralamada' : 'Ofiste'}
                  </span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Stok:</span>
                  <span className="text-gray-900 dark:text-white">
                    {item.stock}
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}

      {showAddModal && (
        <AddEquipmentModal onClose={() => setShowAddModal(false)} />
      )}
    </div>
  );
}

