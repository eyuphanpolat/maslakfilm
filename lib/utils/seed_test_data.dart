import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SeedTestData {
  static Future<void> seedAll({bool force = false}) async {
    try {
      // Eğer force true değilse, mevcut verileri kontrol et
      if (!force) {
        final equipmentSnapshot = await FirebaseFirestore.instance
            .collection('equipment')
            .limit(1)
            .get();

        if (equipmentSnapshot.docs.isNotEmpty) {
          // Eğer veri varsa, ekleme yapma
          debugPrint('ℹ️ Veriler zaten mevcut. Zorla eklemek için force=true kullanın.');
          return;
        }
      } else {
        // Force true ise, önce mevcut test verilerini temizle
        await clearAll();
      }

      // Müşteriler ekle
      final customers = await _seedCustomers();
      
      // Çalışanlar ekle
      await _seedEmployees();
      
      // Ekipmanlar ekle
      final equipment = await _seedEquipment();
      
      // Kiralamalar ekle (bazı ekipmanları kiralamada olarak işaretle)
      await _seedRentals(customers, equipment);
      
      debugPrint('✅ Tüm test verileri başarıyla eklendi!');
    } catch (e) {
      debugPrint('❌ Test verileri eklenirken hata: $e');
      rethrow;
    }
  }

  static Future<List<String>> _seedCustomers() async {
    final customers = [
      {
        'name': 'Ahmet Yılmaz',
        'email': 'ahmet.yilmaz@example.com',
        'phone': '+90 555 123 4567',
        'address': 'İstanbul, Kadıköy, Moda Mahallesi, No:15',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Ayşe Demir',
        'email': 'ayse.demir@example.com',
        'phone': '+90 555 234 5678',
        'address': 'Ankara, Çankaya, Kızılay Mahallesi, No:42',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Mehmet Kaya',
        'email': 'mehmet.kaya@example.com',
        'phone': '+90 555 345 6789',
        'address': 'İzmir, Konak, Alsancak Mahallesi, No:78',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Zeynep Şahin',
        'email': 'zeynep.sahin@example.com',
        'phone': '+90 555 456 7890',
        'address': 'Bursa, Nilüfer, Çekirge Mahallesi, No:23',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Can Öztürk',
        'email': 'can.ozturk@example.com',
        'phone': '+90 555 567 8901',
        'address': 'Antalya, Muratpaşa, Konyaaltı Mahallesi, No:56',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final customerIds = <String>[];
    for (final customer in customers) {
      final docRef = await FirebaseFirestore.instance
          .collection('customers')
          .add(customer);
      customerIds.add(docRef.id);
    }
    debugPrint('✅ ${customers.length} müşteri eklendi');
    return customerIds;
  }

  static Future<List<String>> _seedEmployees() async {
    final employees = [
      {
        'name': 'Ali Veli',
        'email': 'ali.veli@maslakfilm.com',
        'phone': '+90 555 111 2222',
        'position': 'Ekipman Yöneticisi',
        'department': 'Operasyon',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Fatma Yıldız',
        'email': 'fatma.yildiz@maslakfilm.com',
        'phone': '+90 555 222 3333',
        'position': 'Kiralama Uzmanı',
        'department': 'Satış',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Murat Çelik',
        'email': 'murat.celik@maslakfilm.com',
        'phone': '+90 555 333 4444',
        'position': 'Teknisyen',
        'department': 'Bakım',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Selin Arslan',
        'email': 'selin.arslan@maslakfilm.com',
        'phone': '+90 555 444 5555',
        'position': 'Müşteri Temsilcisi',
        'department': 'Satış',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final employeeIds = <String>[];
    for (final employee in employees) {
      final docRef = await FirebaseFirestore.instance
          .collection('employees')
          .add(employee);
      employeeIds.add(docRef.id);
    }
    debugPrint('✅ ${employees.length} çalışan eklendi');
    return employeeIds;
  }

  static Future<List<String>> _seedEquipment() async {
    final equipment = [
      {
        'name': 'Sony A7S III',
        'category': 'Kamera',
        'serialNumber': 'SN-A7S3-2024-001',
        'qrCodeData': 'eq-a7s3-001',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Canon EOS R5',
        'category': 'Kamera',
        'serialNumber': 'SN-CAN-R5-2024-002',
        'qrCodeData': 'eq-canon-r5-002',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Sigma 24-70mm f/2.8',
        'category': 'Lens',
        'serialNumber': 'SN-SIGMA-2470-2024-003',
        'qrCodeData': 'eq-sigma-2470-003',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Canon RF 70-200mm f/2.8',
        'category': 'Lens',
        'serialNumber': 'SN-CAN-RF-70200-2024-004',
        'qrCodeData': 'eq-canon-70200-004',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Sachtler Flowtech 75',
        'category': 'Tripod',
        'serialNumber': 'SN-SACHT-FT75-2024-005',
        'qrCodeData': 'eq-sachtler-ft75-005',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Manfrotto 190XPRO',
        'category': 'Tripod',
        'serialNumber': 'SN-MANF-190X-2024-006',
        'qrCodeData': 'eq-manfrotto-190x-006',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'DJI Ronin S',
        'category': 'Gimbal',
        'serialNumber': 'SN-DJI-RONIN-S-2024-007',
        'qrCodeData': 'eq-dji-ronin-s-007',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Atomos Ninja V',
        'category': 'Monitör',
        'serialNumber': 'SN-ATOMOS-NINJA5-2024-008',
        'qrCodeData': 'eq-atomos-ninja5-008',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'RODE VideoMic Pro+',
        'category': 'Mikrofon',
        'serialNumber': 'SN-RODE-VMPRO+2024-009',
        'qrCodeData': 'eq-rode-vmpro-009',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Sennheiser MKH 416',
        'category': 'Mikrofon',
        'serialNumber': 'SN-SENN-MKH416-2024-010',
        'qrCodeData': 'eq-sennheiser-mkh416-010',
        'status': 'ofiste',
        'imageUrl': null,
        'currentRentalId': null,
        'stock': 2,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final equipmentIds = <String>[];
    for (final eq in equipment) {
      final docRef = await FirebaseFirestore.instance
          .collection('equipment')
          .add(eq);
      equipmentIds.add(docRef.id);
    }
    debugPrint('✅ ${equipment.length} ekipman eklendi');
    return equipmentIds;
  }

  static Future<void> _seedRentals(
    List<String> customerIds,
    List<String> equipmentIds,
  ) async {
    if (customerIds.isEmpty || equipmentIds.length < 2) {
      return;
    }

    final now = DateTime.now();
    final rentals = [
      {
        'equipmentId': equipmentIds[0],
        'equipmentName': 'Sony A7S III',
        'customerId': customerIds[0],
        'customerName': 'Ahmet Yılmaz',
        'location': 'İstanbul Film Seti - Kadıköy',
        'price': 2500.0,
        'startDate': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        'plannedReturnDate': Timestamp.fromDate(now.add(const Duration(days: 4))),
        'status': 'aktif',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'equipmentId': equipmentIds[2],
        'equipmentName': 'Sigma 24-70mm f/2.8',
        'customerId': customerIds[1],
        'customerName': 'Ayşe Demir',
        'location': 'Ankara Stüdyo Çekimi',
        'price': 800.0,
        'startDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'plannedReturnDate': Timestamp.fromDate(now.add(const Duration(days: 6))),
        'status': 'aktif',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'equipmentId': equipmentIds[6],
        'equipmentName': 'DJI Ronin S',
        'customerId': customerIds[2],
        'customerName': 'Mehmet Kaya',
        'location': 'İzmir Düğün Çekimi',
        'price': 1200.0,
        'startDate': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
        'plannedReturnDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'actualReturnDate': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'status': 'tamamlandi',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final rental in rentals) {
      final rentalRef = await FirebaseFirestore.instance
          .collection('rentals')
          .add(rental);

      // Aktif kiralama varsa ekipmanı kiralamada olarak işaretle
      if (rental['status'] == 'aktif') {
        final equipmentId = rental['equipmentId'] as String;
        await FirebaseFirestore.instance
            .collection('equipment')
            .doc(equipmentId)
            .update({
          'status': 'kiralamada',
          'currentRentalId': rentalRef.id,
        });
      }
    }
    debugPrint('✅ ${rentals.length} kiralama eklendi (2 aktif, 1 tamamlanmış)');
  }

  // Test verilerini temizleme fonksiyonu
  static Future<void> clearAll() async {
    try {
      final collections = ['equipment', 'rentals', 'customers', 'employees'];
      
      for (final collection in collections) {
        final snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .get();
        
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      debugPrint('✅ Tüm test verileri temizlendi');
    } catch (e) {
      debugPrint('❌ Test verileri temizlenirken hata: $e');
      rethrow;
    }
  }
}

