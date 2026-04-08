import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Local calendar date for streak tracking (yyyy-MM-dd).
String _streakDateString(DateTime d) {
  final local = DateTime(d.year, d.month, d.day);
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _todayStreakString() => _streakDateString(DateTime.now());

String _yesterdayStreakString() =>
    _streakDateString(DateTime.now().subtract(const Duration(days: 1)));

/// If the user missed a full day of activity, reset streak to 0.
Future<void> normalizeStreakIfStale(String uid) async {
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);
  final snap = await ref.get();
  final data = snap.data() ?? {};
  final last = data['streakLastDate'] as String?;
  if (last == null || last.isEmpty) return;

  final today = _todayStreakString();
  final yesterday = _yesterdayStreakString();
  if (last == today || last == yesterday) return;

  await ref.set({'streak': 0}, SetOptions(merge: true));
}

/// Call when the user completes at least one checkbox (false → true) today.
Future<void> applyStreakOnTaskCompleted(String uid) async {
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);
  final snap = await ref.get();
  final data = snap.data() ?? {};
  final last = data['streakLastDate'] as String?;
  final current = (data['streak'] as num?)?.toInt() ?? 0;

  final today = _todayStreakString();
  final yesterday = _yesterdayStreakString();

  if (last == today) return;

  if (last == yesterday) {
    await ref.set({
      'streak': current + 1,
      'streakLastDate': today,
    }, SetOptions(merge: true));
    return;
  }

  await ref.set({
    'streak': 1,
    'streakLastDate': today,
  }, SetOptions(merge: true));
}

