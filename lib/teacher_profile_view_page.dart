import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherProfileViewPage extends StatelessWidget {
  final String teacherId;

  const TeacherProfileViewPage({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملف المعلم الشخصي'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(teacherId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Error fetching teacher data: ${snapshot.error}");
            return const Center(child: Text('حدث خطأ أثناء جلب بيانات المعلم.'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('لم يتم العثور على بيانات المعلم.'));
          }

          final data = snapshot.data!.data();
          if (data == null || data is! Map<String, dynamic>) {
            return const Center(child: Text('صيغة بيانات المعلم غير صحيحة.'));
          }
          final userData = data;

          final String name = userData['name'] ?? 'اسم غير متوفر';
          final String? photoUrl = userData['photo']; // جلب رابط الصورة
          final String profession1 = userData['profession1'] ?? 'غير متوفر';
          final String? profession2 = userData['profession2'];
          final String? profession3 = userData['profession3'];
          // --- تعديل: استخدام حقل 'phone' ---
          final String phoneNumber = userData['phone'] ?? 'غير متوفر';


          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: primaryColor.withOpacity(0.1),
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Icon(Icons.person, size: 60, color: primaryColor)
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _buildInfoRow(Icons.work_outline, 'المادة الأساسية', profession1),
                      if (profession2 != null && profession2.isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow(Icons.work_outline, 'المادة الثانية', profession2),
                      ],
                      if (profession3 != null && profession3.isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow(Icons.work_outline, 'المادة الثالثة', profession3),
                      ],
                      const Divider(),
                      _buildInfoRow(Icons.phone_outlined, 'للتواصل', phoneNumber),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade800, fontSize: 16))),
              ],
            ),
          );
        }
    );
  }
}