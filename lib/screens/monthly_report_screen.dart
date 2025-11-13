import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../widgets/user_app_bar.dart';
import '../utils/file_download_helper.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  List<Map<String, dynamic>> _rentals = [];
  bool _loading = false;
  String? _errorMessage;

  // Yıl listesi: 2025-2030
  final List<int> _years = List.generate(6, (index) => 2025 + index);
  
  // Ay listesi
  final List<String> _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  @override
  void initState() {
    super.initState();
    _loadRentals();
  }

  Future<void> _loadRentals() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Seçilen ayın başlangıç ve bitiş tarihleri
      final startDate = DateTime(_selectedYear, _selectedMonth, 1);
      final endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

      // Firestore'dan kiralama verilerini çek
      final querySnapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final rentals = <Map<String, dynamic>>[];

      // Her kiralama için ekipman sahibi bilgisini çek
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final rentalId = doc.id;

        // Ekipman ID'lerini al (tek veya çoklu)
        final equipmentId = data['equipmentId'] as String?;
        final equipmentIds = data['equipmentIds'] as List<dynamic>?;
        
        // Ekipman isimlerini al
        final equipmentName = data['equipmentName'] as String?;
        final equipmentNames = data['equipmentNames'] as List<dynamic>?;

        // Eğer çoklu ekipman varsa, her biri için ayrı satır oluştur
        if (equipmentIds != null && equipmentIds.isNotEmpty) {
          final names = equipmentNames != null 
              ? equipmentNames.map((e) => e.toString()).toList()
              : <String>[];
          
          for (int i = 0; i < equipmentIds.length; i++) {
            final eqId = equipmentIds[i] as String;
            final eqName = i < names.length ? names[i] : equipmentName ?? 'Bilinmeyen';
            
            // Ekipman sahibi bilgisini çek
            String? owner = 'maslakfilm'; // Varsayılan
            try {
              final eqDoc = await FirebaseFirestore.instance
                  .collection('equipment')
                  .doc(eqId)
                  .get();
              
              if (eqDoc.exists) {
                final eqData = eqDoc.data();
                owner = eqData?['owner'] as String? ?? 'maslakfilm';
              }
            } catch (e) {
              debugPrint('Ekipman sahibi bilgisi alınamadı: $e');
            }

            rentals.add({
              'rentalId': rentalId,
              'equipmentId': eqId,
              'equipmentName': eqName,
              'customerName': data['customerName'] ?? 'Bilinmeyen',
              'startDate': data['startDate'],
              'plannedReturnDate': data['plannedReturnDate'],
              'actualReturnDate': data['actualReturnDate'],
              'price': data['price'],
              'status': data['status'] ?? 'aktif',
              'location': data['location'],
              'owner': owner,
              'createdByName': data['createdByName'],
              'createdByEmail': data['createdByEmail'],
              'returnedByName': data['returnedByName'],
              'returnedByEmail': data['returnedByEmail'],
            });
          }
        } else if (equipmentId != null) {
          // Tek ekipman
          String? owner = 'maslakfilm'; // Varsayılan
          try {
            final eqDoc = await FirebaseFirestore.instance
                .collection('equipment')
                .doc(equipmentId)
                .get();
            
            if (eqDoc.exists) {
              final eqData = eqDoc.data();
              owner = eqData?['owner'] as String? ?? 'maslakfilm';
            }
          } catch (e) {
            debugPrint('Ekipman sahibi bilgisi alınamadı: $e');
          }

          rentals.add({
            'rentalId': rentalId,
            'equipmentId': equipmentId,
            'equipmentName': equipmentName ?? 'Bilinmeyen',
            'customerName': data['customerName'] ?? 'Bilinmeyen',
            'startDate': data['startDate'],
            'plannedReturnDate': data['plannedReturnDate'],
            'actualReturnDate': data['actualReturnDate'],
            'price': data['price'],
            'status': data['status'] ?? 'aktif',
            'location': data['location'],
            'owner': owner,
            'createdByName': data['createdByName'],
            'createdByEmail': data['createdByEmail'],
            'returnedByName': data['returnedByName'],
            'returnedByEmail': data['returnedByEmail'],
          });
        }
      }

      // Tarihe göre sırala (en yeni önce)
      rentals.sort((a, b) {
        final aDate = (a['startDate'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bDate = (b['startDate'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _rentals = rentals;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Veri yüklenirken bir hata oluştu: $e';
        _loading = false;
      });
      debugPrint('Hata: $e');
    }
  }

  Future<void> _exportToExcel() async {
    if (_rentals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarılacak veri yok')),
      );
      return;
    }

    try {
      // Excel dosyası oluştur
      final excel = Excel.createExcel();
      excel.delete('Sheet1'); // Varsayılan sheet'i sil
      final sheet = excel['Aylık Rapor']; // Yeni sheet oluştur

      // Başlık satırı
      sheet.appendRow([
        TextCellValue('Tarih'),
        TextCellValue('Müşteri'),
        TextCellValue('Ekipman'),
        TextCellValue('Sahip'),
        TextCellValue('Başlangıç Tarihi'),
        TextCellValue('Planlanan Dönüş'),
        TextCellValue('Gerçekleşen Dönüş'),
        TextCellValue('Fiyat (TL)'),
        TextCellValue('Durum'),
        TextCellValue('Lokasyon'),
        TextCellValue('Kiralayan Çalışan'),
        TextCellValue('Teslim Alan Çalışan'),
      ]);

      // Veri satırları
      for (final rental in _rentals) {
        final startDate = (rental['startDate'] as Timestamp?)?.toDate();
        final plannedReturn = (rental['plannedReturnDate'] as Timestamp?)?.toDate();
        final actualReturn = (rental['actualReturnDate'] as Timestamp?)?.toDate();
        
        final owner = rental['owner'] as String? ?? 'maslakfilm';
        final ownerDisplay = owner == 'maslakfilm' ? 'Maslak Film' : 'Ortak';
        
        final status = rental['status'] as String? ?? 'aktif';
        final statusDisplay = status == 'aktif' ? 'Aktif' : 'Tamamlandı';
        
        // Kiralayan çalışan bilgisi
        final createdByName = rental['createdByName']?.toString();
        final createdByEmail = rental['createdByEmail']?.toString();
        final createdByDisplay = createdByName ?? createdByEmail ?? '';
        
        // Teslim alan çalışan bilgisi
        final returnedByName = rental['returnedByName']?.toString();
        final returnedByEmail = rental['returnedByEmail']?.toString();
        final returnedByDisplay = returnedByName ?? returnedByEmail ?? '';
        
        sheet.appendRow([
          TextCellValue(startDate != null ? DateFormat('dd.MM.yyyy').format(startDate) : ''),
          TextCellValue(rental['customerName']?.toString() ?? ''),
          TextCellValue(rental['equipmentName']?.toString() ?? ''),
          TextCellValue(ownerDisplay),
          TextCellValue(startDate != null ? DateFormat('dd.MM.yyyy').format(startDate) : ''),
          TextCellValue(plannedReturn != null ? DateFormat('dd.MM.yyyy').format(plannedReturn) : ''),
          TextCellValue(actualReturn != null ? DateFormat('dd.MM.yyyy').format(actualReturn) : ''),
          TextCellValue(rental['price'] != null ? (rental['price'] as num).toStringAsFixed(2) : ''),
          TextCellValue(statusDisplay),
          TextCellValue(rental['location']?.toString() ?? ''),
          TextCellValue(createdByDisplay),
          TextCellValue(returnedByDisplay),
        ]);
      }

      // Dosyayı kaydet
      final fileName = 'Aylik_Rapor_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.xlsx';
      final bytes = excel.encode();
      
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel dosyası oluşturulamadı')),
          );
        }
        return;
      }

      if (kIsWeb) {
        // Web için dosyayı indir
        try {
          final uint8List = Uint8List.fromList(bytes);
          await downloadFile(uint8List, fileName);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Rapor indiriliyor: $fileName'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('Web download hatası: $e');
          // Fallback: share_plus kullan
          try {
            final uint8List = Uint8List.fromList(bytes);
            final xFile = XFile.fromData(
              uint8List,
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: fileName,
            );
            await Share.shareXFiles([xFile], text: 'Aylık Kiralama Raporu');
          } catch (shareError) {
            debugPrint('Share hatası: $shareError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dosya indirme hatası: $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      } else {
        // Mobil ve desktop platformlar için
        try {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          
          await Share.shareXFiles(
            [XFile(filePath)],
            text: 'Aylık Kiralama Raporu',
          );
        } catch (e) {
          debugPrint('Share hatası: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Dosya paylaşma hatası: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dışa aktarma hatası: $e')),
        );
      }
      debugPrint('Excel export hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Aylık Rapor'),
      body: Column(
        children: [
          // Ay ve Yıl Seçimi
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Yıl',
                        border: OutlineInputBorder(),
                      ),
                      items: _years.map((year) {
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedYear = value;
                          });
                          _loadRentals();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Ay',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(_months[index]),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMonth = value;
                          });
                          _loadRentals();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Excel Dışa Aktarma Butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading || _rentals.isEmpty ? null : _exportToExcel,
                icon: const Icon(Icons.download),
                label: const Text('Excel Olarak İndir'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Rapor Listesi
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _rentals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Seçilen ay için kiralama kaydı bulunamadı',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _rentals.length,
                            itemBuilder: (context, index) {
                              final rental = _rentals[index];
                              final startDate = (rental['startDate'] as Timestamp?)?.toDate();
                              final plannedReturn = (rental['plannedReturnDate'] as Timestamp?)?.toDate();
                              final actualReturn = (rental['actualReturnDate'] as Timestamp?)?.toDate();
                              
                              final owner = rental['owner'] as String? ?? 'maslakfilm';
                              final ownerDisplay = owner == 'maslakfilm' ? 'Maslak Film' : 'Ortak';
                              final ownerColor = owner == 'maslakfilm' ? Colors.blue : Colors.orange;
                              
                              final status = rental['status'] as String? ?? 'aktif';
                              final statusColor = status == 'aktif' ? Colors.green : Colors.grey;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              rental['equipmentName'] ?? 'Bilinmeyen',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              ownerDisplay,
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            backgroundColor: ownerColor,
                                            labelStyle: const TextStyle(color: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                          Chip(
                                            label: Text(
                                              status == 'aktif' ? 'Aktif' : 'Tamamlandı',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            backgroundColor: statusColor,
                                            labelStyle: const TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Müşteri: ${rental['customerName'] ?? 'Bilinmeyen'}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      if (startDate != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Başlangıç: ${DateFormat('dd.MM.yyyy').format(startDate)}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                      if (plannedReturn != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Planlanan Dönüş: ${DateFormat('dd.MM.yyyy').format(plannedReturn)}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                      if (actualReturn != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Gerçekleşen Dönüş: ${DateFormat('dd.MM.yyyy').format(actualReturn)}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      if (rental['price'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fiyat: ${(rental['price'] as num).toStringAsFixed(2)} TL',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                      if (rental['location'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lokasyon: ${rental['location']}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                      // Kiralayan çalışan bilgisi
                                      if (rental['createdByName'] != null || rental['createdByEmail'] != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.person_outline, size: 14, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Kiralayan: ${rental['createdByName'] ?? rental['createdByEmail'] ?? 'Bilinmiyor'}',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      // Teslim alan çalışan bilgisi
                                      if (rental['returnedByName'] != null || rental['returnedByEmail'] != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.how_to_reg, size: 14, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Teslim Alan: ${rental['returnedByName'] ?? rental['returnedByEmail'] ?? 'Bilinmiyor'}',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