/// +10 XP the first time a roadmap video checkbox is completed (never again after uncheck/recheck).
Future<void> awardXpOnFirstCompletion(
  String uid,
  String roadmapDocId,
  int videoIndex,
) async {
  final key = '${roadmapDocId}_$videoIndex';
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final snap = await transaction.get(ref);
    final data = snap.data() ?? {};
    final keys = List<String>.from(data['xpAwardedKeys'] ?? []);
    if (keys.contains(key)) return;

    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    keys.add(key);
    transaction.set(
      ref,
      {
        'xp': xp + 10,
        'xpAwardedKeys': keys,
      },
      SetOptions(merge: true),
    );
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StudyPlannerApp());
}

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE), // Modern vibrant purple accent
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        // Global styling for TextFields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6200EE), width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIconColor: Colors.grey.shade500,
        ),
        // Global styling for the Login Button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6200EE),
            foregroundColor: Colors.white,
            elevation: 0, // Flat design
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── original state (unchanged) ────────────────────────────
  bool _isPasswordVisible = false;
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ── original auth logic (unchanged) ───────────────────────
  Future<void> signUpUser() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup Successful")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> loginUser() async {
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please verify your email before logging in."),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed")),
      );
    }
  }

  // ── build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final media             = MediaQuery.of(context);
    final isSmall           = media.size.width < 380;
    final horizontalPadding = media.size.width < 520 ? 20.0 : 28.0;
    final screenH           = media.size.height;
    final screenW           = media.size.width;

    return Scaffold(
      // no AppBar — full-bleed nature scene
      body: Stack(
        children: [
          // ── 0 · Sky gradient ────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.55, 1.0],
                  colors: [_N.skyTop, _N.skyMid, _N.skyHorizon],
                ),
              ),
            ),
          ),

          // ── 1 · Sun glow ─────────────────────────────────────
          Positioned(
            top: screenH * 0.07,
            right: screenW * 0.12,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _N.sunCore,
                    _N.sunHalo.withOpacity(0.38),
                    _N.skyMid.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),

          // ── 2 · Small clouds ─────────────────────────────────
          Positioned(
            top: screenH * 0.10,
            left: screenW * 0.06,
            child: _Cloud(width: 90, opacity: 0.55),
          ),
          Positioned(
            top: screenH * 0.16,
            left: screenW * 0.38,
            child: _Cloud(width: 60, opacity: 0.40),
          ),

          // ── 3 · Far hills (static — no scroll on login) ──────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenH * 0.50,
            child: ClipPath(
              clipper: const _HillClipper(
                  [0.0, 0.42, 0.52, 0.36, 0.48, 0.38, 0.55, 0.44, 1.0]),
              child: Container(color: _N.hillFar),
            ),
          ),

          // ── 4 · Mid hills ─────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenH * 0.38,
            child: ClipPath(
              clipper: const _HillClipper(
                  [0.0, 0.55, 0.40, 0.60, 0.36, 0.62, 0.48, 0.56, 1.0]),
              child: Container(color: _N.hillMid),
            ),
          ),

          // ── 5 · Near hills ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenH * 0.26,
            child: ClipPath(
              clipper: const _HillClipper(
                  [0.0, 0.60, 0.48, 0.55, 0.66, 0.45, 0.58, 0.68, 1.0]),
              child: Container(color: _N.hillNear),
            ),
          ),

          // ── 6 · Ground strip ──────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 64,
            child: Container(color: _N.ground),
          ),

          // ── 7 · Scrollable login card (foreground) ───────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _N.cardBg.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _N.cardBorder, width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: _N.hillNear.withOpacity(0.13),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.80),
                          blurRadius: 0,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      22,
                      isSmall ? 22 : 28,
                      22,
                      isSmall ? 18 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo icon ───────────────────────────
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _N.accentSoft,
                              border: Border.all(
                                  color: _N.cardBorder, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _N.accent.withOpacity(0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: _N.accent,
                              size: 34,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Headline ────────────────────────────
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.1,
                                color: _N.textDark,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Login to continue to Study Planner',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: _N.textMid,
                                height: 1.35,
                              ),
                        ),

                        const SizedBox(height: 28),

                        // ── thin divider ────────────────────────
                        Container(height: 1, color: _N.cardBorder),
                        const SizedBox(height: 24),

                        // ── Email field (unchanged controller) ──
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: _N.textDark),
                          decoration: InputDecoration(
                            labelText: 'Email address',
                            labelStyle:
                                const TextStyle(color: _N.textMid),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: _N.textMid,
                            ),
                            filled: true,
                            fillColor: _N.accentSoft.withOpacity(0.55),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: _N.cardBorder, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: _N.accent, width: 2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Password field (unchanged controller + toggle) ─
                        TextFormField(
                          controller: passwordController,
                          obscureText: !_isPasswordVisible,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: _N.textDark),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle:
                                const TextStyle(color: _N.textMid),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: _N.textMid,
                            ),
                            filled: true,
                            fillColor: _N.accentSoft.withOpacity(0.55),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: _N.cardBorder, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: _N.accent, width: 2),
                            ),
                            // ── original suffix toggle (unchanged) ──
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _N.textMid,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible =
                                      !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ── Forgot password (unchanged onPressed) ─
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: _N.accent,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Login button (unchanged onPressed: loginUser) ─
                        SizedBox(
                          height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF388E3C),
                                  Color(0xFF2E7D32),
                                  Color(0xFF1B5E20),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _N.accent.withOpacity(0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Login',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Sign-up row (unchanged navigation) ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(
                                color: _N.textMid,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              // ── original navigation (unchanged) ──
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SignupScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _N.accent,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CLOUD WIDGET  (pure UI helper, no logic)
// ─────────────────────────────────────────────────────────────
class _Cloud extends StatelessWidget {
  final double width;
  final double opacity;
  const _Cloud({required this.width, required this.opacity});

  @override
  Widget build(BuildContext context) {
    final h = width * 0.38;
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: width,
        height: h + 10,
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: h * 0.65,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              bottom: h * 0.40,
              left: width * 0.18,
              child: Container(
                width: width * 0.40,
                height: width * 0.40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: h * 0.28,
              left: width * 0.42,
              child: Container(
                width: width * 0.28,
                height: width * 0.28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (private to this file)
// ─────────────────────────────────────────────────────────────
class _N {
  // Sky
  static const skyTop     = Color(0xFF9ECFE8);
  static const skyMid     = Color(0xFFC9E8F5);
  static const skyHorizon = Color(0xFFE8F5FB);

  // Hills
  static const hillFar    = Color(0xFFB2DFDB);
  static const hillMid    = Color(0xFF80CBC4);
  static const hillNear   = Color(0xFF66BB6A);
  static const ground     = Color(0xFF4CAF50);

  // Sun
  static const sunCore    = Color(0xFFFFF9C4);
  static const sunHalo    = Color(0xFFFFEB3B);

  // Cards / UI
  static const cardBg     = Color(0xFFF6FCF6);
  static const cardBorder = Color(0xFFD4EDDA);
  static const accent     = Color(0xFF2E7D32);
  static const accentSoft = Color(0xFFE8F5E9);
  static const textDark   = Color(0xFF1B3A28);
  static const textMid    = Color(0xFF4A7C59);
  static const textLight  = Color(0xFF8AAF8A);

  // XP / streak badge tints (kept original hues)
  static const xpAmber      = Color(0xFFF59E0B);
  static const xpAmberDk    = Color(0xFFB45309);
  static const streakIndigo = Color(0xFF4F46E5);
}

// ─────────────────────────────────────────────────────────────
//  HILL CLIPPER
// ─────────────────────────────────────────────────────────────
class _HillClipper extends CustomClipper<Path> {
  final List<double> pts; // relative Y values 0..1
  const _HillClipper(this.pts);

  @override
  Path getClip(Size s) {
    final path = Path();
    final seg = s.width / (pts.length - 1);
    path.moveTo(0, s.height * pts.first);
    for (int i = 0; i < pts.length - 1; i++) {
      final x1 = i * seg;
      final x2 = (i + 1) * seg;
      final y1 = s.height * pts[i];
      final y2 = s.height * pts[i + 1];
      path.quadraticBezierTo(
        (x1 + x2) / 2,
        (y1 + y2) / 2 - s.height * 0.05,
        x2,
        y2,
      );
    }
    path.lineTo(s.width, s.height);
    path.lineTo(0, s.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HillClipper o) => o.pts != pts;
}

// ─────────────────────────────────────────────────────────────
//  HOME SCREEN
// ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scroll = ScrollController();
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) normalizeStreakIfStale(uid);
    });
    _scroll.addListener(() {
      if (mounted) setState(() => _offset = _scroll.offset);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _px(double speed) => (_offset * speed).clamp(-80.0, 80.0);

  // ── NEW: delete helper ────────────────────────────────────
  Future<void> _deleteRoadmap(
      BuildContext context, String uid, String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: _N.cardBg,
        title: const Text(
          'Delete roadmap?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _N.textDark,
            fontSize: 18,
          ),
        ),
        content: Text(
          '"${name.isEmpty ? 'Untitled roadmap' : name}" will be permanently deleted.',
          style: const TextStyle(color: _N.textMid, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: _N.textMid),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('roadmaps')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media             = MediaQuery.of(context);
    final horizontalPadding = media.size.width < 520 ? 16.0 : 20.0;
    final uid               = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnap) {
        final streak      = (userSnap.data?.data()?['streak'] as num?)?.toInt() ?? 0;
        final totalXp     = (userSnap.data?.data()?['xp']     as num?)?.toInt() ?? 0;
        final streakLabel = streak == 1 ? '🔥 1 day streak' : '🔥 $streak day streak';
        final xpLabel     = '⭐ $totalXp XP';

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(
              "Your roadmaps",
              style: TextStyle(
                color: _N.textDark,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                fontSize: 20,
              ),
            ),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: _N.skyTop.withOpacity(0.72),
            surfaceTintColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _N.xpAmber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: _N.xpAmber.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            xpLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _N.xpAmberDk,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _N.streakIndigo.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color:
                                    _N.streakIndigo.withValues(alpha: 0.18)),
                          ),
                          child: Text(
                            streakLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _N.streakIndigo,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          body: Stack(
            children: [
              // 0 · Sky gradient
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.5, 1.0],
                      colors: [_N.skyTop, _N.skyMid, _N.skyHorizon],
                    ),
                  ),
                ),
              ),

              // 1 · Sun glow
              Positioned(
                top: 72 - _px(0.05),
                right: media.size.width * 0.12,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _N.sunCore,
                        _N.sunHalo.withOpacity(0.40),
                        _N.skyMid.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // 2 · Far hills
              Positioned(
                bottom: -_px(0.10),
                left: 0,
                right: 0,
                height: media.size.height * 0.52,
                child: ClipPath(
                  clipper: const _HillClipper(
                      [0.0, 0.42, 0.52, 0.38, 0.48, 0.36, 0.55, 0.45, 1.0]),
                  child: Container(color: _N.hillFar),
                ),
              ),

              // 3 · Mid hills
              Positioned(
                bottom: -_px(0.18),
                left: 0,
                right: 0,
                height: media.size.height * 0.40,
                child: ClipPath(
                  clipper: const _HillClipper(
                      [0.0, 0.55, 0.42, 0.60, 0.38, 0.62, 0.50, 0.58, 1.0]),
                  child: Container(color: _N.hillMid),
                ),
              ),

              // 4 · Near hills
              Positioned(
                bottom: -_px(0.26),
                left: 0,
                right: 0,
                height: media.size.height * 0.28,
                child: ClipPath(
                  clipper: const _HillClipper(
                      [0.0, 0.62, 0.50, 0.55, 0.68, 0.46, 0.60, 0.70, 1.0]),
                  child: Container(color: _N.hillNear),
                ),
              ),

              // 5 · Ground strip
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 72,
                child: Container(color: _N.ground),
              ),

              // 6 · Scrollable foreground
              SafeArea(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('roadmaps')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(horizontalPadding),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _N.cardBg.withOpacity(0.94),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: _N.cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: _N.hillNear.withOpacity(0.12),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _N.accentSoft,
                                      border: Border.all(
                                          color: _N.cardBorder, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.eco_rounded,
                                      color: _N.accent,
                                      size: 34,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No roadmaps yet",
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _N.textDark,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Create your first roadmap to start tracking progress.",
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: _N.textMid,
                                          height: 1.45,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 12, horizontalPadding, 96),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final data  = docs[index].data();
                        final docId = docs[index].id;

                        final String name = (data['name'] ?? '').toString();
                        final double progress = (data['progress'] is num)
                            ? (data['progress'] as num).toDouble()
                            : 0.0;
                        final int percent =
                            (progress * 100).clamp(0, 100).round();

                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoadmapDetailScreen(
                                  docId: docId,
                                  name: data['name'],
                                  videos: List<String>.from(data['videos']),
                                  completed:
                                      List<bool>.from(data['completed']),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _N.cardBg.withOpacity(0.93),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: _N.cardBorder, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: _N.hillNear.withOpacity(0.10),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: -2,
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.75),
                                  blurRadius: 0,
                                  offset: const Offset(0, -1),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // icon accent
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: _N.accentSoft,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: _N.cardBorder),
                                      ),
                                      child: const Icon(
                                        Icons.route_rounded,
                                        color: _N.accent,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // name
                                    Expanded(
                                      child: Text(
                                        name.isEmpty
                                            ? "Untitled roadmap"
                                            : name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                              color: _N.textDark,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // percent badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _N.accentSoft,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                            color: _N.cardBorder),
                                      ),
                                      child: Text(
                                        "$percent%",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: _N.accent,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // ── NEW: delete button ───────────
                                    IconButton(
                                      onPressed: () => _deleteRoadmap(
                                          context, uid, docId, name),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                      ),
                                      color: const Color(0xFFE57373),
                                      splashRadius: 20,
                                      tooltip: 'Delete roadmap',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                    // ── end new ──────────────────────
                                  ],
                                ),

                                const SizedBox(height: 12),
                                Container(height: 1, color: _N.cardBorder),
                                const SizedBox(height: 12),

                                // progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    minHeight: 7,
                                    backgroundColor:
                                        _N.cardBorder.withOpacity(0.6),
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                            _N.accent),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // label
                                Text(
                                  "$percent% completed",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: _N.textMid,
                                        fontWeight: FontWeight.w600,
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
              ),
            ],
          ),

          floatingActionButton: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF388E3C),
                  Color(0xFF2E7D32),
                  Color(0xFF1B5E20),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _N.accent.withOpacity(0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Create roadmap',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose how you want to build your roadmap.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.ondemand_video_rounded,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                              title: const Text('YouTube Roadmap',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle:
                                  const Text('Import videos from a playlist'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AddRoadmapScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.checklist_rounded,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              title: const Text('Manual Roadmap',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: const Text('Add your own tasks'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ManualRoadmapScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        );
      },
    );
  }
}

