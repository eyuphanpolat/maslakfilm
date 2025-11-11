import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/user_app_bar.dart';
import '../models/equipment_model.dart';
import 'equipment_detail_screen.dart';
import 'scanner_screen.dart';

class EquipmentListScreen extends StatelessWidget {
  const EquipmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Ekipmanlar'),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_equipment',
            onPressed: () => showAddEquipmentDialog(context),
            tooltip: 'Ekipman Ekle',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'qr_scan',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScannerScreen()),
              );
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QR Tara'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipment')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Veri yüklenirken bir sorun oluştu'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz ekipman yok',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yeni ekipman eklemek için + butonuna tıklayın',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<DocumentSnapshot?>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .snapshots()
                : null,
            builder: (context, adminSnapshot) {
              // Admin kontrolü
              bool isAdmin = false;
              final user = FirebaseAuth.instance.currentUser;
              
              final adminEmails = ['polathakki@gmail.com', 'eyuphanpolatt@gmail.com'];
              final userEmail = user?.email?.toLowerCase().trim();
              if (userEmail != null && adminEmails.contains(userEmail)) {
                isAdmin = true;
              }
              
              if (!isAdmin && adminSnapshot.hasData && adminSnapshot.data!.exists) {
                final data = adminSnapshot.data!.data() as Map<String, dynamic>?;
                final role = data?['role'] as String?;
                final adminFlag = data?['isAdmin'] as bool?;
                isAdmin = role == 'admin' || adminFlag == true;
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final equipment = EquipmentModel.fromSnapshot(doc);
                  
                  Future<void> deleteEquipment() async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Ekipmanı Sil'),
                        content: Text(
                          '${equipment.name} ekipmanını silmek istediğinizden emin misiniz?\n\n'
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

                    if (confirmed == true && context.mounted) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('equipment')
                            .doc(equipment.id)
                            .delete();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ekipman silindi'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  }
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EquipmentDetailScreen(equipment: equipment),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: equipment.status == EquipmentStatus.kiralamada
                                    ? Colors.orange[100]
                                    : Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: equipment.status == EquipmentStatus.kiralamada
                                    ? Colors.orange[900]
                                    : Colors.green[900],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          equipment.name,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          onPressed: () {
                                            deleteEquipment();
                                          },
                                          tooltip: 'Sil',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    equipment.category,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Stok: ${equipment.stock}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                equipment.status == EquipmentStatus.kiralamada
                                    ? 'Kiralamada'
                                    : 'Ofiste',
                              ),
                              backgroundColor: equipment.status == EquipmentStatus.kiralamada
                                  ? Colors.orange[100]
                                  : Colors.green[100],
                              labelStyle: TextStyle(
                                color: equipment.status == EquipmentStatus.kiralamada
                                    ? Colors.orange[900]
                                    : Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static void showAddEquipmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddEquipmentDialog(),
    );
  }
}

class _AddEquipmentDialog extends StatefulWidget {
  const _AddEquipmentDialog();

  @override
  State<_AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<_AddEquipmentDialog> {
  final nameController = TextEditingController();
  final stockController = TextEditingController(text: '1');
  String selectedCategory = 'Kamera';

  static const List<String> categories = [
    'Kamera',
    'Lens',
    'Monitör',
    'Ses',
    'Destekleyici',
    'Gimball',
    'Aksesuar',
    'Reji',
    'Işık',
  ];

  @override
  void dispose() {
    nameController.dispose();
    stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Ekipman'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ekipman Adı *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedCategory = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: 'Stok',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ekipman adı gereklidir')),
              );
              return;
            }

            try {
              // Stok değerini parse et
              int stock = 1;
              try {
                stock = int.parse(stockController.text.trim().isEmpty ? '1' : stockController.text.trim());
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stok değeri geçerli bir sayı olmalıdır')),
                );
                return;
              }

              // Kısa QR kod oluştur: Kategori baş harfi + Ekipman isminden 4 harf = 5 harf
              String generateShortQRCode(String category, String name) {
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
              
              // Firebase'e ekle ve otomatik ID al
              final docRef = await FirebaseFirestore.instance.collection('equipment').add({
                'name': nameController.text.trim(),
                'category': selectedCategory,
                'serialNumber': null,
                'qrCodeData': null, // Önce null, sonra kısa kod ile güncellenecek
                'status': 'ofiste',
                'stock': stock,
                'currentRentalId': null,
                'imageUrl': null,
                'createdAt': FieldValue.serverTimestamp(),
              });
              
              // QR kod verisini kısa kod ile güncelle
              final shortQRCode = generateShortQRCode(selectedCategory, nameController.text.trim());
              await docRef.update({
                'qrCodeData': shortQRCode,
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ekipman eklendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              // Hata sessizce log edilir
              debugPrint('Ekipman ekleme hatası: $e');
            }
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
