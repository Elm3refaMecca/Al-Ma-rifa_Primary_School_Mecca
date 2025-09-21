import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class HomeworkListPage extends StatefulWidget {
  final String stage;
  final String grade;
  final String term;
  final String className;
  final String subject;
  final String week;
  final String day;

  const HomeworkListPage({
    super.key,
    required this.stage,
    required this.grade,
    required this.term,
    required this.className,
    required this.subject,
    required this.week,
    required this.day,
  });

  @override
  _HomeworkListPageState createState() => _HomeworkListPageState();
}

class _HomeworkListPageState extends State<HomeworkListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    User? user = _auth.currentUser;
    if (user == null) return;
    try {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      if (mounted && userData.exists && (userData.data()?['role'] == 'admin')) {
        setState(() {
          _isAdmin = true;
        });
      }
    } catch (e) {
      debugPrint("Failed to check user role: $e");
    }
  }


  Future<void> _showAddEditDialog({DocumentSnapshot? homework}) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final isEditing = homework != null;

    PlatformFile? selectedFile;
    bool isUploading = false;

    if (isEditing) {
      final data = homework.data() as Map<String, dynamic>;
      titleController.text = data['title'] ?? '';
      descriptionController.text = data['description'] ?? '';
    }

    Future<(String, String)?> uploadFile(PlatformFile file, String subject) async {
      if (_auth.currentUser == null) return null;
      final filePath = '$subject/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref(filePath);
      await ref.putData(file.bytes!);
      String downloadUrl = await ref.getDownloadURL();
      return (downloadUrl, file.name);
    }

    Future<Map<String, String?>> _getTeacherData() async {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userData = await _firestore.collection('users').doc(user.uid).get();
        final data = userData.data() as Map<String, dynamic>?;
        // --- تعديل: استخدام حقل 'phone' ---
        return {'name': data?['name'], 'phone': data?['phone']};
      }
      return {'name': null, 'phone': null};
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'تعديل الواجب' : 'إضافة واجب جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('المادة: ${widget.subject} - ${widget.term} - ${widget.week} - ${widget.day}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 16),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'العنوان')),
                    TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'الوصف (اختياري)')),
                    const SizedBox(height: 20),
                    if (selectedFile != null) Text('الملف: ${selectedFile!.name}', overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: const Text('اختيار ملف'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                        );
                        if (result != null) {
                          const maxSizeInBytes = 2 * 1024 * 1024; // 2 MB
                          final file = result.files.first;
                          if (file.size > maxSizeInBytes) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('حجم الملف يتجاوز الحد المسموح به (2 ميجابايت)'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            selectedFile = file;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isUploading ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
                ElevatedButton(
                  child: isUploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('حفظ'),
                  onPressed: isUploading ? null : () async {
                    if (titleController.text.isEmpty || _auth.currentUser == null) return;

                    setDialogState(() { isUploading = true; });

                    try {
                      String? fileUrl, fileName, fileType;

                      if (selectedFile != null) {
                        final result = await uploadFile(selectedFile!, widget.subject);
                        if (result != null) {
                          fileUrl = result.$1;
                          fileName = result.$2;
                          fileType = selectedFile!.extension;
                        } else {
                          throw Exception("فشل رفع الملف");
                        }
                      } else if (isEditing) {
                        final data = homework.data() as Map<String, dynamic>;
                        fileUrl = data['fileUrl']; fileName = data['fileName']; fileType = data['fileType'];
                      }

                      final teacherData = await _getTeacherData();

                      Map<String, dynamic> data = {
                        'title': titleController.text, 'description': descriptionController.text,
                        'stage': widget.stage, 'grade': widget.grade, 'term': widget.term, 'class': widget.className,
                        'subject': widget.subject, 'week': widget.week, 'day': widget.day,
                        'teacherName': teacherData['name'], 'teacherPhone': teacherData['phone'],
                        'teacherId': _auth.currentUser!.uid, 'fileUrl': fileUrl,
                        'fileName': fileName, 'fileType': fileType,
                        'createdAt': FieldValue.serverTimestamp(),
                      };

                      if (isEditing) {
                        await _firestore.collection('homework').doc(homework.id).update(data);
                      } else {
                        await _firestore.collection('homework').add(data);
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ الواجب بنجاح'), backgroundColor: Colors.green),
                      );
                      Navigator.of(context).pop();

                    } catch (e) {
                      debugPrint("Error saving homework: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('فشل الحفظ. تأكد من اتصالك بالإنترنت ومن صلاحياتك.'), backgroundColor: Colors.red),
                      );
                    } finally {
                      if(mounted) {
                        setDialogState(() { isUploading = false; });
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.week} - ${widget.day}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('homework')
            .where('stage', isEqualTo: widget.stage)
            .where('grade', isEqualTo: widget.grade)
            .where('term', isEqualTo: widget.term)
            .where('class', isEqualTo: widget.className)
            .where('subject', isEqualTo: widget.subject)
            .where('week', isEqualTo: widget.week)
            .where('day', isEqualTo: widget.day)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Firestore Stream Error: ${snapshot.error}");
            return Center(child: Text('حدث خطأ أثناء تحميل البيانات: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد واجبات مضافة لهذا اليوم.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              final String? teacherId = data['teacherId'];
              final bool isOwner = currentUserId != null && currentUserId == teacherId;
              final Timestamp? createdAtTimestamp = data['createdAt'];
              bool isEditableWithinTime = false;
              if (createdAtTimestamp != null) {
                isEditableWithinTime = DateTime.now().difference(createdAtTimestamp.toDate()).inMinutes < 10;
              }

              final bool canModify = _isAdmin || (isOwner && isEditableWithinTime);

              IconData fileIcon = Icons.attach_file;
              final fileType = data['fileType']?.toString().toLowerCase();
              if (fileType == 'pdf') fileIcon = Icons.picture_as_pdf;
              if (['jpg', 'jpeg', 'png'].contains(fileType)) fileIcon = Icons.image;

              final randomColor = Colors.primaries[Random().nextInt(Colors.primaries.length)].shade100;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: randomColor, child: Icon(Icons.assignment, color: Colors.black54)),
                        title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(data['description'] ?? 'لا يوجد وصف', style: const TextStyle(color: Colors.black54)),
                        ),
                        trailing: (_isAdmin || isOwner)
                            ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showAddEditDialog(homework: doc);
                            } else if (value == 'delete') {
                              try {
                                if (data['fileUrl'] != null && (data['fileUrl'] as String).isNotEmpty) {
                                  await _storage.refFromURL(data['fileUrl']).delete();
                                }
                                await _firestore.collection('homework').doc(doc.id).delete();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم حذف الواجب بنجاح')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('حدث خطأ أثناء الحذف: قد يكون الملف غير موجود'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          enabled: canModify,
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(value: 'edit', child: Text('تعديل')),
                            const PopupMenuItem<String>(value: 'delete', child: Text('حذف')),
                          ],
                        )
                            : null,
                      ),
                      if (isOwner && !isEditableWithinTime && !_isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
                          child: Text('انتهت فترة التعديل/الحذف (10 دقائق)', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                        ),
                      if (data['fileUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 16.0),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text('المعلم: ${data['teacherName'] ?? 'غير معروف'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                            Text(_formatTimestamp(data['createdAt']), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        tooltip: 'إضافة واجب جديد',
        icon: const Icon(Icons.add),
        label: const Text('إضافة واجب'),
      ),
    );
  }
}