import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'chapters_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  String? userStandard;
  Map<String, List<String>> subjectsData = {};
  bool isLoading = true;
  String errorMsg = "";

  // Subject display names and icons
  final Map<String, Map<String, dynamic>> subjectMeta = {
    "maths":      {"label": "Mathematics", "icon": Icons.calculate},
    "science-i":  {"label": "Science I",   "icon": Icons.science},
    "science-ii": {"label": "Science II",  "icon": Icons.biotech},
    "physics":    {"label": "Physics",     "icon": Icons.electric_bolt},
    "chemistry":  {"label": "Chemistry",   "icon": Icons.science},
    "biology":    {"label": "Biology",     "icon": Icons.local_florist},
  };

  @override
  void initState() {
    super.initState();
    loadUserStandard();
  }

  Future<void> loadUserStandard() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          errorMsg = "Not logged in";
          isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          errorMsg = "User record not found";
          isLoading = false;
        });
        return;
      }

      // FIX: normalize the standard string to always be "class10" / "class12"
      // handles "Class 10", "class 10", "Class10", "class10" all correctly
      final rawStandard = userDoc["standard"]?.toString() ?? "class10";
      userStandard = rawStandard
          .toLowerCase()
          .replaceAll(" ", ""); // "Class 10" → "class10"

      await loadSubjects();
    } catch (e) {
      setState(() {
        errorMsg = "Failed to load user data: $e";
        isLoading = false;
      });
    }
  }

  Future<void> loadSubjects() async {
    try {
      final ref = FirebaseStorage.instance.ref("syllabus/$userStandard");
      final result = await ref.listAll();

      if (result.prefixes.isEmpty) {
        setState(() {
          errorMsg = "No subjects found for $userStandard";
          isLoading = false;
        });
        return;
      }

      Map<String, List<String>> temp = {};

      for (var folder in result.prefixes) {
        final subjectName = folder.name; // e.g. "maths", "science-i"
        final chapterFiles = await folder.listAll();
        // only include .json files, skip anything else
        final jsonFiles = chapterFiles.items
            .where((e) => e.name.endsWith(".json"))
            .map((e) => e.name)
            .toList();

        if (jsonFiles.isNotEmpty) {
          temp[subjectName] = jsonFiles;
        }
      }

      setState(() {
        subjectsData = temp;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = "Failed to load subjects. Check your internet connection.";
        isLoading = false;
      });
    }
  }

  String _subjectLabel(String key) {
    return subjectMeta[key.toLowerCase()]?["label"] ??
        key[0].toUpperCase() + key.substring(1);
  }

  IconData _subjectIcon(String key) {
    return subjectMeta[key.toLowerCase()]?["icon"] ?? Icons.menu_book;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8BEAFB), Color(0xFF081062)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── header ───────────────────────────────────────────────────
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Subjects — ${userStandard ?? ''}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // ── body ─────────────────────────────────────────────────────
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Loading
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text("Loading subjects...",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      );
    }

    // Error with retry
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 60),
              const SizedBox(height: 16),
              Text(
                errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMsg = "";
                  });
                  loadUserStandard();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF081062),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Subject grid
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: subjectsData.keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemBuilder: (context, index) {
        final subjectKey = subjectsData.keys.elementAt(index);
        return _subjectTile(subjectKey, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChaptersScreen(
                className: userStandard!,
                subject: subjectKey,
                chapters: subjectsData[subjectKey]!,
              ),
            ),
          );
        });
      },
    );
  }

  Widget _subjectTile(String subjectKey, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFAEEBFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_subjectIcon(subjectKey),
                size: 52, color: const Color(0xFF081062)),
            const SizedBox(height: 10),
            Text(
              _subjectLabel(subjectKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF081062),
              ),
            ),
          ],
        ),
      ),
    );
  }
}