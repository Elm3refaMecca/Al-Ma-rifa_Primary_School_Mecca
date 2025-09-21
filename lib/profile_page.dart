import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
        if (mounted) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>?;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل في جلب البيانات: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? const Center(child: Text('الرجاء تسجيل الدخول لعرض الملف الشخصي.'))
          : _userData == null
          ? const Center(child: Text('لم يتم العثور على بيانات المستخدم.'))
          : ListView(
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
                  _buildInfoRow(Icons.person_outline, 'الاسم', _userData?['name'] ?? 'غير متوفر'),
                  const Divider(),
                  _buildInfoRow(Icons.email_outlined, 'البريد الإلكتروني', _user?.email ?? 'غير متوفر'),
                  const Divider(),
                  _buildInfoRow(Icons.work_outline, 'الوظيفة 1', _userData?['profession1'] ?? 'غير متوفر'),
                  if (_userData?['profession2'] != null && (_userData!['profession2'] as String).isNotEmpty) ...[
                    const Divider(),
                    _buildInfoRow(Icons.work_outline, 'الوظيفة 2', _userData?['profession2']),
                  ],
                  if (_userData?['profession3'] != null && (_userData!['profession3'] as String).isNotEmpty) ...[
                    const Divider(),
                    _buildInfoRow(Icons.work_outline, 'الوظيفة 3', _userData?['profession3']),
                  ],
                  const Divider(),
                  _buildInfoRow(Icons.phone_outlined, 'رقم الهاتف', _userData?['number'] ?? 'غير متوفر'),
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
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade700))),
        ],
      ),
    );
  }
}
