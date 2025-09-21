import 'package:flutter/material.dart';
import 'package:appweb1/homework_list_page.dart';

class HomeworkManagementPage extends StatelessWidget {
  final String stage;
  final String grade;
  final String className;
  final String subject;

  HomeworkManagementPage({
    super.key,
    required this.stage,
    required this.grade,
    required this.className,
    required this.subject,
  });

  // قائمة الأسابيع الدراسية
  final List<String> weeks = List.generate(16, (index) => 'الأسبوع ${index + 1}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أسابيع مادة ${subject}'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: weeks.length,
          itemBuilder: (context, index) {
            final week = weeks[index];
            return InkWell(
              onTap: () {
                // الانتقال إلى صفحة الواجبات مع تمرير كل البيانات المطلوبة
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeworkListPage(
                      stage: stage,
                      grade: grade,
                      className: className,
                      subject: subject,
                      week: week,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Center(
                  child: Text(
                    week,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
