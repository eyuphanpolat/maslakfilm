import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/equipment_model.dart';
import '../widgets/user_app_bar.dart';
import 'scanner_screen.dart';

class QRDeliveryFormScreen extends StatefulWidget {
  const QRDeliveryFormScreen({super.key, this.equipment});

  final EquipmentModel? equipment;

  @override
  State<QRDeliveryFormScreen> createState() => _QRDeliveryFormScreenState();
}

class _QRDeliveryFormScreenState extends State<QRDeliveryFormScreen> {
  bool _isIntact = true;
  bool _hasDamage = false;
  bool _hasMissingParts = false;
  final TextEditingController _damageNotesController = TextEditingController();
  final TextEditingController _missingPartsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _damageNotesController.dispose();
    _missingPartsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _scanQR() async {
    final result = await Navigator.of(context).push<EquipmentModel>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(actionType: 'teslim'),
      ),
    );

    if (result != null && mounted) {
      // Sonuç döndüğünde equipment'i güncellemek için yeni bir widget'a geçiş yap
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QRDeliveryFormScreen(equipment: result),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (widget.equipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce QR kod tarayın')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Önce mevcut kiralama bilgisini al
      String? rentalId = widget.equipment!.currentRentalId;
      
      // Mevcut kullanıcı bilgisini al
      final currentUser = FirebaseAuth.instance.currentUser;
      String? returnedByEmail;
      String? returnedByName;
      
      if (currentUser != null) {
        returnedByEmail = currentUser.email;
        
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
              returnedByName = '$firstName $lastName';
            } else if (firstName != null) {
              returnedByName = firstName;
            } else if (userData?['displayName'] != null) {
              returnedByName = userData!['displayName'] as String;
            }
          }
        } catch (e) {
          debugPrint('Kullanıcı bilgisi alınamadı: $e');
        }
        
        // Firestore'da yoksa Firebase Auth'dan al
        if (returnedByName == null || returnedByName.isEmpty) {
          if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
            returnedByName = currentUser.displayName!;
          } else if (currentUser.email != null) {
            final emailParts = currentUser.email!.split('@');
            returnedByName = emailParts[0];
          }
        }
      }
      
      if (rentalId != null) {
        // Kiralama durumunu tamamlandı olarak işaretle
        await FirebaseFirestore.instance.collection('rentals').doc(rentalId).update({
          'status': 'tamamlandi',
          'actualReturnDate': Timestamp.now(),
          'returnNotes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          'isIntact': _isIntact,
          'hasDamage': _hasDamage,
          'damageNotes': _hasDamage && _damageNotesController.text.trim().isNotEmpty
              ? _damageNotesController.text.trim()
              : null,
          'hasMissingParts': _hasMissingParts,
          'missingPartsNotes': _hasMissingParts && _missingPartsController.text.trim().isNotEmpty
              ? _missingPartsController.text.trim()
              : null,
          'returnedByEmail': returnedByEmail,
          'returnedByName': returnedByName,
        });
      }

      // Ekipman stokunu artır ve ofiste olarak işaretle
      final equipmentDoc = await FirebaseFirestore.instance.collection('equipment').doc(widget.equipment!.id).get();
      final currentStock = equipmentDoc.data()?['stock'] as int? ?? 0;
      
      await FirebaseFirestore.instance.collection('equipment').doc(widget.equipment!.id).update({
        'stock': currentStock + 1,
        'status': currentStock + 1 > 0 ? 'ofiste' : widget.equipment!.status.name,
        'currentRentalId': null,
      });

      if (!mounted) return;

      // Tüm sayfaları kapat ve ana sayfaya dön
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Teslim alım tamamlandı'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Hata sessizce log edilir
      debugPrint('Teslim alım hatası: $e');
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
      appBar: const UserAppBar(title: 'Teslim Alım'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.equipment == null)
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green[900]?.withValues(alpha: 0.3)
                    : Colors.green[50],
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
            else
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
                              widget.equipment!.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.equipment!.category,
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
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Teslim Alım Kontrolü',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('Ekipman Sağlam'),
                subtitle: const Text('Ekipman herhangi bir hasar veya eksiklik yok'),
                value: _isIntact,
                onChanged: (value) {
                  setState(() {
                    _isIntact = value;
                    if (value) {
                      _hasDamage = false;
                      _hasMissingParts = false;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: const Text('Hasar Var'),
                subtitle: const Text('Ekipmanda herhangi bir hasar tespit edildi'),
                value: _hasDamage,
                onChanged: _isIntact
                    ? null
                    : (value) {
                        setState(() {
                          _hasDamage = value;
                          if (value) {
                            _isIntact = false;
                          }
                        });
                      },
              ),
            ),
            if (_hasDamage) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _damageNotesController,
                decoration: const InputDecoration(
                  labelText: 'Hasar Detayları',
                  hintText: 'Hasarın açıklamasını yazın',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: const Text('Eksik Parça Var'),
                subtitle: const Text('Ekipmanda eksik aksesuar veya parça var'),
                value: _hasMissingParts,
                onChanged: _isIntact
                    ? null
                    : (value) {
                        setState(() {
                          _hasMissingParts = value;
                          if (value) {
                            _isIntact = false;
                          }
                        });
                      },
              ),
            ),
            if (_hasMissingParts) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _missingPartsController,
                decoration: const InputDecoration(
                  labelText: 'Eksik Parça Detayları',
                  hintText: 'Eksik olan parçaları yazın',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Genel Notlar (Opsiyonel)',
                hintText: 'Ek notlarınızı yazın',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLines: 3,
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
                  : const Text('Teslim Alımı Tamamla'),
            ),
          ],
        ),
      ),
    );
  }
}

