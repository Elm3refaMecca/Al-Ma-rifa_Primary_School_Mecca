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
  String? _selectedStage, _selectedGrade, _selectedTerm, _selectedClass;
  bool _isLoading = true;
  bool _isAdmin = false;
  List<String> _teacherSubjects = [];
  int _currentStep = 0;

  final List<String> stages = ['المرحلة الابتدائية', 'المرحلة المتوسطة', 'المرحلة الثانوية'];
  final List<String> grades = ['الصف الأول', 'الصف الثاني', 'الصف الثالث', 'الصف الرابع', 'الصف الخامس', 'الصف السادس'];
  final List<String> terms = ['الترم الأول', 'الترم الثاني', 'الترم الثالث'];
  final List<String> classes = ['الفصل 1', 'الفصل 2', 'الفصل 3', 'الفصل 4', 'الفصل 5', 'الفصل 6'];
  final List<String> allSubjects = [
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
    if (user != null) {
      try {
        DocumentSnapshot userDataSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _userData = userDataSnapshot.data() as Map<String, dynamic>?;
            if (_userData != null) {
              if (_userData!['role'] == 'admin') {
                _isAdmin = true;
                _teacherSubjects = allSubjects;
              } else {
                _teacherSubjects = [
                  _userData!['profession1'],
                  _userData!['profession2'],
                  _userData!['profession3'],
                ].where((subject) => subject != null && subject.isNotEmpty).toList().cast<String>();
              }
            }
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
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
            onPressed: () async => await FirebaseAuth.instance.signOut(),
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
        content: _buildDropdown(stages, _selectedStage, 'اختر المرحلة', (val) => setState(() {
          _selectedStage = val;
          _selectedGrade = null; _selectedTerm = null; _selectedClass = null;
          if (val != null) _currentStep = 1;
        })),
        isActive: _currentStep >= 0,
        state: _selectedStage != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الصف الدراسي'),
        content: _buildDropdown(grades, _selectedGrade, 'اختر الصف', (val) => setState(() {
          _selectedGrade = val;
          _selectedTerm = null; _selectedClass = null;
          if (val != null) _currentStep = 2;
        })),
        isActive: _currentStep >= 1,
        state: _selectedGrade != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الترم الدراسي'),
        content: _buildDropdown(terms, _selectedTerm, 'اختر الترم', (val) => setState(() {
          _selectedTerm = val;
          _selectedClass = null;
          if (val != null) _currentStep = 3;
        })),
        isActive: _currentStep >= 2,
        state: _selectedTerm != null ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('الفصل'),
        content: _buildDropdown(classes, _selectedClass, 'اختر الفصل', (val) => setState(() {
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HomeworkManagementPage(
                  stage: _selectedStage!,
                  grade: _selectedGrade!,
                  term: _selectedTerm!,
                  className: _selectedClass!,
                  subject: subject,
                ),
              ),
            );
          },
          child: Text(subject, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}