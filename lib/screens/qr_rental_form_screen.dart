import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/equipment_model.dart';
import '../widgets/user_app_bar.dart';
import 'scanner_screen.dart';
import 'rental_cart_screen.dart';

class QRRentalFormScreen extends StatefulWidget {
  const QRRentalFormScreen({
    super.key,
    this.equipment,
    this.equipmentList,
  });

  final EquipmentModel? equipment;
  final List<EquipmentModel>? equipmentList;

  @override
  State<QRRentalFormScreen> createState() => _QRRentalFormScreenState();
}

class _QRRentalFormScreenState extends State<QRRentalFormScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _extrasController = TextEditingController();
  DateTime? _startDate;
  DateTime? _plannedReturnDate;
  bool _loading = false;
  String? _selectedCustomerId;

  @override
  void dispose() {
    _customerController.dispose();
    _extrasController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Eğer dönüş tarihi başlangıç tarihinden önceyse, dönüş tarihini güncelle
        if (_plannedReturnDate != null && _plannedReturnDate!.isBefore(picked)) {
          _plannedReturnDate = picked.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectReturnDate() async {
    final initialDate = _plannedReturnDate ?? 
        (_startDate?.add(const Duration(days: 7)) ?? DateTime.now().add(const Duration(days: 7)));
    final firstDate = _startDate ?? DateTime.now();
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _plannedReturnDate = picked;
      });
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.of(context).push<EquipmentModel>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(actionType: 'kiralama'),
      ),
    );

    if (result != null && mounted) {
      // Stok kontrolü (ekstra güvenlik için)
      // Not: ScannerScreen'de zaten stok kontrolü yapılıyor ve mesaj gösteriliyor
      // Burada ekstra kontrol yapmaya gerek yok çünkü result null dönmez
      // Eğer stok yoksa ScannerScreen'de mesaj gösteriliyor ve result null döner

      // Sonuç döndüğünde equipment'i güncellemek için yeni bir widget'a geçiş yap
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QRRentalFormScreen(equipment: result),
        ),
      );
    }
  }


  // Sepetten gelen ekipmanları veya tek ekipmanı al
  List<EquipmentModel> get _equipmentList {
    // Önce equipmentList kontrolü (sepetten gelen)
    if (widget.equipmentList != null && widget.equipmentList!.isNotEmpty) {
      return widget.equipmentList!;
    }
    // Sonra tek ekipman kontrolü
    final equipment = widget.equipment;
    if (equipment != null) {
      return [equipment];
    }
    return [];
  }

  Future<void> _submit() async {
    if (_equipmentList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir ekipman seçin')),
      );
      return;
    }

    if (_customerController.text.trim().isEmpty ||
        _startDate == null ||
        _plannedReturnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun')),
      );
      return;
    }

    // Başlangıç tarihi dönüş tarihinden sonra olamaz
    if (_startDate!.isAfter(_plannedReturnDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başlangıç tarihi dönüş tarihinden sonra olamaz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Stok kontrolü - Tüm ekipmanların stokunu kontrol et
    final outOfStockItems = _equipmentList.where((eq) => eq.stock <= 0).toList();
    if (outOfStockItems.isNotEmpty) {
      final itemNames = outOfStockItems.map((e) => e.name).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Stokta yok: $itemNames'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final startTs = Timestamp.fromDate(_startDate!);
      final returnTs = Timestamp.fromDate(_plannedReturnDate!);
      
      // Mevcut kullanıcı bilgisini al
      final currentUser = FirebaseAuth.instance.currentUser;
      String? createdByEmail;
      String? createdByName;
      
      if (currentUser != null) {
        createdByEmail = currentUser.email;
        
        // Firestore'dan kullanıcı adı soyadı al
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            final firstName = userData?['firstName'] as String?;
            final lastName = userData?['lastName'] as String?;
            
            if (firstName != null && lastName != null) {
              createdByName = '$firstName $lastName';
            } else if (firstName != null) {
              createdByName = firstName;
            } else if (userData?['displayName'] != null) {
              createdByName = userData!['displayName'] as String;
            }
          }
        } catch (e) {
          debugPrint('Kullanıcı bilgisi alınamadı: $e');
        }
        
        // Firestore'da yoksa Firebase Auth'dan al
        if (createdByName == null || createdByName.isEmpty) {
          if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
            createdByName = currentUser.displayName!;
          } else if (currentUser.email != null) {
            final emailParts = currentUser.email!.split('@');
            createdByName = emailParts[0];
          }
        }
      }
      
      // Ekipmanları sırala: Kamera öncelikli
      final sortedEquipment = List<EquipmentModel>.from(_equipmentList);
      
      if (sortedEquipment.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ekipman listesi boş'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      sortedEquipment.sort((a, b) {
        // Kamera kategorisi öncelikli
        final aIsCamera = a.category.toLowerCase() == 'kamera';
        final bIsCamera = b.category.toLowerCase() == 'kamera';
        
        if (aIsCamera && !bIsCamera) return -1;
        if (!aIsCamera && bIsCamera) return 1;
        
        // Aynı öncelikteyse isme göre sırala
        return a.name.compareTo(b.name);
      });
      
      // Müşteri adını al
      final customerName = _customerController.text.trim();
      
      // Ekipman ID'leri ve isimleri listesi oluştur
      final equipmentIds = sortedEquipment.map((e) => e.id).toList();
      final equipmentNames = sortedEquipment.map((e) => e.name).toList();
      
      // İlk ekipman (öncelikli olan) için geriye dönük uyumluluk
      final primaryEquipment = sortedEquipment.first;
      final primaryEquipmentName = equipmentNames.isNotEmpty 
          ? (equipmentNames.length == 1 ? equipmentNames.first : '${equipmentNames.length} Ekipman')
          : 'Ekipman';
      
      // Tek bir kiralama kaydı oluştur
      final batch = FirebaseFirestore.instance.batch();
      final rentalRef = FirebaseFirestore.instance.collection('rentals').doc();
      
      batch.set(rentalRef, {
        'equipmentId': primaryEquipment.id, // Geriye dönük uyumluluk için (ilk/öncelikli ekipman)
        'equipmentIds': equipmentIds, // Tüm ekipmanlar
        'equipmentName': primaryEquipmentName, // Geriye dönük uyumluluk için
        'equipmentNames': equipmentNames, // Tüm ekipman isimleri
        'customerName': customerName,
        if (_selectedCustomerId != null) 'customerId': _selectedCustomerId,
        'startDate': startTs,
        'plannedReturnDate': returnTs,
        'status': 'aktif',
        'createdAt': FieldValue.serverTimestamp(),
        if (createdByEmail != null) 'createdByEmail': createdByEmail,
        if (createdByName != null) 'createdByName': createdByName,
        if (_extrasController.text.trim().isNotEmpty) 'extras': _extrasController.text.trim(),
      });
      
      // Her ekipmanın stokunu azalt ve status güncelle
      for (final equipment in sortedEquipment) {
        final currentStock = equipment.stock;
        final newStock = currentStock > 0 ? currentStock - 1 : 0;
        final newStatus = newStock > 0 ? equipment.status : EquipmentStatus.kiralamada;
        
        final equipmentRef = FirebaseFirestore.instance.collection('equipment').doc(equipment.id);
        
        // Owner field'ını koru (varsa)
        final updateData = <String, dynamic>{
          'stock': newStock,
          'status': newStatus.name,
          'currentRentalId': rentalRef.id,
        };
        
        // Owner field'ını koru (varsa) veya varsayılan olarak 'maslakfilm' ekle (yoksa)
        if (equipment.owner != null) {
          updateData['owner'] = equipment.owner;
        } else {
          // Owner null ise varsayılan olarak 'maslakfilm' ekle
          updateData['owner'] = 'maslakfilm';
        }
        
        batch.update(equipmentRef, updateData);
      }
      
      // Tüm işlemleri toplu olarak kaydet
      await batch.commit();

      if (!mounted) return;
      
      // Tüm sayfaları kapat ve ana sayfaya dön
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_equipmentList.length == 1
              ? '✅ Kiralama kaydedildi'
              : '✅ ${_equipmentList.length} ekipman için tek kiralama kaydedildi'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Hata sessizce log edilir
      debugPrint('Kiralama hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Kiralama'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_equipmentList.isEmpty)
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[900]?.withValues(alpha: 0.3)
                    : Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_scanner, size: 48, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Ekipman Seçilmedi',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lütfen QR kod tarayarak ekipman seçin',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _scanQR,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('QR Tara'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_equipmentList.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt, size: 32, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _equipmentList.first.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _equipmentList.first.category,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _scanQR,
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Ekipman Değiştir',
                      ),
                      IconButton(
                        onPressed: () {
                          final equipment = _equipmentList.isNotEmpty ? _equipmentList.first : null;
                          if (equipment != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RentalCartScreen(
                                  initialEquipment: equipment,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.shopping_cart),
                        tooltip: 'Sepete Ekle',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Kiralama Bilgileri',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const TextField(
                    decoration: InputDecoration(
                      labelText: 'Kime Gidiyor? *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                      suffixIcon: SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    enabled: false,
                  );
                }

                final customers = snapshot.data?.docs ?? [];
                final customerNames = customers.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'name': data['name'] ?? 'İsimsiz',
                  };
                }).toList();

                return Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => option['name'] as String,
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return customerNames;
                    }
                    return customerNames.where((customer) {
                      final name = (customer['name'] as String).toLowerCase();
                      return name.contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (option) {
                    setState(() {
                      _selectedCustomerId = option['id'] as String;
                      _customerController.text = option['name'] as String;
                    });
                  },
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    // Controller'ı senkronize et
                    if (textEditingController.text != _customerController.text) {
                      textEditingController.text = _customerController.text;
                    }
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Kime Gidiyor? *',
                        hintText: 'Müşteri adı yazın veya seçin',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) {
                        _customerController.text = value;
                        _selectedCustomerId = null;
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectStartDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ne Zaman Gidiyor? *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _startDate == null
                      ? 'Kiralama başlangıç tarihini seçin'
                      : DateFormat('dd.MM.yyyy').format(_startDate!),
                  style: TextStyle(
                    color: _startDate == null 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey[400] 
                            : Colors.grey) 
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectReturnDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ne Zaman Geliyor? *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _plannedReturnDate == null
                      ? 'Planlanan dönüş tarihini seçin'
                      : DateFormat('dd.MM.yyyy').format(_plannedReturnDate!),
                  style: TextStyle(
                    color: _plannedReturnDate == null 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey[400] 
                            : Colors.grey) 
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ekstralar / Notlar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _extrasController,
              decoration: const InputDecoration(
                labelText: 'Diğer eşyalar (kablo, hafıza kartı, vb.)',
                hintText: 'Örn: 2x HDMI kablosu, 64GB SD kart, tripod',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
                helperText: 'QR ile taranmayan ara parçalar ve ekstra notlar için',
              ),
              keyboardType: TextInputType.multiline,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kiralamayı Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

