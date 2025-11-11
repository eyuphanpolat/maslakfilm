import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/user_app_bar.dart';

class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
  }

  // Çoklu ekipman var mı kontrol et
  bool _hasMultipleEquipment(Map<String, dynamic> data) {
    final equipmentNames = data['equipmentNames'] as List<dynamic>?;
    return equipmentNames != null && equipmentNames.length > 1;
  }

  // Tüm ekipman isimlerini kamera öncelikli sıralı döndür
  List<String> _getAllEquipmentNames(Map<String, dynamic> data) {
    final equipmentNames = data['equipmentNames'] as List<dynamic>?;
    if (equipmentNames == null || equipmentNames.isEmpty) {
      final singleName = data['equipmentName'] as String?;
      return singleName != null ? [singleName] : [];
    }
    
    // Kamera öncelikli sıralama
    final sortedNames = List<String>.from(equipmentNames.map((e) => e.toString()));
    sortedNames.sort((a, b) {
      final aIsCamera = a.toLowerCase().contains('kamera');
      final bIsCamera = b.toLowerCase().contains('kamera');
      if (aIsCamera && !bIsCamera) return -1;
      if (!aIsCamera && bIsCamera) return 1;
      return a.compareTo(b);
    });
    
    return sortedNames;
  }

  // Ekipman adını göster: Çoklu ekipman varsa ilkini göster, yoksa tek adı göster
  String _getEquipmentDisplayName(Map<String, dynamic> data) {
    final equipmentNames = _getAllEquipmentNames(data);
    
    if (equipmentNames.isEmpty) {
      return 'Ekipman adı yok';
    }
    
    if (equipmentNames.length == 1) {
      return equipmentNames.first;
    }
    
    // Çoklu ekipman varsa ilkini (öncelikli) göster
    return equipmentNames.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Kiralama'),
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
                    Icons.assignment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aktif kiralama yok',
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

          // Tarihe göre sırala (en yeni önce)
          final sortedDocs = List<QueryDocumentSnapshot>.from([...activeDocs, ...completedDocs]);
          sortedDocs.sort((a, b) {
            final aDate = (a.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
            final bDate = (b.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate); // En yeni önce
          });

          // Takvim için event map oluştur
          final Map<DateTime, List<Map<String, dynamic>>> eventsMap = {};
          for (var doc in sortedDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();
            final actualReturn = (data['actualReturnDate'] as Timestamp?)?.toDate();
            final isActive = data['status'] == 'aktif';
            
            // Başlangıç tarihi
            if (startDate != null) {
              final dateKey = DateTime(startDate.year, startDate.month, startDate.day);
              eventsMap.putIfAbsent(dateKey, () => []).add({
                'id': doc.id,
                'data': data,
                'type': isActive ? 'start' : 'completed_start',
              });
            }
            // Planlanan dönüş tarihi
            if (plannedReturn != null) {
              final dateKey = DateTime(plannedReturn.year, plannedReturn.month, plannedReturn.day);
              eventsMap.putIfAbsent(dateKey, () => []).add({
                'id': doc.id,
                'data': data,
                'type': isActive ? 'return' : 'completed',
              });
            }
            // Gerçek dönüş tarihi (tamamlanmış kayıtlar için)
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
                          ? Colors.orange[400]
                          : Colors.orange,
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
                  child: _buildRentalsList(context, filteredRentals, selectedDayEvents.isNotEmpty),
                ),
              ],
            );
        },
      ),
    );
  }

  Widget _buildRentalsList(BuildContext context, List<QueryDocumentSnapshot> rentals, bool isFiltered) {
    if (rentals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.event_busy : Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? '${DateFormat('dd.MM.yyyy').format(_selectedDay)} tarihinde kiralama yok'
                  : 'Aktif kiralama yok',
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
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Theme.of(context).cardColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Detay sayfası için
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getEquipmentDisplayName(data),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            // Çoklu ekipman varsa tümünü göster
                            if (_hasMultipleEquipment(data)) ...[
                              const SizedBox(height: 8),
                              ..._getAllEquipmentNames(data).map((name) => Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(data['status'] == 'aktif' ? 'Aktif' : 'Tamamlandı'),
                        backgroundColor: data['status'] == 'aktif' 
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.green[900]!.withValues(alpha: 0.3)
                                : Colors.green[100])
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[300]),
                        labelStyle: TextStyle(
                          color: data['status'] == 'aktif' 
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green[300]
                                  : Colors.green[900])
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[300]
                                  : Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (data['createdByName'] != null || data['createdByEmail'] != null) ...[
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Kiralamayı Yapan',
                      value: data['createdByName'] ?? data['createdByEmail'] ?? 'Bilinmiyor',
                    ),
                    const SizedBox(height: 12),
                  ],
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Müşteri',
                    value: data['customerName'] ?? 'Bilinmiyor',
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
                ],
              ),
            ),
          ),
        );
      },
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

