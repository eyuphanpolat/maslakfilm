import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/user_app_bar.dart';

class CustomerRentalHistoryScreen extends StatelessWidget {
  final String customerName;

  const CustomerRentalHistoryScreen({
    super.key,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Kiralama Geçmişi'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rentals')
            .where('customerName', isEqualTo: customerName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Hata oluştu:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kiralama geçmişi yok',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$customerName için henüz kiralama kaydı bulunmuyor',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Tarihe göre sırala (en yeni önce)
          final rentals = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
          rentals.sort((a, b) {
            final aDate = (a.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
            final bDate = (b.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate); // En yeni önce
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rentals.length,
            itemBuilder: (context, index) {
              final doc = rentals[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final startDate = (data['startDate'] as Timestamp?)?.toDate();
              final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();
              final actualReturn = (data['actualReturnDate'] as Timestamp?)?.toDate();
              final status = data['status'] as String? ?? 'bilinmiyor';
              
              final bool isActive = status == 'aktif';
              final bool isCompleted = status == 'tamamlandi';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['equipmentName'] ?? 'Ekipman adı yok',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                            ),
                            backgroundColor: isActive
                                ? Colors.green[100]
                                : isCompleted
                                    ? Colors.blue[100]
                                    : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isActive
                                  ? Colors.green[900]
                                  : isCompleted
                                      ? Colors.blue[900]
                                      : Colors.grey[900],
                            ),
                          ),
                        ],
                      ),
                      if (startDate != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Başlangıç',
                          value: DateFormat('dd.MM.yyyy').format(startDate),
                        ),
                      ],
                      if (plannedReturn != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.event_outlined,
                          label: 'Planlanan Dönüş',
                          value: DateFormat('dd.MM.yyyy').format(plannedReturn),
                        ),
                      ],
                      if (actualReturn != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.check_circle_outline,
                          label: 'Gerçek Dönüş',
                          value: DateFormat('dd.MM.yyyy').format(actualReturn),
                        ),
                      ],
                      if (data['extras'] != null && (data['extras'] as String).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.orange[900]!.withValues(alpha: 0.2)
                                : Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.note_outlined,
                                size: 20,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ekstralar / Notlar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['extras'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[300]
                                            : Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (data['createdByName'] != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Kiralamayı Yapan',
                          value: data['createdByName'] ?? data['createdByEmail'] ?? 'Bilinmiyor',
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

