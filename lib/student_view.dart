import 'package:appweb1/main.dart';
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
  String? _selectedStage, _selectedGrade, _selectedTerm, _selectedClass, _selectedWeek, _selectedDay, _selectedSubject;
  int _currentStep = 0;

  final List<String> stages = ['المرحلة الابتدائية', 'المرحلة المتوسطة', 'المرحلة الثانوية'];
  final List<String> grades = ['الصف الأول', 'الصف الثاني', 'الصف الثالث', 'الصف الرابع', 'الصف الخامس', 'الصف السادس'];
  final List<String> terms = ['الترم الأول', 'الترم الثاني', 'الترم الثالث'];
  final List<String> classes = ['الفصل 1', 'الفصل 2', 'الفصل 3', 'الفصل 4', 'الفصل 5', 'الفصل 6'];
  final List<String> subjects = [
    'رياضيات', 'لغتي', 'إسلاميات', 'علوم', 'نشاط', 'انجليزي',
    'اجتماعيات', 'فنية', 'حياتية', 'بدنية', 'رقمية', 'تفكير', 'مصدر'
  ];
  final List<String> weeks = List.generate(16, (index) => 'الأسبوع ${index + 1}');
  final List<String> days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  Future<void> _signOutAndGoToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const TeacherLoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- إضافة: شرط التحقق من إتمام كل الاختيارات ---
    final bool allSelectionsMade = _selectedStage != null &&
        _selectedGrade != null &&
        _selectedTerm != null &&
        _selectedClass != null &&
        _selectedWeek != null &&
        _selectedDay != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عرض الواجبات المدرسية'),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'العودة لتسجيل الدخول',
          onPressed: _signOutAndGoToLogin,
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset('assets/e2.png', height: 60),
          ),
          Stepper(
            physics: const ClampingScrollPhysics(),
            currentStep: _currentStep,
            // --- تعديل: منع التنقل بالضغط على الخطوات لفرض التسلسل ---
            onStepTapped: null,
            onStepContinue: () {
              // --- تعديل: الانتقال للخطوة التالية فقط إذا لم تكن الأخيرة ---
              if (_currentStep < _buildSteps().length - 1) {
                setState(() {
                  _currentStep += 1;
                });
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep -= 1;
                });
              }
            },
            // --- تعديل: بناء أزرار التحكم بشكل مخصص ---
            controlsBuilder: (context, details) {
              bool canContinue = false;
              switch (details.currentStep) {
                case 0: canContinue = _selectedStage != null; break;
                case 1: canContinue = _selectedGrade != null; break;
                case 2: canContinue = _selectedTerm != null; break;
                case 3: canContinue = _selectedClass != null; break;
                case 4: canContinue = _selectedWeek != null; break;
                case 5: canContinue = _selectedDay != null; break;
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    if (details.currentStep < _buildSteps().length - 1)
                      ElevatedButton(
                        onPressed: canContinue ? details.onStepContinue : null,
                        child: const Text('متابعة'),
                      ),
                    if (details.currentStep != 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('رجوع'),
                      ),
                  ],
                ),
              );
            },
            steps: _buildSteps(),
          ),
          // --- تعديل: عرض الواجبات فقط عند إكمال جميع الاختيارات ---
          if (allSelectionsMade) ...[
            const Divider(height: 40, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('المرحلة'),
        content: _buildDropdown(stages, _selectedStage, 'اختر المرحلة', (val) => setState(() {
          _selectedStage = val;
          _selectedGrade = null; _selectedTerm = null; _selectedClass = null;
          _selectedWeek = null; _selectedDay = null; _selectedSubject = null;
        })),
        isActive: _currentStep >= 0,
        state: _selectedStage != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الصف'),
        content: _buildDropdown(grades, _selectedGrade, 'اختر الصف', (val) => setState(() {
          _selectedGrade = val;
          _selectedTerm = null; _selectedClass = null; _selectedWeek = null;
          _selectedDay = null; _selectedSubject = null;
        })),
        isActive: _currentStep >= 1,
        state: _selectedGrade != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الترم'),
        content: _buildDropdown(terms, _selectedTerm, 'اختر الترم', (val) => setState(() {
          _selectedTerm = val;
          _selectedClass = null; _selectedWeek = null; _selectedDay = null; _selectedSubject = null;
        })),
        isActive: _currentStep >= 2,
        state: _selectedTerm != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الفصل'),
        content: _buildDropdown(classes, _selectedClass, 'اختر الفصل', (val) => setState(() {
          _selectedClass = val;
          _selectedWeek = null; _selectedDay = null; _selectedSubject = null;
        })),
        isActive: _currentStep >= 3,
        state: _selectedClass != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الأسبوع'),
        content: _buildDropdown(weeks, _selectedWeek, 'اختر الأسبوع', (val) => setState(() {
          _selectedWeek = val;
          _selectedDay = null; _selectedSubject = null;
        })),
        isActive: _currentStep >= 4,
        state: _selectedWeek != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('اليوم والمادة'),
        content: Column(
          children: [
            _buildDropdown(days, _selectedDay, 'اختر اليوم', (val) => setState(() {
              _selectedDay = val;
            })),
            const SizedBox(height: 12),
            _buildDropdown(subjects, _selectedSubject, 'تصفية حسب المادة (اختياري)', (val) {
              setState(() => _selectedSubject = val);
            }, isOptional: true),
          ],
        ),
        isActive: _currentStep >= 5,
        state: _selectedDay != null ? StepState.complete : StepState.indexed,
      ),
    ];
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
        .where('stage', isEqualTo: _selectedStage)
        .where('grade', isEqualTo: _selectedGrade)
        .where('term', isEqualTo: _selectedTerm)
        .where('class', isEqualTo: _selectedClass)
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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