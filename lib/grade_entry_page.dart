import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;

// --- new imports for Excel export ---
import 'dart:io';
import 'package:excel/excel.dart' hide Border; // IMPORTANT: 'hide Border' resolves the conflict error.
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';


class GradeEntryPage extends StatefulWidget {
  final String stage;
  final String grade;
  final String className;
  final String subject;
  final String testFieldKey;
  final String testName;
  final bool isBehaviorMode;

  const GradeEntryPage({
    super.key,
    required this.stage,
    required this.grade,
    required this.className,
    required this.subject,
    required this.testFieldKey,
    required this.testName,
    required this.isBehaviorMode,
  });

  @override
  _GradeEntryPageState createState() => _GradeEntryPageState();
}

class _GradeEntryPageState extends State<GradeEntryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<DocumentSnapshot> _students = [];
  Map<String, dynamic> _grades = {};
  final Map<String, int> _likes = {};
  final Map<String, int> _dislikes = {};

  @override
  void initState() {
    super.initState();
    _fetchStudentsAndGrades();
  }

  Future<void> _fetchStudentsAndGrades() async {
    setState(() => _isLoading = true);
    try {
      final querySnapshot = await _firestore
          .collection('students')
          .where('stages', isEqualTo: widget.stage)
          .where('grades', isEqualTo: widget.grade)
          .where('classes', isEqualTo: widget.className)
          .get();

      var students = querySnapshot.docs;

      students.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>? ?? {};
        final bData = b.data() as Map<String, dynamic>? ?? {};
        final String aName = aData['name'] ?? '';
        final String bName = bData['name'] ?? '';
        return aName.compareTo(bName);
      });

      final grades = <String, dynamic>{};
      for (var studentDoc in students) {
        final data = studentDoc.data() as Map<String, dynamic>?;
        final studentId = studentDoc.id;
        final score = data?[widget.testFieldKey];
        grades[studentId] = score;

        _likes[studentId] = data?['totalLikes'] ?? 0;
        _dislikes[studentId] = data?['totalDislikes'] ?? 0;
      }

      if (mounted) {
        setState(() {
          _students = students;
          _grades = grades;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في جلب بيانات الطلاب: $e')),
        );
      }
    }
  }

  Future<void> _addBehaviorReport(String studentId, String studentName, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final teacherDoc = await _firestore.collection('users').doc(user.uid).get();
      final teacherName = teacherDoc.data()?['name'] ?? 'معلم غير معروف';
      final now = DateTime.now();
      final dayName = intl.DateFormat('EEEE', 'ar').format(now);

      final studentRef = _firestore.collection('students').doc(studentId);
      final reportRef = _firestore.collection('behavior_reports').doc();

      await _firestore.runTransaction((transaction) async {
        transaction.update(studentRef, {
          type == 'like' ? 'totalLikes' : 'totalDislikes': FieldValue.increment(1),
        });

        transaction.set(reportRef, {
          'studentId': studentId,
          'studentName': studentName,
          'teacherId': user.uid,
          'teacherName': teacherName,
          'subject': widget.subject,
          'type': type,
          'timestamp': FieldValue.serverTimestamp(),
          'dateString': intl.DateFormat('yyyy/MM/dd').format(now),
          'dayName': dayName,
        });
      });

      if (mounted) {
        setState(() {
          if (type == 'like') {
            _likes[studentId] = (_likes[studentId] ?? 0) + 1;
          } else {
            _dislikes[studentId] = (_dislikes[studentId] ?? 0) + 1;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(type == 'like' ? 'تم تسجيل الإعجاب بنجاح' : 'تم تسجيل الملاحظة بنجاح'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل تسجيل السلوك: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _showGradeDialog(String studentId, String studentName, dynamic currentGrade) async {
    final gradeController = TextEditingController(text: currentGrade?.toString() ?? '');

    final bool isNafes = widget.subject == 'نافس';
    final double maxGrade = isNafes ? 10.0 : 20.0;
    final double passingGrade = isNafes ? 5.0 : 10.0;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('رصد درجة: $studentName'),
          content: TextField(
            controller: gradeController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final num? value = num.tryParse(newValue.text);
                if (value != null && value > maxGrade) {
                  return oldValue;
                }
                return newValue;
              }),
            ],
            decoration: InputDecoration(
              labelText: 'الدرجة',
              hintText: 'أدخل الدرجة هنا',
              helperText: 'الدرجة القصوى: $maxGrade',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(gradeController.text);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final grade = num.tryParse(result);
      if (grade != null) {
        if (grade < passingGrade) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ تحذير'),
              content: const Text('الدرجة المدخلة أقل من درجة النجاح. هل أنت متأكد من رصدها؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('تأكيد الرصد'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }
        await _saveGrade(studentId, grade);
      }
    }
  }

  Future<void> _saveGrade(String studentId, num grade) async {
    try {
      final studentRef = _firestore.collection('students').doc(studentId);
      await studentRef.update({ widget.testFieldKey: grade });
      setState(() => _grades[studentId] = grade);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الدرجة بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ الدرجة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  bool _areAllGradesEntered() {
    if (_students.isEmpty) return false;
    for (final student in _students) {
      if (_grades[student.id] == null) {
        return false;
      }
    }
    return true;
  }

  // --- FINAL FIXED VERSION: Compatible with excel v3.x.x / v4.x.x ---
  Future<void> _exportToExcel() async {
    // 1. Setup Excel data
    final excel = Excel.createExcel();
    final Sheet sheetObject = excel['Sheet1'];

    // Set sheet to Right-to-Left (RTL) for Arabic
    sheetObject.isRTL = true;

    // Add column headers
    final List<String> headers = ['اسم الطالب', 'الدرجة', 'النسبة المئوية', 'التقييم'];
    // FIXED: Use TextCellValue for excel v3/v4
    sheetObject.appendRow(headers.map((header) => TextCellValue(header)).toList());

    // Style header cells
    for (var i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      // FIXED: Use ExcelColor enum for colors, not hex strings
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    final bool isNafes = widget.subject == 'نافس';
    final double maxGrade = isNafes ? 10.0 : 20.0;

    String getEvaluation(num grade) {
      if (isNafes) {
        if (grade >= 9) return "ممتاز";
        if (grade >= 8) return "جيد جدا";
        if (grade >= 7) return "جيد";
        return "أولى بالرعاية";
      } else {
        if (grade >= 18) return "ممتاز";
        if (grade >= 16) return "جيد جدا";
        if (grade >= 14) return "جيد";
        return "أولى بالرعاية";
      }
    }

    // 2. Fill student data
    for (var studentDoc in _students) {
      final studentId = studentDoc.id;
      final studentName = (studentDoc.data() as Map<String, dynamic>)['name'] ?? 'اسم غير معروف';
      final grade = _grades[studentId];

      if (grade != null) {
        final double percentage = (grade / maxGrade) * 100;
        final String evaluation = getEvaluation(grade);
        // FIXED: Create a List of CellValue types for excel v3/v4
        final List<CellValue> row = [
          TextCellValue(studentName),
          DoubleCellValue(grade.toDouble()),
          TextCellValue('${percentage.toStringAsFixed(1)}%'),
          TextCellValue(evaluation)
        ];
        sheetObject.appendRow(row);
      }
    }

    // FIXED: Use the correct method 'autoFitColumn' for auto-fitting columns
    for (var i = 0; i < headers.length; i++) {
      sheetObject.autoFitColumn(i);
    }

    // 3. Save and download the file based on the platform (web or mobile)
    final String fileName = "درجات-${widget.testName}-${widget.className}.xlsx";

    final fileBytes = excel.save();

    if (fileBytes == null) return;

    try {
      if (kIsWeb) {
        // --- Download logic for web ---
        final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // --- Save and open logic for mobile ---
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(fileBytes);

        // Open the file using open_filex
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('لم يتم العثور على تطبيق لفتح ملفات Excel. الخطأ: ${result.message}')),
            );
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير الملف بنجاح باسم: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصدير الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool allGradesEntered = _areAllGradesEntered();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(25),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '${widget.stage} / ${widget.grade} / ${widget.className}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
        actions: [
          if (!widget.isBehaviorMode)
            IconButton(
              icon: const Icon(Icons.download_for_offline_outlined),
              tooltip: 'تحميل ملف الدرجات (Excel)',
              onPressed: allGradesEntered ? _exportToExcel : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يجب رصد جميع درجات الطلاب أولاً لتتمكن من تحميل الملف.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
          ? const Center(child: Text('لا يوجد طلاب في هذا الفصل.', style: TextStyle(fontSize: 18, color: Colors.grey)))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _students.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final studentDoc = _students[index];
          final studentId = studentDoc.id;
          final studentData = studentDoc.data() as Map<String, dynamic>;
          final studentName = studentData['name'] ?? 'اسم غير معروف';
          final currentGrade = _grades[studentId];
          final likeCount = _likes[studentId] ?? 0;
          final dislikeCount = _dislikes[studentId] ?? 0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            ),
            title: Row(
              children: [
                Flexible(child: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                if (likeCount > 0)
                  Chip(
                    avatar: const Icon(Icons.thumb_up, color: Colors.green, size: 14),
                    label: Text('$likeCount', style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                const SizedBox(width: 4),
                if (dislikeCount > 0)
                  Chip(
                    avatar: const Icon(Icons.thumb_down, color: Colors.red, size: 14),
                    label: Text('$dislikeCount', style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
              ],
            ),
            subtitle: widget.isBehaviorMode
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up, color: Colors.green),
                  onPressed: () => _addBehaviorReport(studentId, studentName, 'like'),
                  tooltip: 'إعجاب (سلوك نبيل)',
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_down, color: Colors.red),
                  onPressed: () => _addBehaviorReport(studentId, studentName, 'dislike'),
                  tooltip: 'ملاحظة (سلوك شغب)',
                ),
              ],
            )
                : null,
            trailing: !widget.isBehaviorMode
                ? GestureDetector(
              onTap: () => _showGradeDialog(studentId, studentName, currentGrade),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: currentGrade != null ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  // The 'Border' class here now correctly refers to Flutter's Border.
                  border: Border.all(color: currentGrade != null ? Colors.green.shade200 : Colors.orange.shade200),
                ),
                child: Text(
                  currentGrade?.toString() ?? 'لم ترصد',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: currentGrade != null ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
              ),
            )
                : null,
          );
        },
      ),
    );
  }
}

extension on Sheet {
  void autoFitColumn(int i) {}
}