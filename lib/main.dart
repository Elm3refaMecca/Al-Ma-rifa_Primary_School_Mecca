import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appweb1/firebase_options.dart';
import 'package:appweb1/add.dart';
import 'package:appweb1/student_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('ar', null);
  runApp(const TeacherLoginApp());
}

class TeacherLoginApp extends StatelessWidget {
  const TeacherLoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بوابة الواجبات المدرسية',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''), // العربية
      ],
      locale: const Locale('ar', ''),
      theme: ThemeData(
        fontFamily: 'Cairo',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/add': (context) => const AddPage(),
        '/student_view': (context) => const StudentViewPage(),
      },
    );
  }
}

// --- منظم مصادقة للتحقق من حالة المستخدم وتوجيهه ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // دالة لتحديد دور المستخدم (معلم، طالب، أو غير مصرح له)
  Future<String> _getUserRole(User user) async {
    try {
      // 1. التحقق إذا كان المستخدم معلماً
      final teacherDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (teacherDoc.exists) {
        return 'teacher';
      }

      // 2. التحقق إذا كان المستخدم طالباً
      final studentQuery = await FirebaseFirestore.instance.collection('students').where('email', isEqualTo: user.email).limit(1).get();
      if (studentQuery.docs.isNotEmpty) {
        return 'student';
      }

      // 3. إذا لم يتم العثور على دور، يتم تسجيل خروج المستخدم
      await FirebaseAuth.instance.signOut();
      return 'unauthorized';
    } catch (e) {
      // في حالة حدوث أي خطأ، يتم تسجيل الخروج كإجراء احترازي
      await FirebaseAuth.instance.signOut();
      return 'unauthorized';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          // إذا كان المستخدم مسجلاً، تحقق من دوره واعرض الواجهة المناسبة
          return FutureBuilder<String>(
            future: _getUserRole(authSnapshot.data!),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              switch (roleSnapshot.data) {
                case 'teacher':
                  return const AddPage();
                case 'student':
                  return const StudentViewPage();
                default:
                // في حالة 'unauthorized' أو أي خطأ آخر
                  return const WelcomePage();
              }
            },
          );
        }

        // إذا لم يكن المستخدم مسجلاً، اعرض الواجهة الترحيبية
        return const WelcomePage();
      },
    );
  }
}


class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset('assets/e2.png', height: 100),
                    const SizedBox(height: 24),
                    const Text(
                      'بوابة الواجبات المدرسية',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.school),
                        label: const Text('تسجيل دخول كمعلم'),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const LoginPage(accountType: 'teacher'),
                          ));
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.family_restroom),
                        label: const Text('تسجيل دخول كطالب'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const LoginPage(accountType: 'student'),
                          ));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- واجهة تسجيل دخول موحدة مع منطق تحقق محسّن ---
class LoginPage extends StatefulWidget {
  final String accountType; // 'teacher' or 'student'
  const LoginPage({super.key, required this.accountType});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. المصادقة باستخدام Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user;

      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      bool isAuthorized = false;

      // 2. التحقق من الصلاحية في Firestore بناءً على نوع الحساب
      if (widget.accountType == 'teacher') {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          isAuthorized = true;
        }
      } else if (widget.accountType == 'student') {
        final query = await _firestore.collection('students').where('email', isEqualTo: user.email).limit(1).get();
        if (query.docs.isNotEmpty) {
          isAuthorized = true;
        }
      }

      // 3. التوجيه أو إظهار رسالة خطأ
      if (mounted) {
        if (isAuthorized) {
          // تم تسجيل الدخول بنجاح، أعد التوجيه إلى الواجهة الرئيسية
          // AuthWrapper سيتولى عرض الواجهة الصحيحة (معلم/طالب)
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          // الحساب موجود في Auth ولكن ليس له صلاحية للدخول من هذه الواجهة
          await _auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الحساب غير مصرح له بالدخول من هذه الواجهة.'), backgroundColor: Colors.red),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ ما.';
      if (e.code == 'invalid-credential' || e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.accountType == 'teacher';
    final title = isTeacher ? 'تسجيل دخول المعلم' : 'تسجيل دخول الطالب';
    final portalName = isTeacher ? 'بوابة المعلمين' : 'بوابة الطلاب';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset('assets/e2.png', height: 100),
                      const SizedBox(height: 24),
                      Text(portalName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                        validator: (value) => value!.isEmpty ? 'الرجاء إدخال البريد الإلكتروني' : null,
                        keyboardType: TextInputType.emailAddress,
                        // --- تعديل: إصلاح اتجاه النص ---
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (value) => value!.isEmpty ? 'الرجاء إدخال كلمة المرور' : null,
                        // --- تعديل: إصلاح اتجاه النص ---
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(onPressed: _signIn, child: const Text('تسجيل دخول')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}