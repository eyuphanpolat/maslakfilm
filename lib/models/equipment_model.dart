import 'package:cloud_firestore/cloud_firestore.dart';

// === GÜNCELLENDİ ===
// Kullanıcının tanımına göre sadece iki durum var:
enum EquipmentStatus {
  ofiste,
  kiralamada,
  bilinmeyen // Hata durumu
}

class EquipmentModel {
  final String id; // Firestore döküman ID'si
  final String name; // Örn: "Sony A7S III"
  final String category; // Örn: "Kamera", "Lens"
  final String? serialNumber; // Seri numarası
  final String qrCodeData; // Genellikle 'id' ile aynı olacak
  final EquipmentStatus status; // 'ofiste', 'kiralamada'
  final String? imageUrl; // Ekipman fotoğrafı
  final String? currentRentalId; // Eğer kiralamadaysa, ilgili kira ID'si
  final int stock; // Stok miktarı

  EquipmentModel({
    required this.id,
    required this.name,
    required this.category,
    this.serialNumber,
    required this.qrCodeData,
    required this.status,
    this.imageUrl,
    this.currentRentalId,
    this.stock = 1, // Varsayılan olarak 1
  });

  // === Firestore'dan Veri Okuma (JSON -> Model) ===
  factory EquipmentModel.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    EquipmentStatus currentStatus;
    
    // === GÜNCELLENDİ ===
    // 'bakımda' durumu kaldırıldı.
    switch (data['status'] as String?) {
      case 'ofiste':
        currentStatus = EquipmentStatus.ofiste;
        break;
      case 'kiralamada': // 'kiralandı' yerine 'kiralamada' olarak güncelledim
        currentStatus = EquipmentStatus.kiralamada;
        break;
      default:
        currentStatus = EquipmentStatus.bilinmeyen;
    }

    return EquipmentModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      serialNumber: data['serialNumber'],
      qrCodeData: data['qrCodeData'] ?? doc.id,
      status: currentStatus,
      imageUrl: data['imageUrl'],
      currentRentalId: data['currentRentalId'],
      stock: data['stock'] as int? ?? 1,
    );
  }

  // === Firestore'a Veri Yazma (Model -> JSON) ===
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'serialNumber': serialNumber,
      'qrCodeData': qrCodeData,
      'status': status.name, // enum'u string'e çevirir (örn: 'ofiste' veya 'kiralamada')
      'imageUrl': imageUrl,
      'currentRentalId': currentRentalId,
      'stock': stock,
    };
  }
}