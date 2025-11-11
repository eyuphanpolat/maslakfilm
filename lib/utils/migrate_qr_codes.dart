import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MigrateQRCodes {
  // QR kod oluştur: Kategori baş harfi + Ekipman isminden 4 harf = 5 harf
  static String generateShortQRCode(String category, String name) {
    // Kategori baş harfini al (sayısal ise 'K' kullan)
    String categoryFirst = 'K'; // Varsayılan (Kamera)
    if (category.isNotEmpty) {
      // Kategori string ise ilk harfi al, sayısal ise 'K' kullan
      final firstChar = category[0];
      if (RegExp(r'[A-Za-z]').hasMatch(firstChar)) {
        categoryFirst = firstChar.toUpperCase();
      }
    }
    
    // Ekipman ismini temizle: boşlukları kaldır, büyük harfe çevir, özel karakterleri kaldır
    String cleanName = name
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '') // Özel karakterleri kaldır
        .replaceAll(' ', '') // Boşlukları kaldır
        .toUpperCase();
    
    // Ekipman isminden 4 karakter al
    String namePart = cleanName.length >= 4 
        ? cleanName.substring(0, 4) 
        : cleanName.padRight(4, 'X'); // Eğer 4 karakterden azsa X ile doldur
    
    // Kategori baş harfi + 4 harf = 5 harf
    final qrCode = '$categoryFirst$namePart';
    // Maksimum 5 harf olduğundan emin ol
    return qrCode.length > 5 ? qrCode.substring(0, 5) : qrCode;
  }

  // Kategori adlarını güncelle (Monitör/Kayıt Cihazı -> Monitör)
  static Future<void> migrateCategoryNames() async {
    try {
      debugPrint('🔄 Kategori adı migration başlatılıyor...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('equipment')
          .where('category', isEqualTo: 'Monitör/Kayıt Cihazı')
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ Güncellenecek kategori bulunamadı');
        return;
      }
      
      int updated = 0;
      
      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'category': 'Monitör',
        });
        
        updated++;
        debugPrint('✅ ${doc.id}: Kategori "Monitör/Kayıt Cihazı" -> "Monitör"');
      }
      
      debugPrint('✅ Kategori migration tamamlandı!');
      debugPrint('   Güncellenen: $updated');
    } catch (e) {
      debugPrint('❌ Kategori migration hatası: $e');
      rethrow;
    }
  }

  // Tüm ekipmanların QR kodlarını güncelle
  static Future<void> migrateAllQRCodes() async {
    try {
      debugPrint('🔄 QR kod migration başlatılıyor...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('equipment')
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ Güncellenecek ekipman bulunamadı');
        return;
      }
      
      int updated = 0;
      int skipped = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        final category = data['category'] as String? ?? 'Diğer';
        final currentQRCode = data['qrCodeData'] as String? ?? '';
        
        // Yeni QR kod oluştur
        final newQRCode = generateShortQRCode(category, name);
        
        // Eğer QR kod zaten 5 harf veya daha kısa ise ve doğru formattaysa atla
        if (currentQRCode.length == 5 && currentQRCode == newQRCode) {
          skipped++;
          continue;
        }
        
        // QR kodunu güncelle
        await doc.reference.update({
          'qrCodeData': newQRCode,
        });
        
        updated++;
        debugPrint('✅ ${doc.id}: "$currentQRCode" -> "$newQRCode"');
      }
      
      debugPrint('✅ Migration tamamlandı!');
      debugPrint('   Güncellenen: $updated');
      debugPrint('   Atlanan: $skipped');
      debugPrint('   Toplam: ${snapshot.docs.length}');
    } catch (e) {
      debugPrint('❌ Migration hatası: $e');
      rethrow;
    }
  }
}

