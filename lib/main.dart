// main.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

// --- [تعديل] تم تحويل الاستدعاء المباشر إلى استدعاء مؤجل لتحسين سرعة التحميل ---
import 'package:almarefamecca/add.dart' deferred as add_page;
import 'package:almarefamecca/student_view.dart' deferred as student_view_page;
import 'package:almarefamecca/firebase_options.dart';

// --- [جديد] ويدجت بسيطة للتحميل المؤجل ---
class DeferredLoader extends StatefulWidget {
  final Future<void> libraryFuture;
  final Widget Function() builder;

  const DeferredLoader({
    required this.libraryFuture,
    required this.builder,
    super.key
  });

  @override
  _DeferredLoaderState createState() => _DeferredLoaderState();
}

class _DeferredLoaderState extends State<DeferredLoader> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.libraryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text('حدث خطأ أثناء تحميل الصفحة: ${snapshot.error}')));
          }
          return widget.builder();
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}


Future<void> _launchWhatsApp(BuildContext context) async {
  const phoneNumber = '966569064173'; // رقم الهاتف بدون + أو 00
  final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber');

  if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح تطبيق واتساب.')),
      );
    }
  }
}

Widget _buildWhatsAppButton(BuildContext context) {
  return Positioned(
    bottom: 16,
    left: 16,
    child: GestureDetector(
      onTap: () => _launchWhatsApp(context),
      child: Tooltip(
        message: 'تواصل معنا عبر واتساب',
        child: SizedBox(
          width: 120,
          height: 120,
          child: Lottie.asset('assets/whatsapp-button.json'),
        ),
      ),
    ),
  );
}

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
    const Color primaryColor = Color(0xFF1976D2);
    const Color accentColor = Color(0xFF00ACC1);
    const Color backgroundColor = Color(0xFFF5F5F5);

    return MaterialApp(
      title: 'بوابة مدرسة المعرفة الاهلية',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
      ],
      locale: const Locale('ar', ''),
      theme: ThemeData(
        fontFamily: 'Cairo',
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          secondary: accentColor,
          background: backgroundColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundColor,
        cardTheme: CardThemeData(
          elevation: 4,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryColor, width: 2),
              foregroundColor: primaryColor,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            )),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall:
          TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF212121)),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF424242)),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      // --- [تعديل] تم تبديل الصفحات بويدجت التحميل المؤجل الخاصة بها ---
      routes: {
        '/': (context) => const AuthWrapper(),
        '/add': (context) => DeferredLoader(
          libraryFuture: add_page.loadLibrary(),
          builder: () => add_page.AddPage(),
        ),
        '/student_view': (context) => DeferredLoader(
          libraryFuture: student_view_page.loadLibrary(),
          builder: () => student_view_page.StudentViewPage(),
        ),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String> _getUserRole(User user) async {
    try {
      final teacherDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (teacherDoc.exists) {
        return 'teacher';
      }
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();
      if (studentDoc.exists) {
        return 'student';
      }
      await FirebaseAuth.instance.signOut();
      return 'unauthorized';
    } catch (e) {
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
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          return FutureBuilder<String>(
            future: _getUserRole(authSnapshot.data!),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }

              switch (roleSnapshot.data) {
              // --- [تعديل] تم استبدال الاستدعاء المباشر بويدجت التحميل المؤجل ---
                case 'teacher':
                  return DeferredLoader(
                    libraryFuture: add_page.loadLibrary(),
                    builder: () => add_page.AddPage(),
                  );
                case 'student':
                  return DeferredLoader(
                    libraryFuture: student_view_page.loadLibrary(),
                    builder: () => student_view_page.StudentViewPage(),
                  );
                default:
                  return const WelcomePage();
              }
            },
          );
        }

        return const WelcomePage();
      },
    );
  }
}


// باقي الكود في ملف main.dart يبقى كما هو بدون تغيير
// WelcomePage, LoginPage, etc.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
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
                        const Icon(Icons.school, size: 100, color: Color(0xFF1976D2)),
                        const SizedBox(height: 24),
                        Text(
                          'بوابة مدرسة المعرفة الاهلية',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person),
                            label: const Text('دخول المعلمين'),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                const LoginPage(accountType: 'teacher'),
                              ));
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.child_care),
                            label: const Text('دخول الطلاب'),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                const LoginPage(accountType: 'student'),
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
          _buildWhatsAppButton(context),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final String accountType;
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
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user;

      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      bool isAuthorized = false;

      if (widget.accountType == 'teacher') {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          isAuthorized = true;
        }
      } else if (widget.accountType == 'student') {
        final doc = await _firestore.collection('students').doc(user.uid).get();
        if (doc.exists) {
          isAuthorized = true;
        }
      }

      if (mounted) {
        if (isAuthorized) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          await _auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'الحساب غير مصرح له بالدخول من هذه الواجهة.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ ما.';
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
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
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('assets/2.png'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
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
                          const Icon(Icons.school,
                              size: 100, color: Color(0xFF1976D2)),
                          const SizedBox(height: 24),
                          Text(portalName,
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor)),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني',
                                prefixIcon: Icon(Icons.email_outlined)),
                            validator: (value) => value!.isEmpty
                                ? 'الرجاء إدخال البريد الإلكتروني'
                                : null,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: Icon(Icons.lock_outline)),
                            validator: (value) =>
                            value!.isEmpty ? 'الرجاء إدخال كلمة المرور' : null,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                                onPressed: _signIn,
                                child: const Text('تسجيل دخول')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildWhatsAppButton(context),
        ],
      ),
    );
  }
}