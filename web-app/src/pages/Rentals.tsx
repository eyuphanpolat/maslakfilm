import { useEffect, useState } from 'react';
import { collection, query, where, orderBy, onSnapshot, Timestamp } from 'firebase/firestore';
import { db } from '../config/firebase';
import { format } from 'date-fns';
import { FileText, User, MapPin, Calendar, Clock } from 'lucide-react';

interface Rental {
  id: string;
  equipmentName: string;
  customerName: string;
  location: string;
  startDate?: Timestamp;
  plannedReturnDate?: Timestamp;
  createdByName?: string;
  createdByEmail?: string;
}

export default function Rentals() {
  const [rentals, setRentals] = useState<Rental[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(
      collection(db, 'rentals'),
      where('status', '==', 'aktif'),
      orderBy('startDate', 'desc')
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const items: Rental[] = [];
      snapshot.forEach((doc) => {
        items.push({ id: doc.id, ...doc.data() } as Rental);
      });
      setRentals(items);
      setLoading(false);
    }, (error) => {
      console.error('Error loading rentals:', error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-black dark:border-white"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Kiralama</h1>
        <p className="text-gray-600 dark:text-gray-400">Aktif kiralama kayıtları</p>
      </div>

      {rentals.length === 0 ? (
        <div className="text-center py-12">
          <FileText className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
            Aktif kiralama yok
          </h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {rentals.map((rental) => (
            <div
              key={rental.id}
              className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800"
            >
              <div className="flex items-start justify-between mb-4">
                <h3 className="text-xl font-bold text-gray-900 dark:text-white">
                  {rental.equipmentName}
                </h3>
                <span className="px-3 py-1 bg-green-100 dark:bg-green-900/20 text-green-800 dark:text-green-300 rounded-lg text-sm font-medium">
                  Aktif
                </span>
              </div>

              <div className="space-y-3">
                <div className="flex items-center space-x-3 text-sm">
                  <User className="w-5 h-5 text-gray-500 dark:text-gray-400" />
                  <div>
                    <span className="text-gray-600 dark:text-gray-400">Müşteri: </span>
                    <span className="text-gray-900 dark:text-white font-medium">
                      {rental.customerName}
                    </span>
                  </div>
                </div>

                <div className="flex items-center space-x-3 text-sm">
                  <MapPin className="w-5 h-5 text-gray-500 dark:text-gray-400" />
                  <div>
                    <span className="text-gray-600 dark:text-gray-400">Lokasyon: </span>
                    <span className="text-gray-900 dark:text-white">{rental.location}</span>
                  </div>
                </div>

                {rental.startDate && (
                  <div className="flex items-center space-x-3 text-sm">
                    <Calendar className="w-5 h-5 text-gray-500 dark:text-gray-400" />
                    <div>
                      <span className="text-gray-600 dark:text-gray-400">Başlangıç: </span>
                      <span className="text-gray-900 dark:text-white">
                        {format(rental.startDate.toDate(), 'dd.MM.yyyy')}
                      </span>
                    </div>
                  </div>
                )}

                {rental.plannedReturnDate && (
                  <div className="flex items-center space-x-3 text-sm">
                    <Clock className="w-5 h-5 text-gray-500 dark:text-gray-400" />
                    <div>
                      <span className="text-gray-600 dark:text-gray-400">Planlanan Dönüş: </span>
                      <span className="text-gray-900 dark:text-white">
                        {format(rental.plannedReturnDate.toDate(), 'dd.MM.yyyy')}
                      </span>
                    </div>
                  </div>
                )}

                {(rental.createdByName || rental.createdByEmail) && (
                  <div className="flex items-center space-x-3 text-sm pt-2 border-t border-gray-200 dark:border-gray-800">
                    <span className="text-gray-600 dark:text-gray-400">Kiralamayı Yapan: </span>
                    <span className="text-gray-900 dark:text-white">
                      {rental.createdByName || rental.createdByEmail}
                    </span>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

