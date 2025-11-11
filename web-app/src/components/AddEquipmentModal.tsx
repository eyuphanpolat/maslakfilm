import { useState } from 'react';
import { collection, addDoc, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../config/firebase';
import toast from 'react-hot-toast';
import { X } from 'lucide-react';

interface AddEquipmentModalProps {
  onClose: () => void;
}

const categories = [
  'Kamera',
  'Lens',
  'Monitör',
  'Ses',
  'Destekleyici',
  'Gimball',
  'Aksesuar',
  'Reji',
  'Işık',
];

export default function AddEquipmentModal({ onClose }: AddEquipmentModalProps) {
  const [name, setName] = useState('');
  const [category, setCategory] = useState('Kamera');
  const [stock, setStock] = useState('1');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!name.trim()) {
      toast.error('Ekipman adı gereklidir');
      return;
    }

    try {
      const stockNum = parseInt(stock) || 1;

      // Kısa QR kod oluştur: Kategori baş harfi + Ekipman isminden 4 harf = 5 harf
      const generateShortQRCode = (category: string, equipmentName: string): string => {
        // Kategori baş harfini al (sayısal ise 'K' kullan)
        let categoryFirst = 'K'; // Varsayılan (Kamera)
        if (category && category.length > 0) {
          // Kategori string ise ilk harfi al, sayısal ise 'K' kullan
          const firstChar = category[0];
          if (/[A-Za-z]/.test(firstChar)) {
            categoryFirst = firstChar.toUpperCase();
          }
        }
        
        // Ekipman ismini temizle: boşlukları kaldır, büyük harfe çevir, özel karakterleri kaldır
        const cleanName = equipmentName
          .replace(/[^a-zA-Z0-9\s]/g, '') // Özel karakterleri kaldır
          .replace(/\s/g, '') // Boşlukları kaldır
          .toUpperCase();
        
        // Ekipman isminden 4 karakter al
        const namePart = cleanName.length >= 4 
          ? cleanName.substring(0, 4) 
          : cleanName.padEnd(4, 'X'); // Eğer 4 karakterden azsa X ile doldur
        
        // Kategori baş harfi + 4 harf = 5 harf
        const qrCode = `${categoryFirst}${namePart}`;
        // Maksimum 5 harf olduğundan emin ol
        return qrCode.length > 5 ? qrCode.substring(0, 5) : qrCode;
      };

      const shortQRCode = generateShortQRCode(category, name.trim());

      const docRef = await addDoc(collection(db, 'equipment'), {
        name: name.trim(),
        category: category,
        serialNumber: null,
        qrCodeData: null,
        status: 'ofiste',
        stock: stockNum,
        currentRentalId: null,
        imageUrl: null,
        createdAt: serverTimestamp(),
      });
      await updateDoc(doc(db, 'equipment', docRef.id), {
        qrCodeData: shortQRCode,
      });

      toast.success('Ekipman eklendi');
      onClose();
    } catch (error: any) {
      // Hata sessizce log edilir
      console.error('Ekipman ekleme hatası:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl max-w-md w-full p-6 relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
        >
          <X size={24} />
        </button>

        <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">Yeni Ekipman</h2>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Ekipman Adı *
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg focus:ring-2 focus:ring-black dark:focus:ring-white focus:border-transparent bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              placeholder="Örn: Sony A7S III"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Kategori
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg focus:ring-2 focus:ring-black dark:focus:ring-white focus:border-transparent bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            >
              {categories.map((cat) => (
                <option key={cat} value={cat}>
                  {cat}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Stok
            </label>
            <input
              type="number"
              value={stock}
              onChange={(e) => setStock(e.target.value)}
              min="1"
              className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg focus:ring-2 focus:ring-black dark:focus:ring-white focus:border-transparent bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            />
          </div>

          <div className="flex space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              İptal
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 px-4 py-2 bg-black dark:bg-white text-white dark:text-black rounded-lg hover:bg-gray-800 dark:hover:bg-gray-200 transition-colors disabled:opacity-50"
            >
              {loading ? 'Ekleniyor...' : 'Ekle'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

