import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isPasswordVisible = false;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> signUpUser() async {
  try {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Signup Successful")),
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

      // ❌ BLOCK if not verified
      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please verify your email before logging in."),
          ),
        );

        return;
      }

      // ✅ Allow if verified
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Minimalist Logo/Icon
                const Icon(
                  Icons.menu_book_rounded,
                  size: 80,
                  color: Color(0xFF6200EE),
                ),
                const SizedBox(height: 32),
                
                // App Title
                Text(
                  'Study Planner',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Welcome back! Please login to continue.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 48),

                // Email Input
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Input
                TextFormField(
                  controller: passwordController,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6200EE),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Login Action Button
                ElevatedButton(
                  onPressed: loginUser,
                  child: const Text('Login'),
                ),
                const SizedBox(height: 32),

                // Sign Up Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6200EE),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('roadmaps')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No roadmaps yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(data['name']),
                  subtitle: Text(
                    "${(data['progress'] * 100).toInt()}% completed",
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoadmapDetailScreen(
                                                docId: docId,
                                                name: data['name'],
                                                videos: List<String>.from(data['videos']),
                                                completed: List<bool>.from(data['completed']),
                                              ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRoadmapScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
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
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Roadmap Name",
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(
                  labelText: "YouTube Playlist Link",
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
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
                      'completed': List.generate(videoTitles.length, (index) => false),
                      'progress': 0.0,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }

                  Navigator.pop(context);
                },
                child: const Text("Generate Roadmap"),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
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
      body: Column(
        children: [
          const SizedBox(height: 20),

          // Progress
          Text(
            "Progress: ${(getProgress() * 100).toStringAsFixed(0)}%",
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: ListView.builder(
              itemCount: widget.videos.length,
              itemBuilder: (context, index) {
                return CheckboxListTile(
                  title: Text(widget.videos[index]),
                  value: isCompleted[index],
                  onChanged: (value) {
                    setState(() {
                      isCompleted[index] = value ?? false;
  });
},
                );
              },
            ),
          ),
        ],
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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> signup() async {
    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Send verification email
      await userCredential.user!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification email sent. Please check your inbox."),
        ),
      );

      Navigator.pop(context); // go back to login
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: signup,
              child: const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}