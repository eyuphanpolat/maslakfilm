import { useEffect, useState } from 'react';
import { collection, query, where, onSnapshot, Timestamp, updateDoc, doc } from 'firebase/firestore';
import { db } from '../config/firebase';
import { format, isToday } from 'date-fns';
import { CheckCircle, Calendar, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';

interface Rental {
  id: string;
  equipmentName: string;
  customerName: string;
  location: string;
  plannedReturnDate?: Timestamp;
  equipmentId?: string;
}

export default function Deliveries() {
  const [rentals, setRentals] = useState<Rental[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'rentals'), where('status', '==', 'aktif'));

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const items: Rental[] = [];
      snapshot.forEach((doc) => {
        items.push({ id: doc.id, ...doc.data() } as Rental);
      });
      
      // Sort by planned return date
      items.sort((a, b) => {
        if (!a.plannedReturnDate && !b.plannedReturnDate) return 0;
        if (!a.plannedReturnDate) return 1;
        if (!b.plannedReturnDate) return -1;
        return a.plannedReturnDate.toMillis() - b.plannedReturnDate.toMillis();
      });

      setRentals(items);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleDelivery = async (rentalId: string, equipmentId?: string) => {
    if (!confirm('Bu kiralama kaydını teslim almak istediğinizden emin misiniz?')) {
      return;
    }

    try {
      // Update rental status
      await updateDoc(doc(db, 'rentals', rentalId), {
        status: 'tamamlandı',
        actualReturnDate: Timestamp.now(),
      });

      // Update equipment status if equipmentId is available
      if (equipmentId) {
        await updateDoc(doc(db, 'equipment', equipmentId), {
          status: 'ofiste',
          currentRentalId: null,
        });
      }

      toast.success('Teslim alındı');
    } catch (error: any) {
      // Hata sessizce log edilir
      console.error('Teslim alım hatası:', error);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-black dark:border-white"></div>
      </div>
    );
  }

  const todayRentals = rentals.filter((rental) => {
    if (!rental.plannedReturnDate) return false;
    return isToday(rental.plannedReturnDate.toDate());
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Teslim Alım</h1>
        <p className="text-gray-600 dark:text-gray-400">Kiralama kayıtlarını teslim alın</p>
      </div>

      {todayRentals.length > 0 && (
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl p-4">
          <div className="flex items-center space-x-3">
            <AlertCircle className="w-6 h-6 text-red-600 dark:text-red-400" />
            <div>
              <h3 className="font-semibold text-red-900 dark:text-red-300">
                Bugün {todayRentals.length} kiralama teslim alınacak
              </h3>
            </div>
          </div>
        </div>
      )}

      {rentals.length === 0 ? (
        <div className="text-center py-12">
          <CheckCircle className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
            Teslim alınacak kiralama yok
          </h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {rentals.map((rental) => {
            const isDueToday = rental.plannedReturnDate && isToday(rental.plannedReturnDate.toDate());
            const isOverdue = rental.plannedReturnDate && rental.plannedReturnDate.toDate() < new Date() && !isDueToday;

            return (
              <div
                key={rental.id}
                className={`bg-white dark:bg-gray-900 rounded-xl p-6 border ${
                  isDueToday
                    ? 'border-red-300 dark:border-red-700 bg-red-50 dark:bg-red-900/20'
                    : isOverdue
                    ? 'border-orange-300 dark:border-orange-700'
                    : 'border-gray-200 dark:border-gray-800'
                }`}
              >
                <div className="flex items-start justify-between mb-4">
                  <h3 className="text-xl font-bold text-gray-900 dark:text-white">
                    {rental.equipmentName}
                  </h3>
                  {isDueToday && (
                    <span className="px-3 py-1 bg-red-100 dark:bg-red-900/20 text-red-800 dark:text-red-300 rounded-lg text-sm font-medium">
                      Bugün
                    </span>
                  )}
                </div>

                <div className="space-y-2 mb-4">
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    <span className="font-medium">Müşteri:</span> {rental.customerName}
                  </p>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    <span className="font-medium">Lokasyon:</span> {rental.location}
                  </p>
                  {rental.plannedReturnDate && (
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      <span className="font-medium">Planlanan Dönüş:</span>{' '}
                      {format(rental.plannedReturnDate.toDate(), 'dd.MM.yyyy')}
                    </p>
                  )}
                </div>

                <button
                  onClick={() => handleDelivery(rental.id, rental.equipmentId)}
                  className="w-full flex items-center justify-center space-x-2 px-4 py-2 bg-black dark:bg-white text-white dark:text-black rounded-lg hover:bg-gray-800 dark:hover:bg-gray-200 transition-colors"
                >
                  <CheckCircle size={20} />
                  <span>Teslim Al</span>
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

