import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUploading = false;

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
        if (mounted) setState(() { _isLoading = false; });
      }
    } else {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(pickedFile.path);
      // --- تعديل: تغيير مسار الرفع إلى photosT ---
      final ref = FirebaseStorage.instance.ref('photosT/${_user!.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({'photo': url});

      if(mounted) {
        setState(() {
          _userData?['photo'] = url;
        });
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفع الصورة: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) setState(() => _isUploading = false);
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: _userData?['photo'] != null
                            ? NetworkImage(_userData!['photo'])
                            : null,
                        child: _userData?['photo'] == null
                            ? Icon(Icons.person_pin, size: 70, color: Colors.blue.shade800)
                            : null,
                      ),
                      if (_isUploading)
                        const CircularProgressIndicator()
                      else
                        Material(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: _pickAndUploadImage,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(Icons.edit, color: Colors.white, size: 20),
                            ),
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(_userData?['name'] ?? 'اسم غير متوفر', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(_user?.email ?? 'بريد إلكتروني غير متوفر', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 24),
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
                  // --- تعديل: استخدام حقل 'phone' بدلاً من 'number' ---
                  _buildInfoRow(Icons.phone_outlined, 'رقم الهاتف', _userData?['phone'] ?? 'غير متوفر'),
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