import { useEffect, useState } from 'react';
import { collection, query, where, getDocs, onSnapshot, Timestamp } from 'firebase/firestore';
import { db } from '../config/firebase';
import { Link } from 'react-router-dom';
import { Camera, FileText, CheckCircle, Users, AlertCircle, Package } from 'lucide-react';

interface SummaryCardProps {
  title: string;
  value: number | string;
  icon: any;
  color: string;
  link?: string;
}

function SummaryCard({ title, value, icon: Icon, color, link }: SummaryCardProps) {
  const content = (
    <div className="bg-white dark:bg-gray-900 rounded-xl p-6 shadow-sm border border-gray-200 dark:border-gray-800 hover:shadow-md transition-shadow">
      <div className="flex items-center justify-between mb-4">
        <div className={`p-3 rounded-lg ${color}`}>
          <Icon className="w-6 h-6 text-white" />
        </div>
        <div className="text-right">
          <div className="text-3xl font-bold text-gray-900 dark:text-white">{value}</div>
          <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">{title}</div>
        </div>
      </div>
    </div>
  );

  if (link) {
    return <Link to={link}>{content}</Link>;
  }

  return content;
}

export default function Dashboard() {
  const [stats, setStats] = useState({
    totalEquipment: 0,
    rentedEquipment: 0,
    activeRentals: 0,
    dueToday: 0,
    totalCustomers: 0,
  });
  const [notifications, setNotifications] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
    
    // Gerçek zamanlı güncelleme için rentals stream'i dinle
    const rentalsQuery = query(
      collection(db, 'rentals'),
      where('status', '==', 'aktif')
    );
    
    const unsubscribeRentals = onSnapshot(rentalsQuery, (snapshot) => {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const rentals = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));
      
      const dueToday = rentals.filter((rental: any) => {
        const plannedReturn = rental.plannedReturnDate?.toDate();
        if (!plannedReturn) return false;
        return (
          plannedReturn.getFullYear() === today.getFullYear() &&
          plannedReturn.getMonth() === today.getMonth() &&
          plannedReturn.getDate() === today.getDate()
        );
      });
      
      // Notifications güncelle
      const notificationsList: any[] = [];
      
      if (dueToday.length > 0) {
        notificationsList.push({
          type: 'warning',
          title: `${dueToday.length} Kiralama Bugün Teslim Alınacak`,
          items: dueToday.slice(0, 3).map((r: any) => ({
            equipment: r.equipmentName,
            customer: r.customerName,
          })),
        });
      }
      
      setNotifications(notificationsList);
      
      // Stats güncelle
      setStats(prev => ({
        ...prev,
        activeRentals: rentals.length,
        dueToday: dueToday.length,
      }));
    });
    
    return () => {
      unsubscribeRentals();
    };
  }, []);

  const loadData = async () => {
    try {
      // Equipment stats
      const equipmentSnapshot = await getDocs(collection(db, 'equipment'));
      const equipment = equipmentSnapshot.docs.map(doc => doc.data());
      
      const rentedEquipment = equipment.filter(eq => eq.status === 'kiralamada').length;

      // Active rentals
      const rentalsQuery = query(
        collection(db, 'rentals'),
        where('status', '==', 'aktif')
      );
      const rentalsSnapshot = await getDocs(rentalsQuery);
      const rentals = rentalsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      // Due today
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const dueToday = rentals.filter((rental: any) => {
        const plannedReturn = rental.plannedReturnDate?.toDate();
        if (!plannedReturn) return false;
        return (
          plannedReturn.getFullYear() === today.getFullYear() &&
          plannedReturn.getMonth() === today.getMonth() &&
          plannedReturn.getDate() === today.getDate()
        );
      });

      // Customers
      const customersSnapshot = await getDocs(collection(db, 'customers'));

      // Low stock equipment (stok 0 olanlar)
      const lowStock = equipment.filter(
        (eq: any) => eq.stock <= 0
      );

      setStats({
        totalEquipment: equipment.length,
        rentedEquipment,
        activeRentals: rentals.length,
        dueToday: dueToday.length,
        totalCustomers: customersSnapshot.docs.length,
      });

      // Notifications
      const notificationsList: any[] = [];
      
      if (dueToday.length > 0) {
        notificationsList.push({
          type: 'warning',
          title: `${dueToday.length} Kiralama Bugün Teslim Alınacak`,
          items: dueToday.slice(0, 3).map((r: any) => ({
            equipment: r.equipmentName,
            customer: r.customerName,
          })),
        });
      }

      if (lowStock.length > 0) {
        notificationsList.push({
          type: 'info',
          title: 'Düşük Stok Uyarısı',
          items: lowStock.slice(0, 3).map((eq: any) => ({
            name: eq.name,
            stock: eq.stock,
          })),
        });
      }

      setNotifications(notificationsList);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setLoading(false);
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
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Ana Sayfa</h1>
        <p className="text-gray-600 dark:text-gray-400">Sistem özeti ve bildirimler</p>
      </div>

      {/* Notifications */}
      {notifications.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-white">Bildirimler</h2>
          {notifications.map((notif, idx) => (
            <div
              key={idx}
              className={`rounded-xl p-4 border ${
                notif.type === 'warning'
                  ? 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800'
                  : 'bg-orange-50 dark:bg-orange-900/20 border-orange-200 dark:border-orange-800'
              }`}
            >
              <div className="flex items-start space-x-3">
                <AlertCircle
                  className={`w-6 h-6 mt-0.5 ${
                    notif.type === 'warning'
                      ? 'text-red-600 dark:text-red-400'
                      : 'text-orange-600 dark:text-orange-400'
                  }`}
                />
                <div className="flex-1">
                  <h3
                    className={`font-semibold mb-2 ${
                      notif.type === 'warning'
                        ? 'text-red-900 dark:text-red-300'
                        : 'text-orange-900 dark:text-orange-300'
                    }`}
                  >
                    {notif.title}
                  </h3>
                  <ul className="space-y-1">
                    {notif.items.map((item: any, itemIdx: number) => (
                      <li
                        key={itemIdx}
                        className="text-sm text-gray-700 dark:text-gray-300"
                      >
                        • {item.equipment || item.name} {item.customer && `- ${item.customer}`}
                        {item.stock !== undefined && ` (Stok: ${item.stock})`}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {notifications.length === 0 && (
        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-xl p-4">
          <div className="flex items-center space-x-3">
            <CheckCircle className="w-6 h-6 text-green-600 dark:text-green-400" />
            <p className="text-green-900 dark:text-green-300">
              Bugün teslim alınacak kiralama yok
            </p>
          </div>
        </div>
      )}

      {/* Summary Cards */}
      <div>
        <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-4">Özet</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
          <SummaryCard
            title="Toplam Ekipman"
            value={stats.totalEquipment}
            icon={Camera}
            color="bg-blue-500"
            link="/equipment"
          />
          <SummaryCard
            title="Kiralamada"
            value={stats.rentedEquipment}
            icon={Package}
            color="bg-orange-500"
            link="/equipment"
          />
          <SummaryCard
            title="Aktif Kiralama"
            value={stats.activeRentals}
            icon={FileText}
            color="bg-green-500"
            link="/rentals"
          />
          <SummaryCard
            title="Bugün Teslim"
            value={stats.dueToday}
            icon={CheckCircle}
            color="bg-red-500"
            link="/deliveries"
          />
          <SummaryCard
            title="Toplam Müşteri"
            value={stats.totalCustomers}
            icon={Users}
            color="bg-purple-500"
            link="/customers"
          />
        </div>
      </div>
    </div>
  );
}

