import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import '../models/equipment_model.dart';
import '../widgets/user_app_bar.dart';

class EquipmentDetailScreen extends StatefulWidget {
  const EquipmentDetailScreen({super.key, required this.equipment});

  final EquipmentModel equipment;

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  late EquipmentModel _equipment;

  @override
  void initState() {
    super.initState();
    _equipment = widget.equipment;
  }

  // QR kod verisi - Kısa kod kullan
  String get _qrCodeData => _equipment.qrCodeData;

  // PDF oluşturma ve yazdırma
  Future<void> _generateAndShareQR() async {
    try {
      // Özel sayfa formatı: 6 cm x 5.7 cm (60 mm x 57 mm)
      const customFormat = PdfPageFormat(60 * PdfPageFormat.mm, 57 * PdfPageFormat.mm);
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return _buildQRPDF(customFormat);
        },
      );
    } catch (e) {
      // Hata sessizce log edilir
      debugPrint('QR PDF hatası: $e');
    }
  }

  Future<Uint8List> _buildQRPDF(PdfPageFormat format) async {
    final pdf = pw.Document();

    // QR kod verisini al
    final qrData = _qrCodeData;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          // Sayfa boyutları: 60mm x 57mm
          // QR kod boyutu: yaklaşık 40mm (sayfa genişliğinin %66'sı)
          // Metin için üstte yaklaşık 10mm boşluk
          final qrSize = format.width * 0.66;
          
          return pw.Container(
            width: format.width,
            height: format.height,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Flexible(
                  child: pw.Text(
                    _equipment.name,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.BarcodeWidget(
                  data: qrData,
                  barcode: pw.Barcode.qrCode(),
                  color: PdfColors.black,
                  width: qrSize,
                  height: qrSize,
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _deleteEquipment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekipmanı Sil'),
        content: Text(
          '${_equipment.name} ekipmanını silmek istediğinizden emin misiniz?\n\n'
          'Bu işlem geri alınamaz!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        await FirebaseFirestore.instance
            .collection('equipment')
            .doc(_equipment.id)
            .delete();

        if (!mounted) return;
        Navigator.of(context).pop(); // Detail ekranını kapat
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ekipman silindi'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Hata sessizce log edilir
        debugPrint('Ekipman silme hatası: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final e = _equipment;
    return Scaffold(
      appBar: UserAppBar(title: e.name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Durum: ${e.status.name.toUpperCase()}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Kategori: ${e.category}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 18,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Text(
                  'Stok: ${e.stock}',
                  style: const TextStyle(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // QR Kod Bölümü
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      e.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: QrImageView(
                          data: _qrCodeData,
                          version: QrVersions.auto,
                          size: 250,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.L,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: FilledButton.icon(
                        onPressed: _generateAndShareQR,
                        icon: const Icon(Icons.download),
                        label: const Text('QR Kod İndir ve Yazdır'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (e.status == EquipmentStatus.kiralamada && e.currentRentalId != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('rentals').doc(e.currentRentalId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final rental = snapshot.data!.data() as Map<String, dynamic>?;
                  if (rental == null) return const SizedBox.shrink();
                  final startDate = (rental['startDate'] as Timestamp?)?.toDate();
                  final plannedReturn = (rental['plannedReturnDate'] as Timestamp?)?.toDate();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aktif Kiralama', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          )),
                          const SizedBox(height: 8),
                          Text('Müşteri: ${rental['customerName'] ?? 'Bilinmiyor'}'),
                          if (startDate != null) Text('Başlangıç: ${DateFormat('dd.MM.yyyy').format(startDate)}'),
                          if (plannedReturn != null) Text('Planlanan Dönüş: ${DateFormat('dd.MM.yyyy').format(plannedReturn)}'),
                          if (rental['price'] != null) Text('Fiyat: ${rental['price']} TL'),
                          if (rental['extras'] != null && (rental['extras'] as String).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange[900]!.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.note_outlined, size: 16, color: Colors.orange[300]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Ekstralar:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[300])),
                                        Text(rental['extras'] as String, style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            // Kiralama Geçmişi Bölümü
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, size: 24, color: Colors.grey[300]),
                        const SizedBox(width: 8),
                        Text(
                          'Kiralama Geçmişi',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('rentals')
                          .orderBy('startDate', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          debugPrint('Kiralama geçmişi hatası: ${snapshot.error}');
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Kiralama geçmişi yüklenirken hata oluştu',
                              style: TextStyle(color: Colors.red[300]),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Kiralama geçmişi yok'),
                          );
                        }

                        // Memory'de filtreleme: Bu ekipmanla ilgili tüm kiralama kayıtlarını bul
                        final allRentals = snapshot.data!.docs;
                        final equipmentRentals = allRentals.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          
                          // equipmentId kontrolü (tek ekipman - geriye dönük uyumluluk)
                          final equipmentId = data['equipmentId'] as String?;
                          if (equipmentId == e.id) return true;
                          
                          // equipmentIds kontrolü (çoklu ekipman)
                          final equipmentIds = data['equipmentIds'] as List<dynamic>?;
                          if (equipmentIds != null && equipmentIds.contains(e.id)) {
                            return true;
                          }
                          
                          return false;
                        }).toList();

                        if (equipmentRentals.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Bu ekipman için kiralama geçmişi yok'),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: equipmentRentals.length,
                          itemBuilder: (context, index) {
                            final doc = equipmentRentals[index];
                            final data = doc.data() as Map<String, dynamic>;
                            
                            final startDate = (data['startDate'] as Timestamp?)?.toDate();
                            final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();
                            final actualReturn = (data['actualReturnDate'] as Timestamp?)?.toDate();
                            final status = data['status'] as String? ?? 'bilinmiyor';
                            final customerName = data['customerName'] as String? ?? 'Bilinmiyor';
                            final isActive = status == 'aktif';
                            final isCompleted = status == 'tamamlandi' || status == 'tamamlandı';
                            
                            // Aktif kiralama ise ve currentRentalId ile eşleşiyorsa, zaten üstte gösteriliyor, burada gösterme
                            if (isActive && doc.id == e.currentRentalId) {
                              return const SizedBox.shrink();
                            }
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isActive 
                                  ? Colors.grey[800] 
                                  : isCompleted 
                                      ? Colors.grey[800] 
                                      : Colors.grey[800],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            customerName,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Chip(
                                          label: Text(
                                            isActive 
                                                ? 'Aktif' 
                                                : isCompleted 
                                                    ? 'Tamamlandı' 
                                                    : status,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor: isActive 
                                              ? Colors.grey[700] 
                                              : isCompleted 
                                                  ? Colors.grey[700] 
                                                  : Colors.grey[700],
                                          labelStyle: TextStyle(
                                            color: isActive 
                                                ? Colors.white 
                                                : isCompleted 
                                                    ? Colors.white 
                                                    : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (startDate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Başlangıç: ${DateFormat('dd.MM.yyyy').format(startDate)}',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (plannedReturn != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.event, size: 14, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Planlanan Dönüş: ${DateFormat('dd.MM.yyyy').format(plannedReturn)}',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (actualReturn != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle, size: 14, color: Colors.grey[300]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Dönüş: ${DateFormat('dd.MM.yyyy').format(actualReturn)}',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (data['extras'] != null && (data['extras'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[900]!.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.note_outlined, size: 16, color: Colors.orange[300]),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Ekstralar:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[300])),
                                                  Text(data['extras'] as String, style: const TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (data['price'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.attach_money, size: 14, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Fiyat: ${data['price']} TL',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Admin için silme butonu
            StreamBuilder<DocumentSnapshot?>(
              stream: FirebaseAuth.instance.currentUser != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                bool isAdmin = false;
                final user = FirebaseAuth.instance.currentUser;
                
                // Admin email kontrolü
                final adminEmails = ['polathakki@gmail.com', 'eyuphanpolatt@gmail.com'];
                final userEmail = user?.email?.toLowerCase().trim();
                if (userEmail != null && adminEmails.contains(userEmail)) {
                  isAdmin = true;
                }
                
                // Firestore'dan kontrol
                if (!isAdmin && snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  final role = data?['role'] as String?;
                  final adminFlag = data?['isAdmin'] as bool?;
                  isAdmin = role == 'admin' || adminFlag == true;
                }
                
                if (!isAdmin) return const SizedBox.shrink();
                
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton(
                    onPressed: _deleteEquipment,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Ekipmanı Sil'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


