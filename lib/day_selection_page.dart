import 'package:flutter/material.dart';
import 'package:appweb1/homework_list_page.dart';

class DaySelectionPage extends StatelessWidget {
  final String stage;
  final String grade;
  final String term; // إضافة الترم
  final String className;
  final String subject;
  final String week;

  DaySelectionPage({
    super.key,
    required this.stage,
    required this.grade,
    required this.term, // إضافة الترم
    required this.className,
    required this.subject,
    required this.week,
  });

  final List<String> days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('اختر اليوم - $week'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final day = days[index];
          return ListTile(
            title: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeworkListPage(
                    stage: stage,
                    grade: grade,
                    term: term, // تمرير الترم
                    className: className,
                    subject: subject,
                    week: week,
                    day: day,
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              child: Text('${index + 1}'),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            tileColor: Colors.white,
          );
        },
      ),
    );
  }
}
