import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/rentals_screen.dart';
import 'screens/deliveries_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/equipment_list_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/qr_action_selection_screen.dart';
import 'screens/monthly_report_screen.dart';
import 'widgets/user_app_bar.dart';
import 'utils/migrate_qr_codes.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaslakFilm',
      themeMode: ThemeMode.dark, // Sadece karanlık mod kullan
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          brightness: Brightness.dark,
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.grey[300]!,
          onSecondary: Colors.black,
          tertiary: Colors.grey[400]!,
          onTertiary: Colors.black,
          error: Colors.white70,
          onError: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
          surfaceContainerHighest: Colors.grey[900]!,
          onSurfaceVariant: Colors.white70,
          outline: Colors.grey[700]!,
          outlineVariant: Colors.grey[800]!,
        ),
        scaffoldBackgroundColor: Colors.black,
        cardTheme: CardThemeData(
          color: Colors.grey[900],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const AuthGate(child: MyHomePage(title: 'MaslakFilm')),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const SignInScreen();
        return child;
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  // Logo widget'ı - logo dosyası yoksa hiçbir şey göstermez
  Widget _buildLogo(String path, {required double height}) {
    return Image.asset(
      path,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Logo yüklenemedi: $path - Hata: $error');
        return const SizedBox.shrink();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _makeEmailsAdminOnStartup();
    _migrateQRCodes();
  }
  
  Future<void> _migrateQRCodes() async {
    // Kategori adlarını güncelle (Monitör/Kayıt Cihazı -> Monitör)
    try {
      await MigrateQRCodes.migrateCategoryNames();
    } catch (e) {
      debugPrint('Kategori migration hatası: $e');
    }
    
    // Tüm ekipmanların QR kodlarını 5 harfe güncelle
    try {
      await MigrateQRCodes.migrateAllQRCodes();
    } catch (e) {
      debugPrint('QR kod migration hatası: $e');
    }
  }

  Future<void> _makeEmailsAdminOnStartup() async {
    // Verilen email'leri admin yap
    final adminEmails = ['polathakki@gmail.com', 'eyuphanpolatt@gmail.com'];
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Eğer mevcut kullanıcı varsa ve admin email'lerinden biri ise, direkt admin yap
      if (currentUser != null && currentUser.email != null) {
        final userEmail = currentUser.email!.toLowerCase().trim();
        
        if (adminEmails.contains(userEmail)) {
          // Kullanıcının UID'sine göre direkt admin yap
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({
            'email': userEmail,
            'role': 'admin',
            'isAdmin': true,
          }, SetOptions(merge: true));
          
          debugPrint('✅ $userEmail admin yapıldı (mevcut kullanıcı)');
        }
      }
      
      // Ayrıca email'e göre de ara (eğer farklı bir kullanıcı giriş yaptıysa)
      for (final email in adminEmails) {
        try {
          // Email'e göre users koleksiyonunda ara
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email.toLowerCase().trim())
              .limit(1)
              .get();

          if (usersSnapshot.docs.isNotEmpty) {
            // Kullanıcı bulundu, admin yap
            final userId = usersSnapshot.docs.first.id;
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .set({
              'email': email.toLowerCase().trim(),
              'role': 'admin',
              'isAdmin': true,
            }, SetOptions(merge: true));
            debugPrint('✅ $email admin yapıldı');
          } else {
            debugPrint('⚠️ Kullanıcı bulunamadı (henüz giriş yapmamış): $email');
          }
        } catch (e) {
          debugPrint('❌ Hata ($email): $e');
        }
      }
    } catch (e) {
      debugPrint('Admin yapma hatası: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: UserAppBar(
        title: widget.title,
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo - Ana sayfa üstünde (logo dosyası eklendiğinde görünecek)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _buildLogo('assets/images/logo_white.png', height: 250),
                ),
              ),
              const _NotificationsSection(),
              const SizedBox(height: 24),
              Text(
                'Menü',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              StreamBuilder<DocumentSnapshot?>(
                stream: user != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots()
                    : null,
                builder: (context, snapshot) {
                  // Admin kontrolü: role == 'admin' veya isAdmin == true veya email admin listesinde
                  bool isAdmin = false;
                  
                  // Önce email kontrolü yap (daha hızlı)
                  final adminEmails = ['polathakki@gmail.com', 'eyuphanpolatt@gmail.com'];
                  final userEmail = user?.email?.toLowerCase().trim();
                  if (userEmail != null && adminEmails.contains(userEmail)) {
                    isAdmin = true;
                  }
                  
                  // Sonra Firestore'dan kontrol et
                  if (!isAdmin && snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final role = data?['role'] as String?;
                    final adminFlag = data?['isAdmin'] as bool?;
                    
                    isAdmin = role == 'admin' || adminFlag == true;
                  }
                  
                  // Responsive grid: Ekran genişliğine göre sütun sayısı
                  final screenWidth = MediaQuery.of(context).size.width;
                  int crossAxisCount = 3;
                  double childAspectRatio = 0.85;
                  
                  if (screenWidth < 600) {
                    // Mobil: 2 sütun
                    crossAxisCount = 2;
                    childAspectRatio = 0.9;
                  } else if (screenWidth < 900) {
                    // Tablet: 3 sütun
                    crossAxisCount = 3;
                    childAspectRatio = 0.85;
                  } else {
                    // Desktop: 3 sütun (daha geniş)
                    crossAxisCount = 3;
                    childAspectRatio = 0.85;
                  }
                  
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                    children: [
                      _MenuCard(
                        title: 'QR Tara',
                        icon: Icons.qr_code_scanner,
                        color: Colors.grey,
                        gradientStart: Colors.grey[800]!,
                        gradientEnd: Colors.grey[900]!,
                        onTap: () {
                          debugPrint('QR Tara butonuna tıklandı - QRActionSelectionScreen açılıyor');
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const QRActionSelectionScreen()),
                          );
                        },
                      ),
                      _MenuCard(
                        title: 'Kiralama',
                        icon: Icons.assignment_outlined,
                        color: Colors.grey,
                        gradientStart: Colors.grey[800]!,
                        gradientEnd: Colors.grey[900]!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RentalsScreen()),
                          );
                        },
                      ),
                      _MenuCard(
                        title: 'Teslim Alım',
                        icon: Icons.check_circle_outline,
                        color: Colors.grey,
                        gradientStart: Colors.grey[800]!,
                        gradientEnd: Colors.grey[900]!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DeliveriesScreen()),
                          );
                        },
                      ),
                      _MenuCard(
                        title: 'Müşteriler',
                        icon: Icons.people_outline,
                        color: Colors.grey,
                        gradientStart: Colors.grey[800]!,
                        gradientEnd: Colors.grey[900]!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CustomersScreen()),
                          );
                        },
                      ),
                      _MenuCard(
                        title: 'Ekipmanlar',
                        icon: Icons.camera_alt_outlined,
                        color: Colors.grey,
                        gradientStart: Colors.grey[800]!,
                        gradientEnd: Colors.grey[900]!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EquipmentListScreen()),
                          );
                        },
                      ),
                      _MenuCard(
                        title: 'Aylık Rapor',
                        icon: Icons.assessment_outlined,
                        color: Colors.grey,
                        gradientStart: Colors.grey[800]!,
                        gradientEnd: Colors.grey[900]!,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MonthlyReportScreen()),
                          );
                        },
                      ),
                      // Sadece admin kullanıcılar için Çalışanlar butonu
                      if (isAdmin)
                        _MenuCard(
                          title: 'Çalışanlar',
                          icon: Icons.badge_outlined,
                          color: Colors.grey,
                          gradientStart: Colors.grey[800]!,
                          gradientEnd: Colors.grey[900]!,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const EmployeesScreen()),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Özet',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const _SummaryCards(),
            ],
          ),
        ),
      ),
    );
  }

}

