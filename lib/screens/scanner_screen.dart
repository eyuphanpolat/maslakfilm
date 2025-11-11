import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/equipment_model.dart';
import 'equipment_detail_screen.dart';
import '../widgets/user_app_bar.dart';

class ScannerScreen extends StatefulWidget {
  final String? actionType; // 'kiralama' veya 'teslim'
  
  const ScannerScreen({super.key, this.actionType});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _handled = false;

  Future<void> _handleCode(String value) async {
    if (_handled) return;
    _handled = true;
    try {
      DocumentSnapshot? targetDoc;
      
      // Önce qrCodeData ile arama yap (kısa kodlar için)
      final q = await FirebaseFirestore.instance
          .collection('equipment')
          .where('qrCodeData', isEqualTo: value)
          .limit(1)
          .get();
      
      if (q.docs.isNotEmpty) {
        targetDoc = q.docs.first;
      } else {
        // Eğer qrCodeData ile bulunamazsa, doküman ID ile ara (eski veriler için)
        final doc = await FirebaseFirestore.instance.collection('equipment').doc(value).get();
        if (doc.exists) {
          targetDoc = doc;
        }
      }
      
      if (targetDoc != null && targetDoc.exists) {
        final model = EquipmentModel.fromSnapshot(targetDoc);
        if (!mounted) return;
        
        // Kiralama için stok kontrolü
        if (widget.actionType == 'kiralama') {
          if (model.stock <= 0) {
            if (!mounted) return;
            _handled = false; // Tekrar deneme için
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ ${model.name} - Stokta yok (Stok: ${model.stock})'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
        }
        
        // Kısa bir gecikme ekle (QR kamera kapanması için)
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (!mounted) return;
        
        // Eğer actionType belirtilmişse, sonucu döndür
        if (widget.actionType == 'kiralama' || widget.actionType == 'teslim') {
          // Scanner'ı kapat ve sonucu döndür
          if (!mounted) return;
          Navigator.of(context).pop(model); // EquipmentModel'i döndür
        } else {
          // Eğer actionType yoksa eski gibi detay sayfasına git
          Navigator.of(context).pop(); // Scanner'ı kapat
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EquipmentDetailScreen(equipment: model)),
          );
        }
      } else {
        if (!mounted) return;
        _handled = false; // Tekrar deneme için
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ekipman bulunamadı'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _handled = false; // Tekrar deneme için
      // Hata sessizce log edilir
      debugPrint('QR tarama hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'QR Tara'),
      body: MobileScanner(
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;
          final raw = barcodes.first.rawValue;
          if (raw != null && raw.isNotEmpty) {
            _handleCode(raw);
          }
        },
      ),
    );
  }
}

