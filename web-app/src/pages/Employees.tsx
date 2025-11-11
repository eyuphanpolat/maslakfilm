import { useEffect, useState } from 'react';
import { collection, onSnapshot, doc, getDoc } from 'firebase/firestore';
import { db, auth } from '../config/firebase';
import { UserCog, Mail, Shield } from 'lucide-react';

interface Employee {
  id: string;
  name: string;
  email: string;
  role?: string;
  isAdmin?: boolean;
}

export default function Employees() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    const checkAdmin = async () => {
      const user = auth.currentUser;
      if (!user) return;

      const adminEmails = ['polathakki@gmail.com', 'eyuphanpolatt@gmail.com'];
      const userEmail = user.email?.toLowerCase().trim();
      
      if (userEmail && adminEmails.includes(userEmail)) {
        setIsAdmin(true);
      } else {
        const userDoc = await getDoc(doc(db, 'users', user.uid));
        if (userDoc.exists()) {
          const data = userDoc.data();
          setIsAdmin(data.role === 'admin' || data.isAdmin === true);
        }
      }
    };

    checkAdmin();

    const q = collection(db, 'users');
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const items: Employee[] = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        if (data.email) {
          items.push({
            id: doc.id,
            name: data.name || data.email.split('@')[0],
            email: data.email,
            role: data.role,
            isAdmin: data.isAdmin,
          });
        }
      });
      setEmployees(items);
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

  if (!isAdmin) {
    return (
      <div className="text-center py-12">
        <Shield className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
          Bu sayfaya erişim yetkiniz yok
        </h3>
        <p className="text-gray-600 dark:text-gray-400">
          Sadece admin kullanıcılar çalışanları görüntüleyebilir
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Çalışanlar</h1>
        <p className="text-gray-600 dark:text-gray-400">Sistem kullanıcıları</p>
      </div>

      {employees.length === 0 ? (
        <div className="text-center py-12">
          <UserCog className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
            Henüz çalışan yok
          </h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {employees.map((employee) => (
            <div
              key={employee.id}
              className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800"
            >
              <div className="flex items-start space-x-4 mb-4">
                <div className="p-3 bg-purple-100 dark:bg-purple-900/20 rounded-lg">
                  <UserCog className="w-6 h-6 text-purple-600 dark:text-purple-400" />
                </div>
                <div className="flex-1">
                  <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                    {employee.name}
                  </h3>
                  {(employee.role === 'admin' || employee.isAdmin) && (
                    <span className="inline-block mt-1 px-2 py-1 bg-purple-100 dark:bg-purple-900/20 text-purple-800 dark:text-purple-300 rounded text-xs font-medium">
                      Admin
                    </span>
                  )}
                </div>
              </div>

              <div className="flex items-center space-x-2 text-sm">
                <Mail className="w-4 h-4 text-gray-500 dark:text-gray-400" />
                <span className="text-gray-900 dark:text-white">{employee.email}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

