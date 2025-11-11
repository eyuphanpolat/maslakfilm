import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/user_app_bar.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UserAppBar(title: 'Çalışanlar'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Çalışan Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('employees')
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
                    Icons.badge_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz çalışan yok',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yeni çalışan eklemek için + butonuna tıklayın',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    data['name'] ?? 'İsimsiz Çalışan',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['email'] != null)
                        Text('E-posta: ${data['email']}'),
                      if (data['phone'] != null)
                        Text('Telefon: ${data['phone']}'),
                      if (data['position'] != null)
                        Text('Pozisyon: ${data['position']}'),
                      if (data['department'] != null)
                        Text('Departman: ${data['department']}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditEmployeeDialog(context, doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteEmployee(context, doc.id),
                      ),
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

  void _showAddEmployeeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final positionController = TextEditingController();
    final departmentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Çalışan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(
                  labelText: 'Pozisyon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Departman',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
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
                  const SnackBar(content: Text('Ad soyad gereklidir')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance.collection('employees').add({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim().isEmpty
                      ? null
                      : emailController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  'position': positionController.text.trim().isEmpty
                      ? null
                      : positionController.text.trim(),
                  'department': departmentController.text.trim().isEmpty
                      ? null
                      : departmentController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Çalışan eklendi')),
                  );
                }
              } catch (e) {
                // Hata sessizce log edilir
                debugPrint('Çalışan işlemi hatası: $e');
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showEditEmployeeDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final nameController = TextEditingController(text: data['name'] ?? '');
    final emailController = TextEditingController(text: data['email'] ?? '');
    final phoneController = TextEditingController(text: data['phone'] ?? '');
    final positionController = TextEditingController(text: data['position'] ?? '');
    final departmentController = TextEditingController(text: data['department'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çalışan Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: positionController,
                decoration: const InputDecoration(
                  labelText: 'Pozisyon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Departman',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
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
                  const SnackBar(content: Text('Ad soyad gereklidir')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance.collection('employees').doc(docId).update({
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim().isEmpty
                      ? null
                      : emailController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  'position': positionController.text.trim().isEmpty
                      ? null
                      : positionController.text.trim(),
                  'department': departmentController.text.trim().isEmpty
                      ? null
                      : departmentController.text.trim(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Çalışan güncellendi')),
                  );
                }
              } catch (e) {
                // Hata sessizce log edilir
                debugPrint('Çalışan işlemi hatası: $e');
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çalışanı Sil'),
        content: const Text('Bu çalışanı silmek istediğinizden emin misiniz?'),
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

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('employees').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çalışan silindi')),
          );
        }
      } catch (e) {
        // Hata sessizce log edilir
        debugPrint('Çalışan silme hatası: $e');
      }
    }
  }
}

