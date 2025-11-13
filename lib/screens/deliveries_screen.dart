import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/user_app_bar.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Teslim Alım'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rentals')
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
                    const SizedBox(height: 16),
                    const Text(
                      'Firebase Firestore\'da index oluşturmanız gerekebilir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
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
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Teslim alınacak kiralama yok',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // Aktif ve tamamlanmış kiralama kayıtlarını ayır
          final allDocs = snapshot.data!.docs;
          final activeDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'aktif';
          }).toList();
          
          final completedDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'tamamlandi' || data['status'] == 'tamamlandı';
          }).toList();

          // Tarihe göre sırala (planlanan dönüş tarihine göre)
          final sortedDocs = List<QueryDocumentSnapshot>.from([...activeDocs, ...completedDocs]);
          sortedDocs.sort((a, b) {
            final aDate = (a.data() as Map<String, dynamic>)['plannedReturnDate'] as Timestamp?;
            final bDate = (b.data() as Map<String, dynamic>)['plannedReturnDate'] as Timestamp?;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate); // En yakın önce
          });

          // Takvim için event map oluştur
          final Map<DateTime, List<Map<String, dynamic>>> eventsMap = {};
          for (var doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();
            final actualReturn = (data['actualReturnDate'] as Timestamp?)?.toDate();
            final isActive = data['status'] == 'aktif';
            
            // Planlanan teslim tarihi
            if (plannedReturn != null) {
              final dateKey = DateTime(plannedReturn.year, plannedReturn.month, plannedReturn.day);
              eventsMap.putIfAbsent(dateKey, () => []).add({
                'id': doc.id,
                'data': data,
                'type': isActive ? 'delivery' : 'completed',
              });
            }
            
            // Gerçek teslim tarihi (tamamlanmış kayıtlar için)
            if (actualReturn != null && !isActive) {
              final dateKey = DateTime(actualReturn.year, actualReturn.month, actualReturn.day);
              eventsMap.putIfAbsent(dateKey, () => []).add({
                'id': doc.id,
                'data': data,
                'type': 'completed',
              });
            }
          }

          // Seçili tarihteki işlemleri filtrele
          final selectedDateKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          final selectedDayEvents = eventsMap[selectedDateKey] ?? [];
          final selectedDayRentals = selectedDayEvents.map((e) => e['id'] as String).toSet();
          final filteredRentals = selectedDayEvents.isNotEmpty
              ? sortedDocs.where((doc) => selectedDayRentals.contains(doc.id)).toList()
              : sortedDocs;

          return Column(
              children: [
                TableCalendar<Map<String, dynamic>>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  locale: 'tr_TR',
                  eventLoader: (day) {
                    final dateKey = DateTime(day.year, day.month, day.day);
                    return eventsMap[dateKey] ?? [];
                  },
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: true,
                    outsideTextStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[400],
                    ),
                    defaultTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    weekendTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.blue.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    markerDecoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red[400]
                          : Colors.red,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    titleTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    formatButtonTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                ),
                Divider(
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: _buildDeliveriesList(context, filteredRentals, selectedDayEvents.isNotEmpty),
                ),
              ],
            );
        },
      ),
    );
  }

  Widget _buildDeliveriesList(BuildContext context, List<QueryDocumentSnapshot> rentals, bool isFiltered) {
    if (rentals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.event_busy : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? '${DateFormat('dd.MM.yyyy').format(_selectedDay)} tarihinde teslim alınacak kiralama yok'
                  : 'Teslim alınacak kiralama yok',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rentals.length,
      itemBuilder: (context, index) {
        final doc = rentals[index];
        final data = doc.data() as Map<String, dynamic>;
        
        final startDate = (data['startDate'] as Timestamp?)?.toDate();
        final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();
        final actualReturn = (data['actualReturnDate'] as Timestamp?)?.toDate();
        final isActive = data['status'] == 'aktif';
        final isDueToday = isActive && plannedReturn != null && 
            plannedReturn.year == DateTime.now().year &&
            plannedReturn.month == DateTime.now().month &&
            plannedReturn.day == DateTime.now().day;
        final isOverdue = isActive && plannedReturn != null && 
            plannedReturn.isBefore(DateTime.now()) && 
            !isDueToday;
        
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: !isActive
              ? isDark
                  ? Colors.grey[800]
                  : Colors.grey[100]
              : isDueToday
                  ? isDark
                      ? Colors.red[900]!.withValues(alpha: 0.3)
                      : Colors.red[50]
                  : isOverdue
                      ? isDark
                          ? Colors.orange[900]!.withValues(alpha: 0.3)
                          : Colors.orange[50]
                      : theme.cardColor,
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
                    if (data['status'] == 'aktif') ...[
                      if (isDueToday)
                        Chip(
                          label: const Text('Bugün'),
                          backgroundColor: isDark
                              ? Colors.red[900]!.withValues(alpha: 0.3)
                              : Colors.red[100],
                          labelStyle: TextStyle(
                            color: isDark ? Colors.red[300] : Colors.red[900],
                          ),
                        )
                      else if (isOverdue)
                        Chip(
                          label: const Text('Gecikmiş'),
                          backgroundColor: isDark
                              ? Colors.orange[900]!.withValues(alpha: 0.3)
                              : Colors.orange[100],
                          labelStyle: TextStyle(
                            color: isDark ? Colors.orange[300] : Colors.orange[900],
                          ),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _completeDelivery(context, doc.id, data['equipmentId']),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Teslim Al'),
                      ),
                    ] else ...[
                      Chip(
                        label: const Text('Tamamlandı'),
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                        labelStyle: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Müşteri',
                  value: data['customerName'] ?? 'Bilinmiyor',
                ),
                if (data['createdByName'] != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Kiralamayı Yapan',
                    value: data['createdByName'] ?? data['createdByEmail'] ?? 'Bilinmiyor',
                  ),
                ],
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
                if (actualReturn != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.check_circle_outline,
                    label: 'Gerçek Dönüş',
                    value: DateFormat('dd.MM.yyyy').format(actualReturn),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _completeDelivery(
    BuildContext context,
    String rentalId,
    String? equipmentId,
  ) async {
    if (equipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ekipman ID bulunamadı')),
      );
      return;
    }

    try {
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
      
      // Kiralama durumunu tamamlandı olarak işaretle
      await FirebaseFirestore.instance.collection('rentals').doc(rentalId).update({
        'status': 'tamamlandi',
        'actualReturnDate': Timestamp.now(),
        'returnedByEmail': returnedByEmail,
        'returnedByName': returnedByName,
      });

      // Ekipman stokunu artır ve ofiste olarak işaretle
      final equipmentDoc = await FirebaseFirestore.instance.collection('equipment').doc(equipmentId).get();
      final currentStock = equipmentDoc.data()?['stock'] as int? ?? 0;
      
      await FirebaseFirestore.instance.collection('equipment').doc(equipmentId).update({
        'stock': currentStock + 1,
        'status': 'ofiste',
        'currentRentalId': null,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teslim alım tamamlandı')),
        );
      }
    } catch (e) {
      // Hata sessizce log edilir
      debugPrint('Teslim alım hatası: $e');
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

