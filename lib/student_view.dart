import 'package:appweb1/student_profile_page.dart';
import 'package:appweb1/teacher_profile_view_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

class StudentViewPage extends StatefulWidget {
  const StudentViewPage({super.key});

  @override
  _StudentViewPageState createState() => _StudentViewPageState();
}

class _StudentViewPageState extends State<StudentViewPage> {
  bool _isLoading = true;
  String? _studentName;

  // بيانات الطالب الثابتة
  String? _fixedStage, _fixedGrade, _fixedTerm, _fixedClass;

  // اختيارات الطالب المتغيرة
  String? _selectedWeek, _selectedDay, _selectedSubject;

  final List<String> subjects = [
    'رياضيات', 'لغتي', 'إسلاميات', 'علوم', 'نشاط', 'انجليزي',
    'اجتماعيات', 'فنية', 'حياتية', 'بدنية', 'رقمية', 'تفكير', 'مصدر'
  ];
  final List<String> weeks = List.generate(16, (index) => 'الأسبوع ${index + 1}');
  final List<String> days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (mounted && querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          _studentName = data['name'];
          // --- تعديل: استخدام أسماء الحقول الصحيحة وتخزينها في متغيرات ثابتة ---
          _fixedStage = data['stages'];
          _fixedGrade = data['grades'];
          _fixedTerm = data['terms'];
          _fixedClass = data['classes'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOutAndGoToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canShowHomework = _fixedStage != null &&
        _fixedGrade != null &&
        _fixedTerm != null &&
        _fixedClass != null &&
        _selectedWeek != null &&
        _selectedDay != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_studentName != null ? 'أهلاً بك، $_studentName' : 'عرض الواجبات', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('بوابة الطالب', style: TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'الملف الشخصي',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentProfilePage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: _signOutAndGoToLogin,
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- تعديل: عرض بيانات الطالب الثابتة ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('بياناتك الدراسية', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800])),
                  const SizedBox(height: 8),
                  _buildInfoTile(Icons.layers, 'المرحلة', _fixedStage),
                  _buildInfoTile(Icons.school, 'الصف', _fixedGrade),
                  _buildInfoTile(Icons.class_, 'الفصل', _fixedClass),
                  _buildInfoTile(Icons.calendar_today, 'الترم', _fixedTerm),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- تعديل: قسم اختيار الأسبوع واليوم ---
          Text('اختر لعرض الواجبات', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800])),
          const SizedBox(height: 16),
          _buildDropdown(weeks, _selectedWeek, '1. اختر الأسبوع', (val) => setState(() => _selectedWeek = val)),
          const SizedBox(height: 12),
          _buildDropdown(days, _selectedDay, '2. اختر اليوم', (val) => setState(() => _selectedDay = val)),
          const SizedBox(height: 12),
          _buildDropdown(subjects, _selectedSubject, 'تصفية حسب المادة (اختياري)', (val) {
            setState(() => _selectedSubject = val);
          }, isOptional: true),

          if (canShowHomework) ...[
            const Divider(height: 40, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'واجبات يوم: ${_selectedDay!}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue[800]),
              ),
            ),
            const SizedBox(height: 10),
            _buildHomeworkList(),
          ]
        ],
      ),
    );
  }

  // --- إضافة: ويدجت لعرض بيانات الطالب ---
  Widget _buildInfoTile(IconData icon, String title, String? subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle ?? 'غير محدد', style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
    );
  }

  Widget _buildDropdown(List<String> items, String? currentValue, String hint, ValueChanged<String?> onChanged, {bool isOptional = false}) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      hint: Text(hint),
      isExpanded: true,
      items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: (isOptional && currentValue != null)
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => setState(() => _selectedSubject = null),
        ) : null,
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(timestamp.toDate());
  }

  Widget _buildHomeworkList() {
    Query query = FirebaseFirestore.instance.collection('homework')
        .where('stage', isEqualTo: _fixedStage)
        .where('grade', isEqualTo: _fixedGrade)
        .where('term', isEqualTo: _fixedTerm)
        .where('class', isEqualTo: _fixedClass)
        .where('week', isEqualTo: _selectedWeek)
        .where('day', isEqualTo: _selectedDay);

    if (_selectedSubject != null) {
      query = query.where('subject', isEqualTo: _selectedSubject);
    }

    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Firestore Stream Error: ${snapshot.error}");
          return const Center(child: Text('حدث خطأ أثناء تحميل البيانات.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('لا توجد واجبات متاحة لهذا التحديد.')));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final String? teacherId = data['teacherId'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: teacherId != null
                    ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherProfileViewPage(teacherId: teacherId),
                    ),
                  );
                } : null,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        label: Text(data['subject'] ?? 'مادة غير محددة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      const SizedBox(height: 12),
                      Text(data['title'] ?? 'بدون عنوان', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(data['description'] ?? 'لا يوجد وصف', style: TextStyle(color: Colors.grey[700])),
                      if (data['fileUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: ActionChip(
                            avatar: const Icon(Icons.download, color: Colors.white),
                            label: Text(data['fileName'] ?? 'تحميل المرفق', style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green,
                            onPressed: () async {
                              final Uri url = Uri.parse(data['fileUrl']);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('المعلم: ${data['teacherName'] ?? 'غير معروف'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                                if (teacherId != null)
                                  Text('(اضغط لعرض الملف الشخصي)', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatTimestamp(data['createdAt']), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}