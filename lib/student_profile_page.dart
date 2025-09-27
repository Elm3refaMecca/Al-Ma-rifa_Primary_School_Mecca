import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    if (_user?.email == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: _user!.email)
          .limit(1)
          .get();

      if (mounted) {
        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            _studentData = querySnapshot.docs.first.data();
          });
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي للطالب'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? const Center(child: Text('الرجاء تسجيل الدخول لعرض الملف الشخصي.'))
          : _studentData == null
          ? const Center(child: Text('لم يتم العثور على بيانات الطالب.'))
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.person_pin, size: 60, color: Colors.blue.shade800),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _studentData?['name'] ?? 'اسم غير متوفر',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _user?.email ?? 'بريد إلكتروني غير متوفر',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoRow(Icons.email_outlined, 'البريد الإلكتروني', _user?.email ?? 'غير متوفر'),
                  const Divider(),
                  // --- تعديل: استخدام أسماء الحقول الصحيحة ---
                  _buildInfoRow(Icons.phone_outlined, 'هاتف ولي الأمر', _studentData?['guardianPhone'] ?? 'غير متوفر'),
                  const Divider(),
                  _buildInfoRow(Icons.layers_outlined, 'المرحلة', _studentData?['stages'] ?? 'غير متوفر'),
                  const Divider(),
                  _buildInfoRow(Icons.school_outlined, 'الصف', _studentData?['grades'] ?? 'غير متوفر'),
                  const Divider(),
                  _buildInfoRow(Icons.class_outlined, 'الفصل', _studentData?['classes'] ?? 'غير متوفر'),
                  const Divider(),
                  _buildInfoRow(Icons.calendar_today_outlined, 'الترم', _studentData?['terms'] ?? 'غير متوفر'),
                ],
              ),
            ),
          ),
        ],
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
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade800, fontSize: 16))),
        ],
      ),
    );
  }
}