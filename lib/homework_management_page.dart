import 'package:appweb1/day_selection_page.dart';
import 'package:flutter/material.dart';

class HomeworkManagementPage extends StatelessWidget {
  final String stage;
  final String grade;
  final String term; // إضافة الترم
  final String className;
  final String subject;

  HomeworkManagementPage({
    super.key,
    required this.stage,
    required this.grade,
    required this.term, // إضافة الترم
    required this.className,
    required this.subject,
  });

  final List<String> weeks = List.generate(16, (index) => 'الأسبوع ${index + 1}');

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = (MediaQuery.of(context).size.width / 150).floor().clamp(2, 4);

    return Scaffold(
      appBar: AppBar(
        title: Text('أسابيع مادة: $subject'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: weeks.length,
          itemBuilder: (context, index) {
            final week = weeks[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DaySelectionPage(
                      stage: stage,
                      grade: grade,
                      term: term, // تمرير الترم
                      className: className,
                      subject: subject,
                      week: week,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Card(
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.blue.shade200, width: 1),
                ),
                elevation: 2,
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
