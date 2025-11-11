import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  // Bugün teslim alınacak kiralamaları kontrol et
  static Future<List<Map<String, dynamic>>> getDueTodayRentals() async {
    try {
      final now = DateTime.now();

      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('status', isEqualTo: 'aktif')
          .get();

      final dueToday = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();

        if (plannedReturn != null) {
          if (plannedReturn.year == now.year &&
              plannedReturn.month == now.month &&
              plannedReturn.day == now.day) {
            dueToday.add({
              'id': doc.id,
              'equipmentName': data['equipmentName'] ?? 'Bilinmiyor',
              'customerName': data['customerName'] ?? 'Bilinmiyor',
              'plannedReturnDate': plannedReturn,
            });
          }
        }
      }

      return dueToday;
    } catch (e) {
      debugPrint('Teslim tarihi kontrol hatası: $e');
      return [];
    }
  }

  // Düşük stoklu ekipmanları kontrol et (stok 0 olanlar)
  static Future<List<Map<String, dynamic>>> getLowStockEquipment() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('equipment')
          .get();

      final lowStock = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final stock = data['stock'] as int? ?? 1;

        if (stock <= 0) {
          lowStock.add({
            'id': doc.id,
            'name': data['name'] ?? 'Bilinmiyor',
            'category': data['category'] ?? 'Bilinmiyor',
            'stock': stock,
          });
        }
      }

      return lowStock;
    } catch (e) {
      debugPrint('Stok kontrol hatası: $e');
      return [];
    }
  }

  // Yakında teslim alınacak kiralamaları kontrol et (2 gün içinde)
  static Future<List<Map<String, dynamic>>> getUpcomingRentals() async {
    try {
      final now = DateTime.now();
      final inTwoDays = now.add(const Duration(days: 2));

      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('status', isEqualTo: 'aktif')
          .get();

      final upcoming = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();

        if (plannedReturn != null) {
          if (plannedReturn.isAfter(now) && plannedReturn.isBefore(inTwoDays)) {
            upcoming.add({
              'id': doc.id,
              'equipmentName': data['equipmentName'] ?? 'Bilinmiyor',
              'customerName': data['customerName'] ?? 'Bilinmiyor',
              'plannedReturnDate': plannedReturn,
            });
          }
        }
      }

      return upcoming;
    } catch (e) {
      debugPrint('Yaklaşan teslim kontrol hatası: $e');
      return [];
    }
  }
}

