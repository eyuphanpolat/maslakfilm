# MF-ETS Web Uygulaması

Maslak Film Ekipman Takip Sistemi - Web versiyonu

## Kurulum

1. Bağımlılıkları yükleyin:
```bash
cd web-app
npm install
```

2. Firebase yapılandırmasını güncelleyin:
- Firebase Console'a gidin (https://console.firebase.google.com)
- Projenizi seçin (maslakfilm-f479b)
- Project Settings > Your apps > Web app ekleyin
- Yeni oluşturulan web app'in yapılandırma bilgilerini alın
- `src/config/firebase.ts` dosyasındaki `appId` değerini güncelleyin
- Gerekirse diğer Firebase ayarlarını da kontrol edin

3. Geliştirme sunucusunu başlatın:
```bash
npm run dev
```
Uygulama http://localhost:3000 adresinde açılacaktır.

4. Production build:
```bash
npm run build
```
Build dosyaları `dist` klasörüne oluşturulacaktır.

## Özellikler

- ✅ Firebase Authentication
- ✅ Ekipman yönetimi
- ✅ Kiralama takibi
- ✅ Teslim alım işlemleri
- ✅ Müşteri yönetimi
- ✅ Çalışan yönetimi (Admin)
- ✅ QR kod tarama (Web kamerası)
- ✅ Dark mode desteği
- ✅ Responsive tasarım

## Teknolojiler

- React 18
- TypeScript
- Vite
- Tailwind CSS
- Firebase (Auth, Firestore)
- React Router
- HTML5 QR Code Scanner