class _MenuCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color gradientStart;
  final Color gradientEnd;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.gradientStart,
    required this.gradientEnd,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: EdgeInsets.all(_isHovered ? 2 : 0),
        child: Card(
          elevation: _isHovered ? 12 : 6,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[900], // Gri-siyah arka plan
                border: Border.all(
                  color: Colors.grey[700]!,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SummaryCard(
            title: 'Toplam Ekipman',
            value: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('equipment')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text('$count');
              },
            ),
            icon: Icons.camera_alt,
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EquipmentListScreen()),
              );
            },
          ),
          _SummaryCard(
            title: 'Kiralamada',
            value: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('equipment')
                  .where('status', isEqualTo: 'kiralamada')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text('$count');
              },
            ),
            icon: Icons.assignment,
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RentalsScreen()),
              );
            },
          ),
          _SummaryCard(
            title: 'Aktif Kiralama',
            value: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .where('status', isEqualTo: 'aktif')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text('$count');
              },
            ),
            icon: Icons.event_available,
            color: Colors.green,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RentalsScreen()),
              );
            },
          ),
          _SummaryCard(
            title: 'Bugün Teslim',
            value: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rentals')
                  .where('status', isEqualTo: 'aktif')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text(
                    '0',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                
                final now = DateTime.now();
                int todayCount = 0;
                
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();
                  if (plannedReturn != null) {
                    if (plannedReturn.year == now.year &&
                        plannedReturn.month == now.month &&
                        plannedReturn.day == now.day) {
                      todayCount++;
                    }
                  }
                }
                
                return Text(
                  '$todayCount',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            icon: Icons.today,
            color: Colors.red,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeliveriesScreen()),
              );
            },
          ),
          _SummaryCard(
            title: 'Toplam Müşteri',
            value: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text('$count');
              },
            ),
            icon: Icons.people,
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Widget value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color, size: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                  child: value,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bildirimler',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rentals')
              .where('status', isEqualTo: 'aktif')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Bugün teslim alınacak kiralamaları filtrele
            final now = DateTime.now();
            final dueToday = <Map<String, dynamic>>[];
            
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final plannedReturn = (data['plannedReturnDate'] as Timestamp?)?.toDate();
                
                if (plannedReturn != null) {
                  if (plannedReturn.year == now.year &&
                      plannedReturn.month == now.month &&
                      plannedReturn.day == now.day) {
                    dueToday.add({
                      'id': doc.id,
                      'equipmentName': data['equipmentName'] ?? 'Bilinmiyor',
                      'customerName': data['customerName'] ?? 'Bilinmiyor',
                      'plannedReturnDate': plannedReturn,
                    });
                  }
                }
              }
            }

            final hasNotifications = dueToday.isNotEmpty;

            if (!hasNotifications) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.green[400]
                            : Colors.green[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bugün teslim alınacak kiralama yok',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dueToday.isNotEmpty) ...[
                  Card(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red[900]!.withValues(alpha: 0.3)
                        : Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.red[300]
                                : Colors.red[700],
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${dueToday.length} Kiralama Bugün Teslim Alınacak',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.red[300]
                                        : Colors.red[900],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...dueToday.take(2).map((rental) => Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    '• ${rental['equipmentName']} - ${rental['customerName']}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[200]
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                                if (dueToday.length > 2)
                                  Text(
                                    '... ve ${dueToday.length - 2} kiralama daha',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: NotificationService.getLowStockEquipment(),
                  builder: (context, stockSnapshot) {
                    if (stockSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    final lowStock = stockSnapshot.data ?? [];

                    if (lowStock.isNotEmpty) {
                      return Card(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange[900]!.withValues(alpha: 0.3)
                            : Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.orange[300]
                                    : Colors.orange[700],
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Düşük Stok Uyarısı',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.orange[300]
                                            : Colors.orange[900],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...lowStock.take(2).map((equipment) => Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        '• ${equipment['name']} - Stok: ${equipment['stock']}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: 11,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.grey[200]
                                              : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                                    if (lowStock.length > 2)
                                      Text(
                                        '... ve ${lowStock.length - 2} ekipman daha',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// Temalı SignIn/SignUp ekranları ayrı dosyalardadır (screens/auth/...)
