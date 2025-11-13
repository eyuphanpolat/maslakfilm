import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/equipment_model.dart';
import '../widgets/user_app_bar.dart';

class RentalFormScreen extends StatefulWidget {
  const RentalFormScreen({super.key, required this.equipment});

  final EquipmentModel equipment;

  @override
  State<RentalFormScreen> createState() => _RentalFormScreenState();
}

class _RentalFormScreenState extends State<RentalFormScreen> {
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime? _plannedReturnDate;
  bool _loading = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _plannedReturnDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_customerController.text.trim().isEmpty ||
        _plannedReturnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final now = Timestamp.now();
      final returnTs = Timestamp.fromDate(_plannedReturnDate!);
      final rentalRef = await FirebaseFirestore.instance.collection('rentals').add({
        'equipmentId': widget.equipment.id,
        'equipmentName': widget.equipment.name,
        'customerName': _customerController.text.trim(),
        'price': _priceController.text.trim().isEmpty ? null : double.tryParse(_priceController.text.trim()),
        'startDate': now,
        'plannedReturnDate': returnTs,
        'status': 'aktif',
        'createdAt': now,
      });
      
      // Stok azalt ve status güncelle
      final currentStock = widget.equipment.stock;
      final newStock = currentStock > 0 ? currentStock - 1 : 0;
      final newStatus = newStock > 0 ? widget.equipment.status : EquipmentStatus.kiralamada;
      
      // Owner field'ını koru (varsa) veya varsayılan olarak 'maslakfilm' ekle (yoksa)
      final updateData = <String, dynamic>{
        'stock': newStock,
        'status': newStatus.name,
        'currentRentalId': rentalRef.id,
      };
      
      if (widget.equipment.owner != null) {
        updateData['owner'] = widget.equipment.owner;
      } else {
        // Owner null ise varsayılan olarak 'maslakfilm' ekle
        updateData['owner'] = 'maslakfilm';
      }
      
      await FirebaseFirestore.instance.collection('equipment').doc(widget.equipment.id).update(updateData);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kiralama kaydedildi')),
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
      appBar: const UserAppBar(title: 'Kiraya Ver'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ekipman: ${widget.equipment.name}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(labelText: 'Müşteri Adı *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Fiyat (Opsiyonel)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Planlanan Dönüş Tarihi *', border: OutlineInputBorder()),
                child: Text(_plannedReturnDate == null ? 'Tarih seçin' : DateFormat('dd.MM.yyyy').format(_plannedReturnDate!)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