class ManualRoadmapScreen extends StatefulWidget {
  const ManualRoadmapScreen({super.key});

  @override
  State<ManualRoadmapScreen> createState() => _ManualRoadmapScreenState();
}

class _ManualRoadmapScreenState extends State<ManualRoadmapScreen> {
  final TextEditingController _nameController = TextEditingController();
  late List<TextEditingController> _taskControllers;

  @override
  void initState() {
    super.initState();
    _taskControllers = [TextEditingController()];
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _outlineField({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF6200EE), width: 2),
      ),
    );
  }

  void _addTask() {
    setState(() {
      _taskControllers.add(TextEditingController());
    });
  }

  void _removeTask(int index) {
    if (_taskControllers.length <= 1) return;
    setState(() {
      final removed = _taskControllers.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final tasks = _taskControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (name.isEmpty || tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a roadmap name and at least one task.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('roadmaps')
        .add({
      'name': name,
      'videos': tasks,
      'completed': List.generate(tasks.length, (_) => false),
      'progress': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'manual',
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width < 520 ? 20.0 : 28.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual roadmap'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6200EE).withValues(alpha: 0.08),
              const Color(0xFF00C2FF).withValues(alpha: 0.08),
              const Color(0xFFFFFFFF),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 0,
                  color: Colors.white.withValues(alpha: 0.92),
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: _outlineField(
                            label: 'Roadmap name',
                            icon: Icons.route_rounded,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Tasks',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(_taskControllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _taskControllers[index],
                                    textInputAction: TextInputAction.next,
                                    decoration: _outlineField(
                                      label: 'Task ${index + 1}',
                                      icon: Icons.check_circle_outline_rounded,
                                    ),
                                  ),
                                ),
                                if (_taskControllers.length > 1) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    onPressed: () => _removeTask(index),
                                    icon: const Icon(Icons.close_rounded),
                                    color: Colors.grey.shade600,
                                    tooltip: 'Remove task',
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _addTask,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add task'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF7C3AED),
                                Color(0xFF4F46E5),
                                Color(0xFF2563EB),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                'Create roadmap',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class AddRoadmapScreen extends StatefulWidget {
  const AddRoadmapScreen({super.key});

  @override
  State<AddRoadmapScreen> createState() => _AddRoadmapScreenState();
}

class _AddRoadmapScreenState extends State<AddRoadmapScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController linkController = TextEditingController();

  List<String> videoTitles = [];
  late List<bool> isCompleted = [];

  double getProgress() {
  if (videoTitles.isEmpty) return 0;

  int completed = isCompleted.where((e) => e).length;
  return completed / videoTitles.length;
}

  String extractPlaylistId(String url) {
    final uri = Uri.parse(url);
    return uri.queryParameters['list'] ?? '';
  }

  Future<void> fetchPlaylistVideos() async {
    final playlistId = extractPlaylistId(linkController.text);

    const apiKey = "AIzaSyBVviVf9Gt_K9fayatRT6vYf93-11I3onI";

    final url =
        "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=$playlistId&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['items'];

      List<String> tempList = [];

      for (var item in items) {
        tempList.add(item['snippet']['title']);
      }

      setState(() {
        videoTitles = tempList;
        isCompleted = List.generate(tempList.length, (index) => false);
      });
    } else {
      print("Failed to fetch videos");
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Create Roadmap"),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    elevation: 0,
                    color: Colors.white.withValues(alpha: 0.92),
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: "Roadmap name",
                              prefixIcon: const Icon(Icons.route_rounded),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(18),
                                ),
                                borderSide: BorderSide(
                                  color: Color(0xFF6200EE),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: linkController,
                            decoration: InputDecoration(
                              labelText: "YouTube playlist link",
                              prefixIcon: const Icon(Icons.link_rounded),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(18),
                                ),
                                borderSide: BorderSide(
                                  color: Color(0xFF6200EE),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFF4F46E5),
                                  Color(0xFF2563EB),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await fetchPlaylistVideos();

                                  final user = FirebaseAuth.instance.currentUser;

                                  if (user != null) {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .collection('roadmaps')
                                        .add({
                                      'name': nameController.text,
                                      'videos': videoTitles,
                                      'completed': List.generate(
                                          videoTitles.length,
                                          (index) => false),
                                      'progress': 0.0,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                  }

                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  "Generate Roadmap",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Progress: ${(getProgress() * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        /// THIS FIXES THE ERROR
        Expanded(
          child: ListView.builder(
            itemCount: videoTitles.length,
            itemBuilder: (context, index) {
              return CheckboxListTile(
                title: Text(videoTitles[index]),
                value: (isCompleted.isNotEmpty && index < isCompleted.length)
                  ? isCompleted[index]
                  : false,
                onChanged: (value) {
                  setState(() {
                  if (isCompleted.isNotEmpty && index < isCompleted.length) {
                    isCompleted[index] = value ?? false;
      }
    });
  },
);
    },
  ),
),
      ],
    ),
  );
}}

class RoadmapDetailScreen extends StatefulWidget {
  final String docId;
  final String name;
  final List<String> videos;
  final List<bool>? completed;

  const RoadmapDetailScreen({
    super.key,
    required this.docId,
    required this.name,
    required this.videos,
    this.completed,
  });

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  late List<bool> isCompleted;

  @override
  void initState() {
    super.initState();
    isCompleted = widget.completed ??
      List.generate(widget.videos.length, (index) => false);
  }

  double getProgress() {
    if (widget.videos.isEmpty) return 0;
    int done = isCompleted.where((e) => e).length;
    return done / widget.videos.length;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final horizontalPadding = media.size.width < 520 ? 16.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;

            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('roadmaps')
                  .doc(widget.docId)
                  .update({
                'completed': isCompleted,
                'progress': getProgress(),
              });
            }

            Navigator.pop(context);
          },
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6200EE).withValues(alpha: 0.06),
              const Color(0xFF00C2FF).withValues(alpha: 0.06),
              const Color(0xFFFFFFFF),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              20,
            ),
            itemCount: widget.videos.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                final progress = getProgress().clamp(0.0, 1.0);
                final percent = (progress * 100).round();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 6,
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.06),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF4F46E5),
                                ),
                              ),
                              Text(
                                "$percent%",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Progress",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.06),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${isCompleted.where((e) => e).length} of ${widget.videos.length} videos completed",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final index = i - 1;
              final title = widget.videos[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CheckboxListTile(
                  value: isCompleted[index],
                  onChanged: (value) {
                    final newVal = value ?? false;
                    final wasCompleted = isCompleted[index];
                    setState(() {
                      isCompleted[index] = newVal;
                    });
                    if (newVal && !wasCompleted) {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        applyStreakOnTaskCompleted(uid);
                        awardXpOnFirstCompletion(uid, widget.docId, index);
                      }
                    }
                  },
                  activeColor: const Color(0xFF4F46E5),
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  title: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ── original controllers (unchanged) ─────────────────────
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();

  // ── original signup logic (unchanged) ────────────────────
  Future<void> signup() async {
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userCredential.user!.sendEmailVerification();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VerifyEmailScreen(),
        ),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media             = MediaQuery.of(context);
    final isSmall           = media.size.width < 380;
    final horizontalPadding = media.size.width < 520 ? 20.0 : 28.0;
    final screenH           = media.size.height;
    final screenW           = media.size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Sign Up",
          style: TextStyle(
            color: _N.textDark,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: _N.skyTop,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _N.textDark),
      ),
      body: Stack(
        children: [
          // 0 · Sky gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.55, 1.0],
                  colors: [_N.skyTop, _N.skyMid, _N.skyHorizon],
                ),
              ),
            ),
          ),

          // 1 · Sun glow
          Positioned(
            top: screenH * 0.06,
            right: screenW * 0.10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _N.sunCore,
                    _N.sunHalo.withOpacity(0.36),
                    _N.skyMid.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),

          // 2 · Clouds
          Positioned(
            top: screenH * 0.09,
            left: screenW * 0.05,
            child: _Cloud(width: 80, opacity: 0.50),
          ),
          Positioned(
            top: screenH * 0.18,
            left: screenW * 0.45,
            child: _Cloud(width: 55, opacity: 0.38),
          ),

          // 3 · Far hills
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenH * 0.50,
            child: ClipPath(
              clipper: const _HillClipper(
                [0.0, 0.44, 0.54, 0.38, 0.50, 0.36, 0.56, 0.46, 1.0],
              ),
              child: Container(color: _N.hillFar),
            ),
          ),

          // 4 · Mid hills
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenH * 0.38,
            child: ClipPath(
              clipper: const _HillClipper(
                [0.0, 0.56, 0.42, 0.62, 0.37, 0.64, 0.50, 0.58, 1.0],
              ),
              child: Container(color: _N.hillMid),
            ),
          ),

          // 5 · Near hills
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenH * 0.25,
            child: ClipPath(
              clipper: const _HillClipper(
                [0.0, 0.62, 0.50, 0.56, 0.68, 0.46, 0.60, 0.70, 1.0],
              ),
              child: Container(color: _N.hillNear),
            ),
          ),

          // 6 · Ground strip
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 64,
            child: Container(color: _N.ground),
          ),

          // 7 · Scrollable card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _N.cardBg.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _N.cardBorder, width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: _N.hillNear.withOpacity(0.13),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.80),
                          blurRadius: 0,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      22,
                      isSmall ? 22 : 28,
                      22,
                      isSmall ? 18 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Icon
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _N.accentSoft,
                              border: Border.all(
                                color: _N.cardBorder,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _N.accent.withOpacity(0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: _N.accent,
                              size: 34,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Headline
                        Text(
                          'Create your account',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.1,
                                color: _N.textDark,
                              ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'We\'ll send a verification link to your email',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: _N.textMid,
                                height: 1.35,
                              ),
                        ),

                        const SizedBox(height: 24),
                        Container(height: 1, color: _N.cardBorder),
                        const SizedBox(height: 22),

                        // Email field (unchanged controller)
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: _N.textDark),
                          decoration: InputDecoration(
                            labelText: 'Email address',
                            labelStyle: const TextStyle(color: _N.textMid),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: _N.textMid,
                            ),
                            filled: true,
                            fillColor: _N.accentSoft.withOpacity(0.55),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _N.cardBorder,
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _N.accent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Password field (unchanged controller)
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: _N.textDark),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: _N.textMid),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: _N.textMid,
                            ),
                            filled: true,
                            fillColor: _N.accentSoft.withOpacity(0.55),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _N.cardBorder,
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _N.accent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Create account button (unchanged onPressed: signup)
                        SizedBox(
                          height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF388E3C),
                                  Color(0xFF2E7D32),
                                  Color(0xFF1B5E20),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _N.accent.withOpacity(0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                "Create account",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        // end Column children
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // end Stack children
        ],
      ),
    );
  }
}

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isSmall = media.size.width < 380;
    final horizontalPadding = media.size.width < 520 ? 20.0 : 28.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Email"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6200EE).withValues(alpha: 0.08),
                const Color(0xFF00C2FF).withValues(alpha: 0.08),
                const Color(0xFFFFFFFF),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: Colors.white.withValues(alpha: 0.92),
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        22,
                        isSmall ? 22 : 26,
                        22,
                        isSmall ? 18 : 22,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFF4F46E5),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6200EE)
                                        .withValues(alpha: 0.22),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.mark_email_read_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Check your inbox',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'We sent a verification link to your email.\nVerify it to continue using Study Planner.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'If you don’t see it, check your spam/junk folder.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.grey.shade800,
                                          height: 1.3,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFF4F46E5),
                                    Color(0xFF2563EB),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5)
                                        .withValues(alpha: 0.28),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  final user = FirebaseAuth.instance.currentUser;

                                  await user?.reload();
                                  final refreshedUser = FirebaseAuth.instance.currentUser;

                                  if (refreshedUser != null &&
                                      refreshedUser.emailVerified) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const HomeScreen()),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Email not verified yet"),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  "I have verified",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                await user?.sendEmailVerification();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Verification email resent"),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.12),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                "Resend email",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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