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
  bool _isLoading = true;
  bool _isAdmin = false;
  int _currentStep = 0;

  // --- متغيرات جديدة لإدارة الصلاحيات الديناميكية ---
  List<String> _teacherSubjects = [];
  String? _teacherTerm;

  List<String> _availableStages = [];
  Map<String, List<String>> _gradesByStage = {};
  Map<String, List<String>> _classesByGrade = {};

  List<String> _gradesForSelectedStage = [];
  List<String> _classesForSelectedGrade = [];

  // قوائم شاملة لصلاحيات المدير
  final List<String> _allStages = ['المرحلة الابتدائية', 'المرحلة المتوسطة', 'المرحلة الثانوية'];
  final List<String> _allGrades = ['الصف الأول', 'الصف الثاني', 'الصف الثالث', 'الصف الرابع', 'الصف الخامس', 'الصف السادس'];
  final List<String> _allClasses = ['الفصل 1', 'الفصل 2', 'الفصل 3', 'الفصل 4', 'الفصل 5', 'الفصل 6'];
  final List<String> _allTerms = ['الترم الأول', 'الترم الثاني', 'الترم الثالث'];
  final List<String> _allSubjects = [
    'رياضيات', 'لغتي', 'إسلاميات', 'علوم', 'نشاط', 'انجليزي',
    'اجتماعيات', 'فنية', 'حياتية', 'بدنية', 'رقمية', 'تفكير', 'مصدر'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      DocumentSnapshot userDataSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;

      final data = userDataSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        setState(() => _isLoading = false);
        return;
      }

      _userData = data;
      // التحقق من دور المدير
      if (data['profession'] == 'admin') {
        _isAdmin = true;
        _teacherSubjects = _allSubjects;
        _availableStages = _allStages;
        _teacherTerm = data['terms'] ?? _allTerms.first;
      } else {
        // إذا لم يكن مدير، قم بتحليل صلاحياته
        _parseTeacherPermissions(data);
      }

      setState(() => _isLoading = false);

    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- دالة لتحليل صلاحيات المعلم ---
  void _parseTeacherPermissions(Map<String, dynamic> data) {
    // 1. تحليل المواد
    _teacherSubjects = [
      data['profession1'], data['profession2'], data['profession3'],
      data['profession4'], data['profession5'], data['profession6'],
      data['profession7'], data['profession8'], data['profession9'],
      data['profession10'], data['profession11'], data['profession12'],
      data['profession13'],
    ].where((s) => s != null && s.isNotEmpty).cast<String>().toList();

    // 2. تحليل الترم
    _teacherTerm = data['terms'];

    // 3. تحليل المراحل والصفوف والفصول
    final stages = <String>{};
    final grades = <String, Set<String>>{};
    final classes = <String, Set<String>>{};

    // تعريف بنية البيانات
    final structure = {
      'المرحلة الابتدائية': {
        'field': 'stage1',
        'grades': {
          'الصف الأول': {'field': 'grade1', 'classField': 'class1'},
          'الصف الثاني': {'field': 'grade2', 'classField': 'class2'},
          'الصف الثالث': {'field': 'grade3', 'classField': 'class3'},
          'الصف الرابع': {'field': 'grade4', 'classField': 'class4'},
          'الصف الخامس': {'field': 'grade5', 'classField': 'class5'},
          'الصف السادس': {'field': 'grade6', 'classField': 'class6'},
        }
      },
      'المرحلة المتوسطة': {
        'field': 'stage2',
        'grades': {
          'الصف الأول المتوسط': {'field': 'grade11', 'classField': 'class11'},
          'الصف الثاني المتوسط': {'field': 'grade22', 'classField': 'class22'},
          'الصف الثالث المتوسط': {'field': 'grade33', 'classField': 'class33'},
        }
      },
      'المرحلة الثانوية': {
        'field': 'stage3',
        'grades': {
          'الصف الأول الثانوي': {'field': 'grade111', 'classField': 'class111'},
          'الصف الثاني الثانوي': {'field': 'grade222', 'classField': 'class222'},
          'الصف الثالث الثانوي': {'field': 'grade333', 'classField': 'class333'},
        }
      },
    };

    // تحليل الصلاحيات
    structure.forEach((stageName, stageInfo) {
      final stageData = stageInfo as Map<String, dynamic>;
      if (data[stageData['field']] != null && data[stageData['field']] != '0') {
        stages.add(stageName);
        grades.putIfAbsent(stageName, () => <String>{});

        // --- تعديل: إضافة تحقق من وجود القيمة قبل استدعاء forEach ---
        final gradesMap = stageData['grades'] as Map<String, dynamic>?;
        if (gradesMap != null) {
          gradesMap.forEach((gradeName, gradeInfo) {
            final gradeData = gradeInfo as Map<String, dynamic>;
            if (data[gradeData['field']] != null && data[gradeData['field']] != '0') {
              grades[stageName]!.add(gradeName);

              final classValue = data[gradeData['classField']];
              if (classValue is String && classValue.isNotEmpty && classValue != '0') {
                classes.putIfAbsent(gradeName, () => <String>{});
                classes[gradeName]!.addAll(classValue.split(',').map((e) => e.trim()));
              }
            }
          });
        }
      }
    });

    // تحديث الحالة
    _availableStages = stages.toList();
    _gradesByStage = grades.map((key, value) => MapEntry(key, value.toList()));
    _classesByGrade = classes.map((key, value) => MapEntry(key, value.toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_userData?['name'] ?? 'أهلاً بك', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_isAdmin ? 'Admin Access' : (_userData?['profession1'] ?? 'معلم'), style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'الملف الشخصي',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset('assets/e2.png', height: 80),
          ),
          Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 3) setState(() => _currentStep += 1);
            },
            onStepCancel: () {
              if (_currentStep > 0) setState(() => _currentStep -= 1);
            },
            onStepTapped: (step) => setState(() => _currentStep = step),
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: _buildSteps(),
          ),
          if (_selectedClass != null) ...[
            const Divider(thickness: 1, height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSectionTitle('5. اختر المادة لإدارة واجباتها'),
            ),
            _teacherSubjects.isEmpty
                ? const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('لم يتم تحديد مواد لك في ملفك الشخصي.'),
            ))
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSubjectGrid(),
            ),
          ],
        ],
      ),
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('المرحلة الدراسية'),
        content: _buildDropdown(_availableStages, _selectedStage, 'اختر المرحلة', (val) => setState(() {
          _selectedStage = val;
          _selectedGrade = null; _selectedClass = null;
          if (val != null) {
            _gradesForSelectedStage = _isAdmin ? _allGrades : (_gradesByStage[val] ?? []);
            _currentStep = 1;
          } else {
            _gradesForSelectedStage = [];
          }
          _classesForSelectedGrade = [];
        })),
        isActive: _currentStep >= 0,
        state: _selectedStage != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الصف الدراسي'),
        content: _buildDropdown(_gradesForSelectedStage, _selectedGrade, 'اختر الصف', (val) => setState(() {
          _selectedGrade = val;
          _selectedClass = null;
          if (val != null) {
            _classesForSelectedGrade = _isAdmin ? _allClasses : (_classesByGrade[val] ?? []);
            _currentStep = 2;
          } else {
            _classesForSelectedGrade = [];
          }
        })),
        isActive: _currentStep >= 1,
        state: _selectedGrade != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الترم الدراسي'),
        content: AbsorbPointer( // لجعل القائمة غير قابلة للتعديل
          child: _buildDropdown(
              _isAdmin ? _allTerms : (_teacherTerm != null ? [_teacherTerm!] : []),
              _isAdmin ? (_teacherTerm ?? _allTerms.first) : _teacherTerm,
              'الترم الدراسي',
                  (val) { /* لا تفعل شيئا */ }
          ),
        ),
        isActive: _currentStep >= 2,
        state: _teacherTerm != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الفصل'),
        content: _buildDropdown(_classesForSelectedGrade, _selectedClass, 'اختر الفصل', (val) => setState(() {
          _selectedClass = val;
        })),
        isActive: _currentStep >= 3,
        state: _selectedClass != null ? StepState.complete : StepState.indexed,
      ),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]));
  }

  Widget _buildDropdown(List<String> items, String? currentValue, String hint, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      hint: Text(hint),
      isExpanded: true,
      items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSubjectGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: _teacherSubjects.length,
      itemBuilder: (context, index) {
        final subject = _teacherSubjects[index];
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 1,
          ),
          onPressed: () {
            if (_selectedStage != null && _selectedGrade != null && _teacherTerm != null && _selectedClass != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HomeworkManagementPage(
                    stage: _selectedStage!,
                    grade: _selectedGrade!,
                    term: _teacherTerm!,
                    className: _selectedClass!,
                    subject: subject,
                  ),
                ),
              );
            }
          },
          child: Text(subject, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}