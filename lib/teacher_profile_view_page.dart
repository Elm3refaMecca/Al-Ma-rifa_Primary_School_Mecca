import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherProfileViewPage extends StatelessWidget {
  final String teacherId;

  const TeacherProfileViewPage({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
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
            return const Center(child: Text('حدث خطأ في جلب البيانات.'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('لم يتم العثور على بيانات المعلم.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, size: 60, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(Icons.person_outline, 'الاسم', userData['name'] ?? 'غير متوفر'),
                      const Divider(),
                      _buildInfoRow(Icons.work_outline, 'الوظيفة 1', userData['profession1'] ?? 'غير متوفر'),
                      if (userData['profession2'] != null && (userData['profession2'] as String).isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow(Icons.work_outline, 'الوظيفة 2', userData['profession2']),
                      ],
                      if (userData['profession3'] != null && (userData['profession3'] as String).isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow(Icons.work_outline, 'الوظيفة 3', userData['profession3']),
                      ],
                      const Divider(),
                      _buildInfoRow(Icons.phone_outlined, 'رقم الهاتف للتواصل', userData['number'] ?? 'غير معروف'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const SizedBox(width: 16),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade700))),
        ],
      ),
    );
  }
}
