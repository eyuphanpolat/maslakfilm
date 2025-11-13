import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../widgets/user_app_bar.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String? employeeEmail;
  final Map<String, dynamic> employeeData;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.employeeEmail,
    required this.employeeData,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UserAppBar(title: widget.employeeName),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Mobilde (genişlik < 800) dikey, desktop'ta yatay
                if (constraints.maxWidth < 800) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üst - Kiralamalar
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: _buildRentalsSection(),
                      ),
                      const SizedBox(height: 16),
                      // Alt - Teslim Alımlar
                      Expanded(
                        child: _buildDeliveriesSection(),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol taraf - Kiralamalar
                      Expanded(
                        child: _buildRentalsSection(),
                      ),
                      const SizedBox(width: 16),
                      // Sağ taraf - Teslim Alımlar
                      Expanded(
                        child: _buildDeliveriesSection(),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRentalsSection() {
    return Card(
      color: Colors.grey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Kiralamalar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .orderBy('startDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Henüz kiralama yapılmamış'),
                    ),
                  );
                }

                // Çalışanın email veya name ile eşleşen kiralamaları filtrele
                final filteredRentals = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdByEmail = (data['createdByEmail'] as String?)?.toLowerCase().trim();
                  final createdByName = (data['createdByName'] as String?)?.toLowerCase().trim();
                  final empEmail = widget.employeeEmail?.toLowerCase().trim();
                  final empName = widget.employeeName.toLowerCase().trim();
                  
                  return (empEmail != null && createdByEmail == empEmail) ||
                         (createdByName != null && createdByName == empName) ||
                         (empEmail != null && createdByName != null && createdByName.contains(empName.split(' ').first.toLowerCase()));
                }).toList();

                if (filteredRentals.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Henüz kiralama yapılmamış'),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredRentals.length,
                  itemBuilder: (context, index) {
                    final doc = filteredRentals[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final equipmentName = data['equipmentName'] as String? ?? 
                        (data['equipmentNames'] as List<dynamic>?)?.join(', ') ?? 
                        'Bilinmiyor';
                    final customerName = data['customerName'] as String? ?? 'Bilinmiyor';
                    final startDate = (data['startDate'] as Timestamp?)?.toDate();
                    final plannedReturnDate = (data['plannedReturnDate'] as Timestamp?)?.toDate();
                    final status = data['status'] as String? ?? 'bilinmiyor';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.grey[800],
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.assignment,
                          color: status == 'aktif' ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          equipmentName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Müşteri: $customerName',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                            if (startDate != null)
                              Text(
                                'Başlangıç: ${DateFormat('dd.MM.yyyy', 'tr_TR').format(startDate)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                              ),
                            if (plannedReturnDate != null)
                              Text(
                                'Planlanan Teslim: ${DateFormat('dd.MM.yyyy', 'tr_TR').format(plannedReturnDate)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                              ),
                            if (data['extras'] != null && (data['extras'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '📝 ${data['extras'] as String}',
                                  style: TextStyle(fontSize: 10, color: Colors.orange[300], fontStyle: FontStyle.italic),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'aktif' ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status == 'aktif' ? 'Aktif' : 'Tamamlandı',
                            style: TextStyle(
                              fontSize: 10,
                              color: status == 'aktif' ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesSection() {
    return Card(
      color: Colors.grey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Teslim Alımlar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .where('status', isEqualTo: 'tamamlandi')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Henüz teslim alım yapılmamış'),
                    ),
                  );
                }

                // Çalışanın email veya name ile eşleşen teslim alımları filtrele
                final filteredDeliveries = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final returnedByEmail = (data['returnedByEmail'] as String?)?.toLowerCase().trim();
                  final returnedByName = (data['returnedByName'] as String?)?.toLowerCase().trim();
                  final empEmail = widget.employeeEmail?.toLowerCase().trim();
                  final empName = widget.employeeName.toLowerCase().trim();
                  
                  return (empEmail != null && returnedByEmail == empEmail) ||
                         (returnedByName != null && returnedByName == empName) ||
                         (empEmail != null && returnedByName != null && returnedByName.contains(empName.split(' ').first.toLowerCase()));
                }).toList();

                // Tarihe göre sırala
                filteredDeliveries.sort((a, b) {
                  final aDate = (a.data() as Map<String, dynamic>)['actualReturnDate'] as Timestamp?;
                  final bDate = (b.data() as Map<String, dynamic>)['actualReturnDate'] as Timestamp?;
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate);
                });

                if (filteredDeliveries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Henüz teslim alım yapılmamış'),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredDeliveries.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDeliveries[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final equipmentName = data['equipmentName'] as String? ?? 
                        (data['equipmentNames'] as List<dynamic>?)?.join(', ') ?? 
                        'Bilinmiyor';
                    final customerName = data['customerName'] as String? ?? 'Bilinmiyor';
                    final actualReturnDate = (data['actualReturnDate'] as Timestamp?)?.toDate();
                    final startDate = (data['startDate'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.grey[800],
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.orange,
                          size: 20,
                        ),
                        title: Text(
                          equipmentName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Müşteri: $customerName',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                            if (startDate != null)
                              Text(
                                'Kiralama Başlangıç: ${DateFormat('dd.MM.yyyy', 'tr_TR').format(startDate)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                              ),
                            if (actualReturnDate != null)
                              Text(
                                'Teslim Alım: ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(actualReturnDate)}',
                                style: TextStyle(fontSize: 11, color: Colors.orange[300]),
                              ),
                            if (data['extras'] != null && (data['extras'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '📝 ${data['extras'] as String}',
                                  style: TextStyle(fontSize: 10, color: Colors.orange[300], fontStyle: FontStyle.italic),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Teslim Alındı',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

