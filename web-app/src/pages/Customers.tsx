import { useEffect, useState } from 'react';
import { collection, onSnapshot, orderBy } from 'firebase/firestore';
import { db } from '../config/firebase';
import { Users, Phone, Mail } from 'lucide-react';

interface Customer {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  company?: string;
}

export default function Customers() {
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = collection(db, 'customers');
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const items: Customer[] = [];
      snapshot.forEach((doc) => {
        items.push({ id: doc.id, ...doc.data() } as Customer);
      });
      items.sort((a, b) => a.name.localeCompare(b.name));
      setCustomers(items);
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
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Müşteriler</h1>
        <p className="text-gray-600 dark:text-gray-400">Tüm müşteri kayıtları</p>
      </div>

      {customers.length === 0 ? (
        <div className="text-center py-12">
          <Users className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
            Henüz müşteri yok
          </h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {customers.map((customer) => (
            <div
              key={customer.id}
              className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800"
            >
              <div className="flex items-start space-x-4 mb-4">
                <div className="p-3 bg-blue-100 dark:bg-blue-900/20 rounded-lg">
                  <Users className="w-6 h-6 text-blue-600 dark:text-blue-400" />
                </div>
                <div className="flex-1">
                  <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                    {customer.name}
                  </h3>
                  {customer.company && (
                    <p className="text-sm text-gray-600 dark:text-gray-400">{customer.company}</p>
                  )}
                </div>
              </div>

              <div className="space-y-2">
                {customer.email && (
                  <div className="flex items-center space-x-2 text-sm">
                    <Mail className="w-4 h-4 text-gray-500 dark:text-gray-400" />
                    <span className="text-gray-900 dark:text-white">{customer.email}</span>
                  </div>
                )}
                {customer.phone && (
                  <div className="flex items-center space-x-2 text-sm">
                    <Phone className="w-4 h-4 text-gray-500 dark:text-gray-400" />
                    <span className="text-gray-900 dark:text-white">{customer.phone}</span>
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

