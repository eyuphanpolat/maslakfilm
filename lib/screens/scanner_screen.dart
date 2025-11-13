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
  String? _stockErrorMessage;
  String? _equipmentName;

  @override
  void dispose() {
    // Ekran kapanırken mesajı temizle
    _stockErrorMessage = null;
    super.dispose();
  }

  Future<void> _handleCode(String value) async {
    if (_handled) return;
    _handled = true;
    
    // Önceki hata mesajını temizle
    setState(() {
      _stockErrorMessage = null;
      _equipmentName = null;
    });
    
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
            setState(() {
              _stockErrorMessage = 'Stok Yok';
              _equipmentName = model.name;
            });
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
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw != null && raw.isNotEmpty) {
                _handleCode(raw);
              }
            },
          ),
          // Stok yok uyarısı (yanıp sönmeyen, sabit)
          if (_stockErrorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.red,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _stockErrorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_equipmentName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _equipmentName!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _stockErrorMessage = null;
                            _equipmentName = null;
                            _handled = false; // Tekrar tarama yapılabilir
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

