import 'package:flutter/material.dart';
import '../models/equipment_model.dart';
import '../widgets/user_app_bar.dart';
import 'scanner_screen.dart';
import 'qr_rental_form_screen.dart';

class RentalCartScreen extends StatefulWidget {
  const RentalCartScreen({super.key, this.initialEquipment});

  final EquipmentModel? initialEquipment;

  @override
  State<RentalCartScreen> createState() => _RentalCartScreenState();
}

class _RentalCartScreenState extends State<RentalCartScreen> {
  late final List<EquipmentModel> _cartItems;

  @override
  void initState() {
    super.initState();
    // Başlangıç ekipmanı varsa sepete ekle
    _cartItems = widget.initialEquipment != null
        ? [widget.initialEquipment!]
        : [];
  }

  Future<void> _scanQR() async {
    final result = await Navigator.of(context).push<EquipmentModel>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(actionType: 'kiralama'),
      ),
    );

    if (result != null && mounted) {
      // Stok kontrolü
      if (result.stock <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result.name} - Stokta yok (Stok: ${result.stock})'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Aynı ekipman zaten sepette var mı kontrol et
      final exists = _cartItems.any((item) => item.id == result.id);
      
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu ekipman zaten sepette'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _cartItems.add(result);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.name} sepete eklendi'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _continueToForm() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir ekipman ekleyin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QRRentalFormScreen(equipmentList: _cartItems),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Kiralama Sepeti'),
      body: Column(
        children: [
          // Sepet içeriği
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sepet Boş',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'QR kod tarayarak ekipman ekleyin',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            Icons.camera_alt,
                            color: Theme.of(context).colorScheme.primary,
                            size: 32,
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(item.category),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeItem(index),
                            tooltip: 'Kaldır',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Alt butonlar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_cartItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${_cartItems.length} ekipman seçildi',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanQR,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('QR Tara'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _cartItems.isEmpty ? null : _continueToForm,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                        child: const Text('Devam Et'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

