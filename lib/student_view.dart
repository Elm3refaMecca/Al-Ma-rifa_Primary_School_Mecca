import 'dart:math';
import 'dart:typed_data';

import 'package:almarefamecca/student_profile_page.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:percent_indicator/percent_indicator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
// --- (إضافة جديدة) المكتبات المطلوبة ---
import 'package:url_launcher/url_launcher.dart';

enum StudentView { dashboard, results, noble, behaviorNotes }

enum ReportType { graphical, table, studentData }

class TestInfo {
  final String key;
  final String name;
  final String subject;

  TestInfo({required this.key, required this.name, required this.subject});
}

class Subject {
  final String name;
  final IconData icon;
  Subject({required this.name, required this.icon});
}

class _AnalysisResult {
  final String subjectName;
  final double average;
  final double percentage;
  final double maxPossibleGrade;
  final num highestGrade;
  final num lowestGrade;
  final String assessment;
  final String consistency;
  final bool isBelowPassing;
  final List<MapEntry<String, num>> testResults;
  final List<FlSpot> trendSpots;
  final String performanceTrend;
  final double? predictedNextGrade;
  final String riskAssessment;

  _AnalysisResult({
    required this.subjectName,
    required this.average,
    required this.percentage,
    required this.maxPossibleGrade,
    required this.highestGrade,
    required this.lowestGrade,
    required this.assessment,
    required this.consistency,
    required this.isBelowPassing,
    required this.testResults,
    required this.trendSpots,
    required this.performanceTrend,
    this.predictedNextGrade,
    required this.riskAssessment,
  });
}

class StudentViewPage extends StatefulWidget {
  // >>> [MODIFIED] Added optional studentId
  final String? studentId;

  const StudentViewPage({super.key, this.studentId});

  @override
  _StudentViewPageState createState() => _StudentViewPageState();
}

