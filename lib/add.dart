import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appweb1/profile_page.dart';
import 'package:appweb1/homework_management_page.dart';

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  _AddPageState createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  Map<String, dynamic>? _userData;
  String? _selectedStage, _selectedGrade, _selectedClass;

  final List<String> stages = ['المرحلة الابتدائية', 'المرحلة المتوسطة', 'المرحلة الثانوية'];
  final List<String> grades = ['الصف الأول', 'الصف الثاني', 'الصف الثالث', 'الصف الرابع', 'الصف الخامس', 'الصف السادس'];
  final List<String> classes = ['الفصل 1', 'الفصل 2', 'الفصل 3', 'الفصل 4', 'الفصل 5', 'الفصل 6'];
  final List<String> subjects = [
    'رياضيات', 'لغتي', 'إسلاميات', 'علوم', 'نشاط', 'انجليزي',
    'اجتماعيات', 'فنية', 'حياتية', 'بدنية', 'رقمية', 'تفكير', 'مصادر'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if(mounted) {
        setState(() {
          _userData = userData.data() as Map<String, dynamic>?;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_userData?['name'] ?? 'أهلاً بك', style: const TextStyle(fontSize: 18)),
            // ** التعديل: استخدام 'profession1'
            Text(_userData?['profession1'] ?? 'معلم', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'الملف الشخصي',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('1. اختر المرحلة الدراسية'),
          _buildDropdown(stages, _selectedStage, 'المرحلة', (val) => setState(() {
            _selectedStage = val;
            _selectedGrade = null;
            _selectedClass = null;
          })),
          if (_selectedStage != null) ...[
            const SizedBox(height: 20),
            _buildSectionTitle('2. اختر الصف الدراسي'),
            _buildDropdown(grades, _selectedGrade, 'الصف', (val) => setState(() {
              _selectedGrade = val;
              _selectedClass = null;
            })),
          ],
          if (_selectedGrade != null) ...[
            const SizedBox(height: 20),
            _buildSectionTitle('3. اختر الفصل'),
            _buildDropdown(classes, _selectedClass, 'الفصل', (val) => setState(() {
              _selectedClass = val;
            })),
          ],
          if (_selectedClass != null) ...[
            const SizedBox(height: 20),
            _buildSectionTitle('4. اختر المادة لإدارة واجباتها'),
            _buildSubjectGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  Widget _buildDropdown(List<String> items, String? currentValue, String hint, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: currentValue,
          hint: Text('اختر $hint'),
          items: items.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSubjectGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HomeworkManagementPage(
                  stage: _selectedStage!,
                  grade: _selectedGrade!,
                  className: _selectedClass!,
                  subject: subject,
                ),
              ),
            );
          },
          child: Text(subject, textAlign: TextAlign.center),
        );
      },
    );
  }
}
