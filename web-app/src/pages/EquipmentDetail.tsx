import { useEffect, useState } from 'react';
import { doc, getDoc, onSnapshot } from 'firebase/firestore';
import { useParams, Link } from 'react-router-dom';
import { db } from '../config/firebase';
import { ArrowLeft, Camera } from 'lucide-react';
import LoadingSpinner from '../components/LoadingSpinner';

interface Equipment {
  id: string;
  name: string;
  category: string;
  status: 'ofiste' | 'kiralamada';
  stock: number;
  qrCodeData?: string;
  currentRentalId?: string;
}

export default function EquipmentDetail() {
  const { id } = useParams<{ id: string }>();
  const [equipment, setEquipment] = useState<Equipment | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!id) return;

    const unsubscribe = onSnapshot(doc(db, 'equipment', id), (docSnap) => {
      if (docSnap.exists()) {
        setEquipment({ id: docSnap.id, ...docSnap.data() } as Equipment);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, [id]);

  if (loading) {
    return <LoadingSpinner />;
  }

  if (!equipment) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600 dark:text-gray-400">Ekipman bulunamadı</p>
        <Link
          to="/equipment"
          className="mt-4 inline-block text-blue-600 dark:text-blue-400 hover:underline"
        >
          Ekipman listesine dön
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <Link
        to="/equipment"
        className="inline-flex items-center space-x-2 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
      >
        <ArrowLeft size={20} />
        <span>Geri</span>
      </Link>

      <div className="bg-white dark:bg-gray-900 rounded-xl p-8 border border-gray-200 dark:border-gray-800">
        <div className="flex items-start space-x-6 mb-6">
          <div
            className={`p-4 rounded-xl ${
              equipment.status === 'kiralamada'
                ? 'bg-orange-100 dark:bg-orange-900/20'
                : 'bg-green-100 dark:bg-green-900/20'
            }`}
          >
            <Camera
              className={`w-12 h-12 ${
                equipment.status === 'kiralamada'
                  ? 'text-orange-600 dark:text-orange-400'
                  : 'text-green-600 dark:text-green-400'
              }`}
            />
          </div>
          <div className="flex-1">
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
              {equipment.name}
            </h1>
            <p className="text-lg text-gray-600 dark:text-gray-400">{equipment.category}</p>
          </div>
          <span
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              equipment.status === 'kiralamada'
                ? 'bg-orange-100 dark:bg-orange-900/20 text-orange-800 dark:text-orange-300'
                : 'bg-green-100 dark:bg-green-900/20 text-green-800 dark:text-green-300'
            }`}
          >
            {equipment.status === 'kiralamada' ? 'Kiralamada' : 'Ofiste'}
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="text-sm font-medium text-gray-600 dark:text-gray-400">
              Stok Miktarı
            </label>
            <p className="mt-1 font-semibold text-gray-900 dark:text-white">
              {equipment.stock}
            </p>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-600 dark:text-gray-400">
              QR Kod
            </label>
            <p className="text-gray-900 dark:text-white mt-1 font-mono text-sm">
              {equipment.qrCodeData || equipment.id}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

