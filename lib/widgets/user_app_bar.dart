import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const UserAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: isDark ? Colors.grey[900] : Colors.black,
      title: Row(
        children: [
          // Logo (logo dosyası eklendiğinde görünecek)
          _buildLogo('assets/images/logo_white.png', height: 28),
          const SizedBox(width: 12),
          // Sol üstte kullanıcı adı
          StreamBuilder<DocumentSnapshot?>(
            stream: user != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              String userName = '';
              bool isAdmin = false;
              
              // Admin kontrolü
              final adminEmails = ['polathakki@gmail.com', 'eyuphanpolatt@gmail.com'];
              final userEmail = user?.email?.toLowerCase().trim();
              if (userEmail != null && adminEmails.contains(userEmail)) {
                isAdmin = true;
              }
              
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final firstName = data?['firstName'] as String?;
                final lastName = data?['lastName'] as String?;
                
                if (firstName != null && lastName != null) {
                  userName = '$firstName $lastName';
                } else if (firstName != null) {
                  userName = firstName;
                } else if (data?['displayName'] != null) {
                  userName = data!['displayName'] as String;
                }
                
                // Firestore'dan admin kontrolü
                if (!isAdmin) {
                  final role = data?['role'] as String?;
                  final adminFlag = data?['isAdmin'] as bool?;
                  isAdmin = role == 'admin' || adminFlag == true;
                }
              }
              
              // Firestore'da yoksa Firebase Auth'dan al
              if (userName.isEmpty) {
                if (user?.displayName != null && user!.displayName!.isNotEmpty) {
                  userName = user.displayName!;
                } else if (user?.email != null) {
                  // Email'den kullanıcı adı çıkar (örn: "ahmet@example.com" -> "ahmet")
                  final emailParts = user!.email!.split('@');
                  userName = emailParts[0];
                }
              }
              
              if (userName.isEmpty) {
                userName = 'Kullanıcı';
              }
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      userName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            '|',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(width: 8),
          // Sayfa başlığı
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

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
}

