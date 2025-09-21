// homework_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

class HomeworkListPage extends StatefulWidget {
  final String stage;
  final String grade;
  final String className;
  final String subject;
  final String week;

  const HomeworkListPage({
    super.key,
    required this.stage,
    required this.grade,
    required this.className,
    required this.subject,
    required this.week,
  });

  @override
  _HomeworkListPageState createState() => _HomeworkListPageState();
}

class _HomeworkListPageState extends State<HomeworkListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // دالة لإظهار مربع حوار لإضافة أو تعديل واجب
  Future<void> _showAddEditDialog({DocumentSnapshot? homework}) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final isEditing = homework != null;

    PlatformFile? selectedFile;

    if (isEditing) {
      final data = homework.data() as Map<String, dynamic>;
      titleController.text = data['title'] ?? '';
      descriptionController.text = data['description'] ?? '';
    }

    // دالة لرفع الملف إلى Firebase Storage
    Future<(String, String)?> uploadFile(PlatformFile file, String subject) async {
      if (_auth.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ: يجب تسجيل الدخول لرفع الملفات.'), backgroundColor: Colors.red),
        );
        return null;
      }

      try {
        final filePath = '$subject/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = _storage.ref(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بدء رفع الملف...'), duration: Duration(seconds: 1)),
        );

        await ref.putData(file.bytes!);
        String downloadUrl = await ref.getDownloadURL();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الملف بنجاح!'), backgroundColor: Colors.green),
        );
        return (downloadUrl, file.name);
      } on FirebaseException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفع الملف: ${e.message}'), backgroundColor: Colors.red),
        );
        return null;
      }
    }

    // دالة لجلب اسم ورقم هاتف المعلم الحالي
    Future<Map<String, String?>> _getTeacherData() async {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userData = await _firestore.collection('users').doc(user.uid).get();
        final data = userData.data() as Map<String, dynamic>?;
        return {
          'name': data?['name'],
          'phone': data?['number'], // ** التعديل: استخدام 'number' بدلاً من 'phone'
        };
      }
      return {'name': null, 'phone': null};
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'تعديل الواجب' : 'إضافة واجب جديد لـ ${widget.week}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'العنوان')),
                    TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'الوصف')),
                    const SizedBox(height: 20),
                    if (selectedFile != null) Text('الملف المختار: ${selectedFile!.name}'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: const Text('اختيار ملف (صورة أو PDF)'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                        );
                        if (result != null) {
                          setDialogState(() {
                            selectedFile = result.files.first;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty || _auth.currentUser == null) return;

                    String? fileUrl, fileName, fileType;

                    if (selectedFile != null) {
                      final result = await uploadFile(selectedFile!, widget.subject);
                      if (result != null) {
                        fileUrl = result.$1;
                        fileName = result.$2;
                        fileType = selectedFile!.extension;
                      } else {
                        return; // إيقاف العملية إذا فشل الرفع
                      }
                    } else if (isEditing) {
                      final data = homework.data() as Map<String, dynamic>;
                      fileUrl = data['fileUrl'];
                      fileName = data['fileName'];
                      fileType = data['fileType'];
                    }

                    final teacherData = await _getTeacherData();

                    Map<String, dynamic> data = {
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'week': widget.week,
                      'stage': widget.stage,
                      'grade': widget.grade,
                      'class': widget.className,
                      'subject': widget.subject,
                      'teacherName': teacherData['name'],
                      'teacherPhone': teacherData['phone'],
                      'fileUrl': fileUrl,
                      'fileName': fileName,
                      'fileType': fileType,
                      // ** الإضافة: حفظ معرّف المعلم وتاريخ الإنشاء من الخادم
                      'teacherId': _auth.currentUser!.uid,
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    if (isEditing) {
                      await _firestore.collection('homework').doc(homework.id).update(data);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تعديل الواجب بنجاح.'), backgroundColor: Colors.green),
                      );
                    } else {
                      await _firestore.collection('homework').add(data);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تمت إضافة الواجب بنجاح. يمكنك تعديله أو حذفه خلال 10 دقائق.'),
                          duration: Duration(seconds: 5),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // دالة لتحويل Timestamp إلى تنسيق تاريخ ووقت مقروء
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('واجبات ${widget.subject} - ${widget.week}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('homework')
            .where('stage', isEqualTo: widget.stage)
            .where('grade', isEqualTo: widget.grade)
            .where('class', isEqualTo: widget.className)
            .where('subject', isEqualTo: widget.subject)
            .where('week', isEqualTo: widget.week)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(child: Text('حدث خطأ. تأكد من إنشاء الفهرس في Firestore. \n${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد واجبات مضافة لهذا الأسبوع.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // ** الإضافة: التحقق إذا كان المستخدم الحالي هو صاحب الواجب
              final String? teacherId = data['teacherId'];
              final bool isOwner = currentUserId != null && currentUserId == teacherId;

              // ** الإضافة: التحقق من الوقت المتبقي للتعديل
              final Timestamp? createdAtTimestamp = data['createdAt'];
              bool isEditable = false;
              if (createdAtTimestamp != null) {
                final createdAt = createdAtTimestamp.toDate();
                isEditable = DateTime.now().difference(createdAt).inMinutes < 10;
              }

              IconData fileIcon = Icons.attach_file;
              if (data['fileType'] == 'pdf') fileIcon = Icons.picture_as_pdf;
              if (['jpg', 'jpeg', 'png'].contains(data['fileType'])) fileIcon = Icons.image;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(data['description'] ?? 'لا يوجد وصف'),
                        ),
                        // ** التعديل: إظهار الأزرار فقط لصاحب الواجب
                        trailing: isOwner
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.green),
                              // ** التعديل: تعطيل الزر إذا انتهى الوقت
                              onPressed: isEditable ? () => _showAddEditDialog(homework: doc) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: isEditable
                                  ? () async {
                                if(data['fileUrl'] != null) {
                                  try {
                                    await _storage.refFromURL(data['fileUrl']).delete();
                                  } on FirebaseException catch(e) {
                                    print("Failed to delete file from storage: $e");
                                  }
                                }
                                await _firestore.collection('homework').doc(doc.id).delete();
                              }
                                  : null,
                            ),
                          ],
                        )
                            : null, // لا تظهر شيئاً إذا لم يكن المالك
                      ),
                      // ** الإضافة: إظهار رسالة إذا لم يعد الواجب قابلاً للتعديل
                      if (isOwner && !isEditable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'انتهت فترة التعديل (10 دقائق).',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          ),
                        ),
                      if (data['fileUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ActionChip(
                            avatar: Icon(fileIcon, color: Colors.white),
                            label: Text(data['fileName'] ?? 'عرض المرفق', style: const TextStyle(color: Colors.white)),
                            backgroundColor: Theme.of(context).primaryColor,
                            onPressed: () async {
                              final Uri url = Uri.parse(data['fileUrl']);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ),
                      const Divider(height: 24),
                      Text(
                        'نشر بواسطة: ${data['teacherName'] ?? 'غير معروف'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ النشر: ${_formatTimestamp(data['createdAt'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        tooltip: 'إضافة واجب جديد',
        child: const Icon(Icons.add),
      ),
    );
  }
}
