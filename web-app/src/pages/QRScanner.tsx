import { useEffect, useRef, useState } from 'react';
import { Html5Qrcode } from 'html5-qrcode';
import { useNavigate } from 'react-router-dom';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '../config/firebase';
import { ArrowLeft, QrCode } from 'lucide-react';
import toast from 'react-hot-toast';

export default function QRScanner() {
  const [scanning, setScanning] = useState(false);
  const [scannedCode, setScannedCode] = useState<string | null>(null);
  const scannerRef = useRef<Html5Qrcode | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    return () => {
      if (scannerRef.current) {
        scannerRef.current.stop().catch(() => {});
      }
    };
  }, []);

  const startScanning = async () => {
    try {
      const scanner = new Html5Qrcode('qr-reader');
      scannerRef.current = scanner;

      await scanner.start(
        { facingMode: 'environment' },
        {
          fps: 10,
          qrbox: { width: 250, height: 250 },
        },
        (decodedText) => {
          handleScanResult(decodedText);
        },
        (errorMessage) => {
          // Ignore scanning errors
        }
      );

      setScanning(true);
    } catch (error: any) {
      toast.error('Kamera erişimi hatası: ' + error.message);
    }
  };

  const stopScanning = async () => {
    if (scannerRef.current) {
      try {
        await scannerRef.current.stop();
        scannerRef.current.clear();
      } catch (error) {
        // Ignore stop errors
      }
      scannerRef.current = null;
    }
    setScanning(false);
  };

  const handleScanResult = async (qrCodeData: string) => {
    setScannedCode(qrCodeData);
    await stopScanning();

    try {
      // Önce qrCodeData ile arama yap (kısa kodlar için)
      const { collection, query, where, getDocs } = await import('firebase/firestore');
      const q = query(collection(db, 'equipment'), where('qrCodeData', '==', qrCodeData));
      const snapshot = await getDocs(q);
      
      let equipmentData: any = null;
      let equipmentId: string | null = null;
      
      if (!snapshot.empty) {
        equipmentId = snapshot.docs[0].id;
        equipmentData = snapshot.docs[0].data();
      } else {
        // Eğer qrCodeData ile bulunamazsa, doküman ID ile ara (eski veriler için)
        const equipmentDoc = await getDoc(doc(db, 'equipment', qrCodeData));
        
        if (equipmentDoc.exists()) {
          equipmentId = equipmentDoc.id;
          equipmentData = equipmentDoc.data();
        } else {
          toast.error('Ekipman bulunamadı');
          return;
        }
      }

      // Stok kontrolü (kiralama için)
      if (equipmentData && equipmentData.stock !== undefined && equipmentData.stock <= 0) {
        toast.error(`⚠️ ${equipmentData.name || 'Ekipman'} - Stokta yok (Stok: ${equipmentData.stock})`, {
          duration: 4000,
        });
        return;
      }

      toast.success('Ekipman bulundu!');
      navigate(`/equipment/${equipmentId}`);
    } catch (error: any) {
      // Hata sessizce log edilir
      console.error('QR tarama hatası:', error);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center space-x-4">
        <button
          onClick={() => navigate(-1)}
          className="text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
        >
          <ArrowLeft size={24} />
        </button>
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">QR Kod Tarayıcı</h1>
          <p className="text-gray-600 dark:text-gray-400">Ekipman QR kodunu tarayın</p>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-800">
        <div id="qr-reader" className="w-full max-w-md mx-auto mb-4"></div>

        <div className="flex justify-center space-x-4">
          {!scanning ? (
            <button
              onClick={startScanning}
              className="flex items-center space-x-2 px-6 py-3 bg-black dark:bg-white text-white dark:text-black rounded-lg hover:bg-gray-800 dark:hover:bg-gray-200 transition-colors"
            >
              <QrCode size={20} />
              <span>Tarayıcıyı Başlat</span>
            </button>
          ) : (
            <button
              onClick={stopScanning}
              className="flex items-center space-x-2 px-6 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
            >
              <span>Durdur</span>
            </button>
          )}
        </div>

        {scannedCode && (
          <div className="mt-4 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
            <p className="text-sm text-gray-600 dark:text-gray-400">Taranan Kod:</p>
            <p className="font-mono text-sm text-gray-900 dark:text-white">{scannedCode}</p>
          </div>
        )}
      </div>
    </div>
  );
}