class _StudentViewPageState extends State<StudentViewPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _studentData;
  StudentView _currentView = StudentView.dashboard;
  late TabController _tabController;
  final Map<String, Color> _subjectColors = {};

  String? _studentDocId;

  late final Map<String, TestInfo> _allTestsMap;

  // --- controller for screenshot ---
  final ScreenshotController _screenshotController = ScreenshotController();


  final List<Subject> subjects = [
    Subject(name: 'رياضيات', icon: Icons.calculate),
    Subject(name: 'لغتي', icon: Icons.translate),
    Subject(name: 'إسلاميات', icon: Icons.mosque),
    Subject(name: 'علوم', icon: Icons.science),
    Subject(name: 'انجليزي', icon: Icons.book),
    Subject(name: 'اجتماعيات', icon: Icons.public),
    Subject(name: 'فنية', icon: Icons.palette),
    Subject(name: 'بدنية', icon: Icons.fitness_center),
    Subject(name: 'رقمية', icon: Icons.computer),
    Subject(name: 'تفكير', icon: Icons.psychology),
    Subject(name: 'نشاط', icon: Icons.star),
    Subject(name: 'حياتية', icon: Icons.eco),
    Subject(name: 'مصدر', icon: Icons.source),
    Subject(name: 'نافس', icon: Icons.emoji_events),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  void _initializeData() {
    _allTestsMap = {for (var test in _getAllPossibleTests()) test.key: test};
    _fetchStudentData();
    _assignSubjectColors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TestInfo> _getAllPossibleTests() {
    final List<TestInfo> tests = [];
    final Map<String, String> subjects = {
      'profession1': 'رياضيات',
      'profession2': 'لغتي',
      'profession3': 'إسلاميات',
      'profession4': 'علوم',
      'profession5': 'نشاط',
      'profession6': 'انجليزي',
      'profession7': 'اجتماعيات',
      'profession8': 'فنية',
      'profession9': 'حياتية',
      'profession10': 'بدنية',
      'profession11': 'رقمية',
      'profession12': 'تفكير',
    };

    subjects.forEach((profKey, subjName) {
      tests.add(TestInfo(key: 'e1$profKey', name: 'الاختبار الأول (دوري)', subject: subjName));
      tests.add(TestInfo(key: 'e2$profKey', name: 'الاختبار الثاني (دوري)', subject: subjName));
      tests.add(TestInfo(key: 'e3$profKey', name: 'الاختبار الثالث (دوري)', subject: subjName));
      // -- إضافة الاختبارات الجديدة --
      tests.add(TestInfo(key: 'e14$profKey', name: 'اختبار قبلي', subject: subjName));
      tests.add(TestInfo(key: 'e15$profKey', name: 'اختبار بعدي', subject: subjName));
      tests.add(TestInfo(key: 'e16$profKey', name: 'اختبار احتياطي', subject: subjName));
    });

    const nafesSubject = 'نافس';
    const nafesKey = 'profession13';
    tests.addAll([
      TestInfo(key: 'e1$nafesKey', name: 'الأول أساسي', subject: nafesSubject),
      TestInfo(key: 'e2$nafesKey', name: 'الثاني أساسي', subject: nafesSubject),
      TestInfo(key: 'e3$nafesKey', name: 'الاول ف نافس', subject: nafesSubject),
      TestInfo(key: 'e4$nafesKey', name: 'الثاني ف نافس', subject: nafesSubject),
      TestInfo(key: 'e5$nafesKey', name: 'الثالث ف نافс', subject: nafesSubject),
      TestInfo(key: 'e6$nafesKey', name: 'الرابع ف نافس', subject: nafesSubject),
      TestInfo(key: 'e7$nafesKey', name: 'الخامس ف نافس', subject: nafesSubject),
      TestInfo(key: 'e8$nafesKey', name: 'السادس ف نافس', subject: nafesSubject),
      TestInfo(key: 'e9$nafesKey', name: 'السابع ف نافس', subject: nafesSubject),
      TestInfo(key: 'e10$nafesKey', name: 'الثامن ف نافس', subject: nafesSubject),
      TestInfo(key: 'e11$nafesKey', name: 'التاسع ف نافس', subject: nafesSubject),
      TestInfo(key: 'e12$nafesKey', name: 'العاشر ف نافس', subject: nafesSubject),
    ]);

    return tests;
  }

  void _assignSubjectColors() {
    final List<MaterialColor> vibrantColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lightGreen,
      Colors.brown,
      Colors.blueGrey
    ];

    for (int i = 0; i < subjects.length; i++) {
      _subjectColors[subjects[i].name] =
      vibrantColors[i % vibrantColors.length];
    }
  }

  // --- (إضافة جديدة) دالة الاتصال بواتساب ---
  Future<void> _launchWhatsApp() async {
    const phoneNumber = '966569064173'; // رقم الهاتف بدون + أو 00
    final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber');

    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق واتساب.')),
        );
      }
    }
  }

  Future<void> _fetchStudentData() async {
    final studentDocumentId = widget.studentId ?? FirebaseAuth.instance.currentUser?.uid;

    if (studentDocumentId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentDocumentId)
          .get();

      if (mounted && docSnapshot.exists) {
        setState(() {
          _studentData = docSnapshot.data();
          _studentDocId = docSnapshot.id;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      // --- [MODIFIED] Wrapped body in a Stack to add WhatsApp button ---
      body: Stack(
        children: [
          _buildBody(),
          Positioned(
            bottom: 16,
            left: 16,
            child: GestureDetector(
              onTap: _launchWhatsApp,
              child: Tooltip(
                message: 'تواصل معنا عبر واتساب',
                child: SizedBox(
                  width: 120,
                  height: 120,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final bool isTeacherView = widget.studentId != null;
    bool isDashboard = _currentView == StudentView.dashboard;
    String title;

    switch (_currentView) {
      case StudentView.results:
        title = 'النتائج والتحليل الدراسي';
        break;
      case StudentView.noble:
        title = 'قاعة الشرف للطلاب المنضبطين';
        break;
      case StudentView.behaviorNotes:
        title = 'ملاحظات سلوكية: ${_studentData?['name'] ?? ''}';
        break;
      default:
        title = isTeacherView ? 'تقرير الطالب: ${_studentData?['name'] ?? ''}' : 'أهلاً بك، ${_studentData?['name'] ?? ''}';
    }

    // --- [MODIFIED] Build actions list ---
    List<Widget> appBarActions = [];
    if (isDashboard && !isTeacherView) {
      appBarActions.addAll(_buildDashboardActions());
    } else if (_currentView == StudentView.results) {
      appBarActions.add(
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'تحميل التقارير (PDF)',
          onPressed: _showReportOptions,
        ),
      );
    }

    // --- [ADDED] Add school logo to all AppBars ---
    appBarActions.add(
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset('assets/2.png'),
      ),
    );

    return AppBar(
      title: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
      centerTitle: !isDashboard || isTeacherView,
      leading: (isTeacherView && isDashboard) || !isDashboard
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () {
          if (!isDashboard) {
            setState(() => _currentView = StudentView.dashboard);
          } else {
            Navigator.of(context).pop();
          }
        },
      )
          : null,
      actions: appBarActions, // Use the new actions list
      automaticallyImplyLeading: !isDashboard || isTeacherView,
    );
  }

  Widget _buildBody() {
    final bool isTeacherView = widget.studentId != null;

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_studentData == null) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('عفواً، لم يتم العثور على بيانات الطالب.'),
              const SizedBox(height: 20),
              if (!isTeacherView)
                ElevatedButton(
                  onPressed: _signOutAndGoToLogin,
                  child: const Text('العودة لتسجيل الدخول'),
                )
            ],
          ));
    }

    switch (_currentView) {
      case StudentView.results:
        return _buildResultsView();
      case StudentView.noble:
        return _buildNobleStudentView();
      case StudentView.behaviorNotes:
        return _buildBehaviorNotesView();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final int totalLikes = _studentData?['totalLikes'] ?? 0;
    final int totalDislikes = _studentData?['totalDislikes'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
        children: [
          _buildDashboardButton(
            title: 'النتائج والتحليل',
            icon: Icons.bar_chart_rounded,
            color: Colors.green.shade700,
            onTap: () => setState(() => _currentView = StudentView.results),
          ),
          _buildDashboardButton(
            title: 'الطالب المنضبط',
            icon: Icons.thumb_up,
            color: Colors.blue.shade700,
            count: totalLikes,
            onTap: () => setState(() => _currentView = StudentView.noble),
          ),
          _buildDashboardButton(
            title: 'الملاحظات السلوكية',
            icon: Icons.priority_high,
            color: Colors.red.shade600,
            count: totalDislikes,
            onTap: () =>
                setState(() => _currentView = StudentView.behaviorNotes),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int count = 0,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, size: 36, color: color),
                ),
                if (count > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_AnalysisResult> _getAllAnalyses() {
    final Map<String, Map<String, num>> subjectGrades = {};
    _studentData?.forEach((key, value) {
      if (value is num && _allTestsMap.containsKey(key)) {
        final testInfo = _allTestsMap[key]!;
        subjectGrades
            .putIfAbsent(testInfo.subject, () => {})[testInfo.name.trim()] = value;
      }
    });

    final sortedSubjects = subjectGrades.keys.toList()..sort();
    return sortedSubjects
        .map((subjectName) =>
        _analyzeSubjectGrades(subjectName, subjectGrades[subjectName]!))
        .toList();
  }

  Widget _buildResultsView() {
    final allAnalyses = _getAllAnalyses();

    if (allAnalyses.isEmpty) {
      return const Center(
        child: Text('لا توجد نتائج دراسية لعرضها حالياً.',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    return Screenshot(
      controller: _screenshotController,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ...allAnalyses.map((analysis) {
                final subjectIcon = subjects
                    .firstWhere((s) => s.name == analysis.subjectName,
                    orElse: () => Subject(name: '', icon: Icons.book))
                    .icon;
                return _SubjectResultCard(
                  analysis: analysis,
                  subjectIcon: subjectIcon,
                  color: _subjectColors[analysis.subjectName] ?? Colors.blue,
                );
              }).toList(),
              _buildOverallAnalysisWidget(allAnalyses),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallAnalysisWidget(List<_AnalysisResult> allAnalyses) {
    if (allAnalyses.isEmpty) return const SizedBox.shrink();

    final double overallAveragePercentage =
        allAnalyses.map((a) => a.percentage).reduce((a, b) => a + b) /
            allAnalyses.length;

    allAnalyses.sort((a, b) => b.average.compareTo(a.average));
    final strengths = allAnalyses.take(3).toList();
    final weaknesses = allAnalyses.reversed.take(3).toList();

    String overallAssessment;
    if (overallAveragePercentage >= 0.9) {
      overallAssessment =
      'أداء استثنائي وممتاز في جميع المواد. استمر في هذا التفوق!';
    } else if (overallAveragePercentage >= 0.75) {
      overallAssessment =
      'أداء عام جيد جداً، مع وجود نقاط قوة واضحة. عمل رائع!';
    } else if (overallAveragePercentage >= 0.60) {
      overallAssessment =
      'أداء عام جيد ومستقر. يمكن تحقيق المزيد من التقدم بالتركيز على بعض المواد.';
    } else {
      overallAssessment =
      'الأداء العام يحتاج إلى متابعة وجهد إضافي لتحقيق نتائج أفضل.';
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المحصلة النهائية والتقييم الشامل',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            Center(
              child: CircularPercentIndicator(
                radius: 60.0,
                lineWidth: 12.0,
                animation: true,
                percent: overallAveragePercentage,
                center: Text(
                  "${(overallAveragePercentage * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 22.0),
                ),
                footer: const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("متوسط الأداء العام",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15.0)),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'التقييم الشامل:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              overallAssessment,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Divider(height: 24),
            Text(
              'أبرز نقاط القوة (أعلى المواد أداءً):',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...strengths.map((s) => ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green[700]),
              title: Text(s.subjectName),
              trailing: Text(
                  '${(s.percentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
            const Divider(height: 24),
            Text(
              'مواد تحتاج إلى تركيز إضافي:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...weaknesses.map((w) => ListTile(
              leading:
              Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
              title: Text(w.subjectName),
              trailing: Text(
                  '${(w.percentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        ),
      ),
    );
  }

  _AnalysisResult _analyzeSubjectGrades(
      String subjectName, Map<String, num> testResults) {
    final sortedTests = testResults.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final grades = sortedTests.map((e) => e.value).toList();

    if (grades.isEmpty) {
      return _AnalysisResult(
        subjectName: subjectName,
        average: 0,
        percentage: 0,
        maxPossibleGrade: 0,
        highestGrade: 0,
        lowestGrade: 0,
        assessment: 'N/A',
        consistency: 'N/A',
        isBelowPassing: false,
        testResults: [],
        trendSpots: [],
        performanceTrend: 'لا يوجد بيانات',
        predictedNextGrade: null,
        riskAssessment: 'غير محدد',
      );
    }

    final bool isNafes = subjectName == 'نافس';
    final double maxGrade = isNafes ? 10.0 : 20.0;
    final double passingGrade = maxGrade / 2.0;

    final double average = grades.reduce((a, b) => a + b) / grades.length;
    final double percentage = (average / maxGrade).clamp(0.0, 1.0);
    final num highest = grades.reduce(max);
    final num lowest = grades.reduce(min);
    final bool isBelowPassing = average < passingGrade;

    final double variance =
        grades.map((g) => pow(g - average, 2)).reduce((a, b) => a + b) /
            grades.length;
    final double stdDev = sqrt(variance);
    String consistency;
    if (stdDev > (maxGrade * 0.15)) {
      consistency = 'غير مستقر';
    } else if (stdDev < (maxGrade * 0.05)) {
      consistency = 'مستقر جداً';
    } else {
      consistency = 'مستقر';
    }

    String assessment;
    if (percentage >= 0.9)
      assessment = 'ممتاز';
    else if (percentage >= 0.8)
      assessment = 'جيد جداً';
    else if (percentage >= 0.7)
      assessment = 'جيد';
    else if (percentage >= 0.5)
      assessment = 'مقبول';
    else
      assessment = 'يحتاج لمتابعة';

    final trendSpots = <FlSpot>[];
    for (int i = 0; i < sortedTests.length; i++) {
      trendSpots.add(FlSpot(i.toDouble(), sortedTests[i].value.toDouble()));
    }

    String performanceTrend = 'مستقر';
    double? predictedNextGrade;
    String riskAssessment = 'مسار آمن';

    if (grades.length >= 2) {
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (int i = 0; i < grades.length; i++) {
        sumX += i;
        sumY += grades[i];
        sumXY += i * grades[i];
        sumX2 += i * i;
      }
      final n = grades.length.toDouble();

      final double slope =
          (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

      if (slope > (maxGrade * 0.05)) {
        performanceTrend = 'تحسن ملحوظ';
      } else if (slope < -(maxGrade * 0.05)) {
        performanceTrend = 'تراجع ملحوظ';
      }

      final double intercept = (sumY - slope * sumX) / n;
      predictedNextGrade = (slope * n + intercept).clamp(0.0, maxGrade);

      if (isBelowPassing &&
          (performanceTrend.contains('تراجع') ||
              performanceTrend == 'مستقر')) {
        riskAssessment = 'مسار حرج';
      } else if (isBelowPassing ||
          (predictedNextGrade != null && predictedNextGrade < passingGrade)) {
        riskAssessment = 'يحتاج لمتابعة';
      }
    } else {
      performanceTrend = 'يتطلب اختبارين للتحليل';
    }

    return _AnalysisResult(
      subjectName: subjectName,
      average: average,
      percentage: percentage,
      maxPossibleGrade: maxGrade,
      highestGrade: highest,
      lowestGrade: lowest,
      assessment: assessment,
      consistency: consistency,
      isBelowPassing: isBelowPassing,
      testResults: sortedTests,
      trendSpots: trendSpots,
      performanceTrend: performanceTrend,
      predictedNextGrade: predictedNextGrade,
      riskAssessment: riskAssessment,
    );
  }

  void _showReportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('تقرير التحليل البياني'),
              subtitle: const Text('عرض شامل مع رسوم بيانية وتوقعات'),
              onTap: () {
                Navigator.pop(context);
                _generateAndSharePdf(ReportType.graphical);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('تقرير جدولي للدرجات'),
              subtitle: const Text('عرض الدرجات في جدول منظم مع التقييم'),
              onTap: () {
                Navigator.pop(context);
                _generateAndSharePdf(ReportType.table);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('ملف بيانات الطالب'),
              subtitle: const Text('عرض البيانات الأساسية للطالب فقط'),
              onTap: () {
                Navigator.pop(context);
                _generateAndSharePdf(ReportType.studentData);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.fullscreen_exit, color: Colors.deepPurple),
              title: const Text('تحميل تقرير شامل (صورة للصفحة)'),
              subtitle: const Text('يتم تصدير نسخة PDF من العرض الحالي للشاشة'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }


  Future<void> _generateAndSharePdf(ReportType reportType) async {
    final image1 = pw.MemoryImage(
      (await rootBundle.load('assets/1.png')).buffer.asUint8List(),
    );
    final image2 = pw.MemoryImage(
      (await rootBundle.load('assets/2.png')).buffer.asUint8List(),
    );
    final image3 = pw.MemoryImage(
      (await rootBundle.load('assets/3.png')).buffer.asUint8List(),
    );
    final image4 = pw.MemoryImage(
      (await rootBundle.load('assets/4.png')).buffer.asUint8List(),
    );

    final allAnalyses = _getAllAnalyses();
    final doc = pw.Document();
    final String studentName = _studentData?['name'] ?? 'student';
    final safeStudentName = studentName.replaceAll(' ', '_');

    String fileName = 'report_$safeStudentName.pdf';
    List<pw.Widget> content = [];

    pw.ThemeData arabicTheme;
    try {
      final fontData = await rootBundle.load("assets/Cairo-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);
      arabicTheme = pw.ThemeData.withFont(base: ttf, bold: ttf);
    } catch (e) {
      arabicTheme = pw.ThemeData();
    }

    switch (reportType) {
      case ReportType.graphical:
        fileName = 'graphical_report_$safeStudentName.pdf';
        content = [
          pw.Header(
            level: 0,
            child: pw.Text('تحليل الأداء الدراسي للطالب: $studentName',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center),
          ),
          _buildOverallAnalysisPdf(allAnalyses),
          pw.Divider(height: 30),
          pw.Text('التحليل التفصيلي للمواد',
              textDirection: pw.TextDirection.rtl,
              style:
              pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ...allAnalyses.map((analysis) => _buildSubjectPdf(analysis)),
        ];
        break;
      case ReportType.table:
        fileName = 'grades_report_$safeStudentName.pdf';
        content = [
          pw.Header(
            level: 0,
            child: pw.Text('تقرير الدرجات للطالب: $studentName',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center),
          ),
          _buildTableReportPdf(allAnalyses),
        ];
        break;
      case ReportType.studentData:
        fileName = 'student_data_$safeStudentName.pdf';
        content = [
          pw.Header(
            level: 0,
            child: pw.Text('بيانات الطالب: $studentName',
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center),
          ),
          _buildStudentDataPdf(),
        ];
        break;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: arabicTheme,
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(bottom: 20.0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image1, width: 120, height: 120),
                pw.Image(image2, width: 120, height: 120),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 20.0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image3, width: 60, height: 60),
                pw.Image(image4, width: 60, height: 60),
              ],
            ),
          );
        },
        build: (pw.Context context) => content,
      ),
    );

    try {
      await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تجهيز التقرير بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل فتح التقرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildStudentDataPdf() {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          _buildPdfTableRow('الاسم', _studentData?['name'] ?? 'غير متوفر'),
          _buildPdfTableRow('المرحلة', _studentData?['stages'] ?? 'غير متوفر'),
          _buildPdfTableRow('الصف', _studentData?['grades'] ?? 'غير متوفر'),
          _buildPdfTableRow('الفصل', _studentData?['classes'] ?? 'غير متوفر'),
          _buildPdfTableRow('هاتف ولي الأمر', _studentData?['guardian_phone'] ?? 'غير متوفر'),
        ],
      ),
    );
  }

  pw.Widget _buildTableReportPdf(List<_AnalysisResult> allAnalyses) {
    final List<pw.TableRow> rows = [];
    rows.add(
      pw.TableRow(
        children: [
          _buildPdfTableHeader('التقييم'),
          _buildPdfTableHeader('النسبة'),
          _buildPdfTableHeader('المتوسط'),
          _buildPdfTableHeader('المادة'),
        ],
      ),
    );

    for (final analysis in allAnalyses) {
      rows.add(
        pw.TableRow(
          children: [
            _buildPdfTableCell(analysis.assessment),
            _buildPdfTableCell('${(analysis.percentage * 100).toStringAsFixed(1)}%'),
            _buildPdfTableCell('${analysis.average.toStringAsFixed(1)} / ${analysis.maxPossibleGrade.toInt()}'),
            _buildPdfTableCell(analysis.subjectName),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
      },
      children: rows,
    );
  }

  pw.TableRow _buildPdfTableRow(String label, String value) {
    return pw.TableRow(children: [
      pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value, textDirection: pw.TextDirection.rtl)),
      pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
    ]);
  }

  pw.Widget _buildPdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildPdfTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          textDirection: pw.TextDirection.rtl),
    );
  }

  pw.Widget _buildOverallAnalysisPdf(List<_AnalysisResult> allAnalyses) {
    if (allAnalyses.isEmpty) return pw.SizedBox.shrink();

    final double overallAveragePercentage =
        allAnalyses.map((a) => a.percentage).reduce((a, b) => a + b) /
            allAnalyses.length;

    allAnalyses.sort((a, b) => b.average.compareTo(a.average));
    final strengths = allAnalyses.take(3).toList();
    final weaknesses = allAnalyses.reversed.take(3).toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'المحصلة النهائية والتقييم الشامل',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Text(
            'متوسط الأداء العام: ${(overallAveragePercentage * 100).toStringAsFixed(1)}%',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('نقاط القوة:', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...strengths.map((s) => pw.Text('- ${s.subjectName} (متوسط: ${s.average.toStringAsFixed(1)})', textDirection: pw.TextDirection.rtl)),
          pw.SizedBox(height: 10),
          pw.Text('مواد تحتاج إلى تركيز:', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...weaknesses.map((w) => pw.Text('- ${w.subjectName} (متوسط: ${w.average.toStringAsFixed(1)})', textDirection: pw.TextDirection.rtl)),
        ],
      ),
    );
  }

  pw.Widget _buildSubjectPdf(_AnalysisResult analysis) {
    PdfColor riskColor;
    switch (analysis.riskAssessment) {
      case 'مسار حرج':
        riskColor = PdfColors.red;
        break;
      case 'يحتاج لمتابعة':
        riskColor = PdfColors.orange;
        break;
      default:
        riskColor = PdfColors.green;
        break;
    }

    return pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 10),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                analysis.subjectName,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
              ),
              pw.Divider(height: 8),
              pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    _buildPdfInfoRow('المتوسط', '${analysis.average.toStringAsFixed(1)} / ${analysis.maxPossibleGrade.toInt()}'),
                    _buildPdfInfoRow('النسبة المئوية', '${(analysis.percentage * 100).toStringAsFixed(1)}%'),
                    _buildPdfInfoRow('التقييم العام', analysis.assessment),
                    _buildPdfInfoRow('أعلى درجة', analysis.highestGrade.toString()),
                    _buildPdfInfoRow('أدنى درجة', analysis.lowestGrade.toString()),
                    _buildPdfInfoRow('مستوى الأداء', analysis.consistency),
                    _buildPdfInfoRow('اتجاه الأداء', analysis.performanceTrend),
                    if (analysis.predictedNextGrade != null)
                      _buildPdfInfoRow('الدرجة التالية المتوقعة', '~${analysis.predictedNextGrade!.toStringAsFixed(1)}'),
                    _buildPdfInfoRow('تقييم المسار', analysis.riskAssessment, valueColor: riskColor),
                  ]
              ),
              if (analysis.testResults.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text('تفاصيل الدرجات:', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.center,
                  cellStyle: const pw.TextStyle(),
                  data: <List<String>>[
                    <String>['الدرجة', 'الاختبار'], // Headers
                    ...analysis.testResults.map((e) => ['${e.value} / ${analysis.maxPossibleGrade.toInt()}', e.key]).toList(),
                  ],
                )
              ]
            ]
        )
    );
  }

  pw.TableRow _buildPdfInfoRow(String label, String value, {PdfColor? valueColor}) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          value,
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(color: valueColor),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          label,
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ),
    ]);
  }
  Widget _buildNobleStudentView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              "🏆 قاعة الشرف: الطلاب المنضبطين 🏆",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('students')
                .orderBy('totalLikes', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('لا يوجد طلاب منظبطين حالياً.'));
              }
              final docs = snapshot.data!.docs;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (docs.length > 1) Flexible(child: _buildRankPodium(context, docs[1], 2)),
                    if (docs.isNotEmpty) Flexible(child: _buildRankPodium(context, docs[0], 1)),
                    if (docs.length > 2) Flexible(child: _buildRankPodium(context, docs[2], 3)),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade300, Colors.amber.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.card_giftcard, color: Colors.white, size: 30),
                          SizedBox(width: 12),
                          Text(
                            "مكافأة الأبطال",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "سيتم تكريم هؤلاء الطلاب المنضبطين وتكريمهم بمكافآت قيمة في جميع الفعاليات والاحتفالات المدرسية تقديراً لتميزهم.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankPodium(BuildContext context, DocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'طالب';
    final likes = data['totalLikes'] ?? 0;

    final podiumHeights = {1: 150.0, 2: 120.0, 3: 90.0};
    final rankColors = {
      1: Colors.amber,
      2: Colors.grey.shade400,
      3: const Color(0xFFCD7F32),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimatedTrophy(rank: rank),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thumb_up, color: Colors.blue.shade700, size: 16),
            const SizedBox(width: 4),
            Text('$likes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: 100,
          height: podiumHeights[rank],
          decoration: BoxDecoration(
            color: rankColors[rank],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(color: Colors.black.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJustificationPoint(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }

  Widget _buildBehaviorJustifications() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "مبررات الملاحظات السلوكية",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "هذا الموضوع من الأساليب التربوية الرقمية الحديثة لضبط الصف.",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const Divider(height: 20),
            _buildJustificationPoint(
              "1. التوضيح والحيادية (لماذا ظهرت العلامة؟)",
              "هذه العلامات هي إشعارات موضوعية يتم تسجيلها من قبل المعلمين عند ملاحظة سلوك محدد غير مناسب في الحصة (كمقاطعة، أو عدم التزام بالتعليمات). المعلم لا يضيف رأياً شخصياً أو تعليقاً، بل يوفر توثيقاً دقيقاً لحدوث السلوك.",
            ),
            _buildJustificationPoint(
              "2. دلالة العدد الكبير (رسالة الاستياء)",
              "في حالة تراكم عدد كبير من هذه العلامات، فإن ذلك يشير إلى أن هناك نمطاً سلوكياً ثابتاً يسبب استياءً متكرراً من عدة معلمين وفي حصص مختلفة. هذا الوضع يتجاوز الملاحظة العابرة ويتطلب تدخلكم الحاسم لتقويم مسار الطالب.",
            ),
            _buildJustificationPoint(
              "3. الدعوة للحل (ما هو دور ولي الأمر؟)",
              "دوركم محوري وضروري الآن. يرجى تخصيص وقت هادئ ومناسب لمناقشة أهمية احترام المعلم وقواعد الفصل. المرجو هو توجيه الطالب نحو تبني السلوك البديل الإيجابي والمناسب للمرحلة التعليمية.",
            ),
            _buildJustificationPoint(
              "4. خطة العمل المباشرة (الإجراء المتبع)",
              "نظامنا يعتمد على الشراكة. إذا وصل عدد العلامات إلى رقم مرتفع، يُرجى التواصل معنا لترتيب اجتماع تنسيقي عاجل لتوحيد جهود المدرسة والمنزل، وتحديد عواقب منطقية متفق عليها لهذا النمط السلوكي.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorNotesView() {
    if (_studentDocId == null) {
      return const Center(child: Text("بيانات الطالب غير متوفرة."));
    }
    final int totalDislikes = _studentData?['totalDislikes'] ?? 0;

    return ListView(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.priority_high, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "إجمالي الملاحظات: $totalDislikes",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Display justifications permanently.
        _buildBehaviorJustifications(),

        // --- Important note for the developer ---
        // This query requires a composite index in Firestore to work correctly.
        // If you encounter an error related to "missing index", please create the following index in your Firestore database:
        // Collection: behavior_reports
        // Fields:
        // 1. studentId (Ascending)
        // 2. type (Ascending)
        // 3. timestamp (Descending)
        // Without this index, the query will fail and the data will not be displayed.
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('behavior_reports')
              .where('studentId', isEqualTo: _studentDocId)
              .where('type', isEqualTo: 'dislike')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('حدث خطأ أثناء تحميل الملاحظات: ${snapshot.error}'),
              ));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 100, color: Colors.grey.shade400),
                      const SizedBox(height: 20),
                      const Text('لا توجد أي ملاحظات سلوكية مسجلة.',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }
            // Using a Column here because the parent is a ListView.
            return Column(
              children: snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.priority_high,
                                  color: Colors.red, size: 30),
                              const SizedBox(width: 12),
                              Flexible(
                                  child: Text(
                                      'ملاحظة سلوكية من المعلم: ${data['teacherName'] ?? 'غير معروف'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                          fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const Divider(height: 24),
                          Text.rich(TextSpan(
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800),
                              children: [
                                const TextSpan(
                                    text: 'في مادة: ',
                                    style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(
                                    text: '${data['subject'] ?? 'غير محدد'}'),
                              ])),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(_formatTimestamp(data['timestamp']),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600))
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildDashboardActions() {
    return [
      StreamBuilder<QuerySnapshot>(
        stream: _studentDocId == null
            ? null
            : FirebaseFirestore.instance
            .collection('students')
            .doc(_studentDocId)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          return badges.Badge(
            showBadge: count > 0,
            badgeContent: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 10)),
            position: badges.BadgePosition.topEnd(top: 4, end: 4),
            child: IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'الإشعارات',
              onPressed: _showNotifications,
            ),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.person_outline),
        tooltip: 'الملف الشخصي',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StudentProfilePage())),
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'تسجيل الخروج',
        onPressed: _signOutAndGoToLogin,
      ),
    ];
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        if (_studentDocId == null) {
          return const Center(child: Text("لا يمكن عرض الإشعارات."));
        }
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            _markNotificationsAsRead();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("الإشعارات",
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('students')
                        .doc(_studentDocId)
                        .collection('notifications')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text(
                                  "لا توجد إشعارات حالياً.",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey),
                                )));
                      }
                      return ListView.separated(
                        controller: scrollController,
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          Timestamp? ts = data['timestamp'];
                          String formattedDate = ts != null
                              ? intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar')
                              .format(ts.toDate())
                              : '..';
                          final bool isLike =
                          (data['message'] ?? '').contains('نبل');
                          return ListTile(
                            leading: Icon(
                                isLike
                                    ? Icons.sentiment_very_satisfied
                                    : Icons.priority_high,
                                color: isLike ? Colors.green : Colors.red),
                            title: Text(data['message'] ?? '...'),
                            subtitle: Text(formattedDate),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markNotificationsAsRead() async {
    if (_studentDocId == null) return;
    final notificationsRef = FirebaseFirestore.instance
        .collection('students')
        .doc(_studentDocId)
        .collection('notifications');
    final unreadNotifs =
    await notificationsRef.where('isRead', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unreadNotifs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _signOutAndGoToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar')
        .format(timestamp.toDate());
  }
}

class _AnimatedTrophy extends StatefulWidget {
  final int rank;
  const _AnimatedTrophy({required this.rank});

  @override
  __AnimatedTrophyState createState() => __AnimatedTrophyState();
}

class __AnimatedTrophyState extends State<_AnimatedTrophy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<int, dynamic> rankDetails = {
      1: {'color': const Color(0xFFFFD700), 'size': 70.0},
      2: {'color': const Color(0xFFC0C0C0), 'size': 60.0},
      3: {'color': const Color(0xFFCD7F32), 'size': 50.0},
    };

    return ScaleTransition(
      scale: _animation,
      child: Icon(
        Icons.emoji_events,
        color: rankDetails[widget.rank]['color'],
        size: rankDetails[widget.rank]['size'],
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
    );
  }
}

class _SubjectResultCard extends StatelessWidget {
  const _SubjectResultCard({
    required this.analysis,
    required this.subjectIcon,
    required this.color,
  });

  final _AnalysisResult analysis;
  final IconData subjectIcon;
  final Color color;

  Widget _getRiskAssessmentWidget() {
    IconData icon;
    Color color;
    switch (analysis.riskAssessment) {
      case 'مسار حرج':
        icon = Icons.dangerous;
        color = Colors.red.shade700;
        break;
      case 'يحتاج لمتابعة':
        icon = Icons.warning_amber_rounded;
        color = Colors.amber.shade800;
        break;
      default:
        icon = Icons.check_circle;
        color = Colors.green.shade700;
    }
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(analysis.riskAssessment,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(subjectIcon, size: 28, color: color),
                const SizedBox(width: 12),
                Text(analysis.subjectName,
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                _getRiskAssessmentWidget(),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircularPercentIndicator(
                  radius: 55.0,
                  lineWidth: 10.0,
                  animation: true,
                  percent: analysis.percentage,
                  center: Text(
                      "${(analysis.percentage * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20.0)),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                        "المتوسط: ${analysis.average.toStringAsFixed(1)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15.0)),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: color,
                  backgroundColor: color.withOpacity(0.2),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoChip(
                          label: 'التقييم العام',
                          value: analysis.assessment,
                          icon: Icons.military_tech_outlined,
                          color: color),
                      const SizedBox(height: 8),
                      _InfoChip(
                          label: 'مستوى الأداء',
                          value: analysis.consistency,
                          icon: Icons.show_chart_outlined,
                          color: color),
                      const SizedBox(height: 8),
                      _InfoChip(
                          label: 'أعلى درجة',
                          value: analysis.highestGrade.toString(),
                          icon: Icons.arrow_upward_outlined,
                          color: Colors.green),
                      const SizedBox(height: 8),
                      _InfoChip(
                          label: 'أدنى درجة',
                          value: analysis.lowestGrade.toString(),
                          icon: Icons.arrow_downward_outlined,
                          color: Colors.redAccent),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('التحليل التنبؤي للمسار',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPredictiveInfo(
              context,
              icon: Icons.trending_up,
              color: analysis.performanceTrend.contains('تحسن')
                  ? Colors.green
                  : (analysis.performanceTrend.contains('تراجع')
                  ? Colors.red
                  : Colors.grey),
              label: 'اتجاه الأداء',
              value: analysis.performanceTrend,
            ),
            const SizedBox(height: 12),
            if (analysis.predictedNextGrade != null)
              _buildPredictiveInfo(
                context,
                icon: Icons.track_changes,
                color: Theme.of(context).primaryColor,
                label: 'الدرجة التالية المتوقعة',
                value:
                '~${analysis.predictedNextGrade!.toStringAsFixed(1)} / ${analysis.maxPossibleGrade.toInt()}',
              ),
            const Divider(height: 32),
            Text('تتبع الأداء الزمني',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _PerformanceTrendChart(
                spots: analysis.trendSpots,
                color: color,
                maxGrade: analysis.maxPossibleGrade),
            const Divider(height: 32),
            ExpansionTile(
              title: Text('عرض تفاصيل الدرجات',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              tilePadding: EdgeInsets.zero,
              children: [
                ...analysis.testResults.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6.0, horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: const TextStyle(fontSize: 15)),
                        Text(
                            '${entry.value} / ${analysis.maxPossibleGrade.toInt()}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictiveInfo(BuildContext context,
      {required IconData icon,
        required Color color,
        required String label,
        required String value}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text('$label:',
            style:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

class _PerformanceTrendChart extends StatelessWidget {
  final List<FlSpot> spots;
  final Color color;
  final double maxGrade;

  const _PerformanceTrendChart({
    required this.spots,
    required this.color,
    required this.maxGrade,
  });

  @override
  Widget build(BuildContext context) {
    if (spots.length < 2) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text(
            'يتطلب عرض الرسم البياني وجود اختبارين على الأقل.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
            getDrawingVerticalLine: (value) =>
                FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: maxGrade / 4)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: _bottomTitleWidgets)),
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xff37434d), width: 1)),
          minY: 0,
          maxY: maxGrade,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                          radius: 5,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: Colors.white)),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Colors.grey.shade700,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text('الاختبار ${value.toInt() + 1}', style: style),
    );
  }
}