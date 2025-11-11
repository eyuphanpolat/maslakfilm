# Debug Rehberi - Beyaz Sayfa Sorunu

## 1. Tarayıcı Console'unu Kontrol Edin

1. Tarayıcıda F12 tuşuna basın (veya sağ tık > İncele)
2. "Console" sekmesine gidin
3. Kırmızı hata mesajlarını kontrol edin
4. Hata mesajlarını not edin

## 2. Yaygın Sorunlar ve Çözümleri

### Firebase Yapılandırma Hatası

Eğer console'da Firebase ile ilgili hata görüyorsanız:

1. Firebase Console'a gidin: https://console.firebase.google.com
2. Projenizi seçin (maslakfilm-f479b)
3. Project Settings > Your apps
4. "Add app" > Web (</>) seçeneğini tıklayın
5. App nickname girin (örn: "maslakfilm-web")
6. "Register app" butonuna tıklayın
7. Yapılandırma bilgilerini kopyalayın
8. `web-app/src/config/firebase.ts` dosyasını açın
9. `appId` değerini güncelleyin

### Module Bulunamadı Hatası

Eğer "Cannot find module" hatası görüyorsanız:

```bash
cd web-app
npm install
```

### Port Zaten Kullanılıyor

Eğer port 3000 zaten kullanılıyorsa:

`vite.config.ts` dosyasında port numarasını değiştirin:

```typescript
server: {
  port: 3001, // veya başka bir port
}
```

## 3. Test Etme

1. Terminal'de `npm run dev` komutunu çalıştırın
2. Tarayıcıda http://localhost:3000 adresine gidin
3. Console'u açık tutun ve hataları kontrol edin

## 4. Hata Mesajını Paylaşın

Eğer sorun devam ediyorsa, console'daki hata mesajını paylaşın.

