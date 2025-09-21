// student_view.dart

import 'package:appweb1/teacher_profile_view_page.dart';
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
  String? _selectedStage, _selectedGrade, _selectedClass, _selectedSubject, _selectedWeek;

  final List<String> stages = ['المرحلة الابتدائية', 'المرحلة المتوسطة', 'المرحلة الثانوية'];
  final List<String> grades = ['الصف الأول', 'الصف الثاني', 'الصف الثالث', 'الصف الرابع', 'الصف الخامس', 'الصف السادس'];
  final List<String> classes = ['الفصل 1', 'الفصل 2', 'الفصل 3', 'الفصل 4', 'الفصل 5', 'الفصل 6'];
  final List<String> subjects = [
    'رياضيات', 'لغتي', 'إسلاميات', 'علوم', 'نشاط', 'انجليزي',
    'اجتماعيات', 'فنية', 'حياتية', 'بدنية', 'رقمية', 'تفكير', 'مصدر'
  ];
  final List<String> weeks = List.generate(16, (index) => 'الأسبوع ${index + 1}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عرض الواجبات المدرسية')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDropdown(stages, _selectedStage, 'المرحلة', (val) => setState(() {
            _selectedStage = val; _selectedGrade = null; _selectedClass = null; _selectedSubject = null; _selectedWeek = null;
          })),
          const SizedBox(height: 10),
          if (_selectedStage != null)
            _buildDropdown(grades, _selectedGrade, 'الصف', (val) => setState(() {
              _selectedGrade = val; _selectedClass = null; _selectedSubject = null; _selectedWeek = null;
            })),
          const SizedBox(height: 10),
          if (_selectedGrade != null)
            _buildDropdown(classes, _selectedClass, 'الفصل', (val) => setState(() {
              _selectedClass = val; _selectedSubject = null; _selectedWeek = null;
            })),
          const SizedBox(height: 10),
          if (_selectedClass != null)
            _buildDropdown(subjects, _selectedSubject, 'المادة', (val) => setState(() {
              _selectedSubject = val; _selectedWeek = null;
            })),
          const SizedBox(height: 10),
          if (_selectedSubject != null)
            _buildDropdown(weeks, _selectedWeek, 'الأسبوع', (val) => setState(() {
              _selectedWeek = val;
            })),

          if (_selectedWeek != null) ...[
            const Divider(height: 40, thickness: 1),
            Text('واجبات ${_selectedWeek!}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            _buildHomeworkList(),
          ]
        ],
      ),
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
          items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(timestamp.toDate());
  }

  Widget _buildHomeworkList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('homework')
          .where('stage', isEqualTo: _selectedStage)
          .where('grade', isEqualTo: _selectedGrade)
          .where('class', isEqualTo: _selectedClass)
          .where('subject', isEqualTo: _selectedSubject)
          .where('week', isEqualTo: _selectedWeek)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ. تأكد من إنشاء الفهرس في Firestore.\n${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('لا توجد واجبات متاحة حالياً لهذا الأسبوع.')));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final String? teacherId = data['teacherId'];

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: teacherId != null
                    ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherProfileViewPage(teacherId: teacherId),
                    ),
                  );
                }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? 'بدون عنوان', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(data['description'] ?? 'لا يوجد وصف'),
                      if (data['fileUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: ActionChip(
                            avatar: const Icon(Icons.download_for_offline, color: Colors.white),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المعلم: ${data['teacherName'] ?? 'غير معروف'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '(اضغط لعرض الملف الشخصي)',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'نُشر في: ${_formatTimestamp(data['createdAt'])}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            textDirection: TextDirection.ltr,
                          ),
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
