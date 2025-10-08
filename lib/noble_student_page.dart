import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;

class NobleStudentPage extends StatefulWidget {
  final String stage;
  final String grade;
  final String className;
  final String subject;

  const NobleStudentPage({
    super.key,
    required this.stage,
    required this.grade,
    required this.className,
    required this.subject,
  });

  @override
  _NobleStudentPageState createState() => _NobleStudentPageState();
}

class _NobleStudentPageState extends State<NobleStudentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<DocumentSnapshot> _students = [];
  final Map<String, int> _likes = {};
  final Map<String, int> _dislikes = {};


  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
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

      for (var studentDoc in students) {
        final data = studentDoc.data() as Map<String, dynamic>?;
        final studentId = studentDoc.id;

        // تعبئة خرائط الإعجابات والملاحظات
        _likes[studentId] = data?['totalLikes'] ?? 0;
        _dislikes[studentId] = data?['totalDislikes'] ?? 0;
      }

      if (mounted) {
        setState(() {
          _students = students;
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
          'subject': widget.subject, // إضافة مادة المعلم
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطالب المنضبط'),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up, color: Colors.green, size: 28),
                  onPressed: () => _addBehaviorReport(studentId, studentName, 'like'),
                  tooltip: 'إعجاب (سلوك نبيل)',
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_down, color: Colors.red, size: 28),
                  onPressed: () => _addBehaviorReport(studentId, studentName, 'dislike'),
                  tooltip: 'ملاحظة (سلوك شغب)',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}