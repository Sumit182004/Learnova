import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:learnova/chapters_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  String? userStandard;
  Map<String, List<String>> subjectsData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserStandard();
  }

  Future<void> loadUserStandard() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .get();

      userStandard =
          userDoc["standard"].toString().toLowerCase().replaceAll(" ", "");

      await loadSubjects();
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> loadSubjects() async {
    try {
      final ref =
      FirebaseStorage.instance.ref("syllabus/$userStandard");

      final result = await ref.listAll();

      Map<String, List<String>> temp = {};

      for (var folder in result.prefixes) {
        String subjectName = folder.name;

        final chapterFiles = await folder.listAll();

        temp[subjectName] =
            chapterFiles.items.map((e) => e.name).toList();
      }

      setState(() {
        subjectsData = temp;
        isLoading = false;
      });
    } catch (e) {
      print("Firebase subject load error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || userStandard == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                      "Subjects - $userStandard",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: subjectsData.keys.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemBuilder: (context, index) {
                    String subjectName =
                    subjectsData.keys.elementAt(index);

                    return subjectTile(subjectName, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChaptersScreen(
                            className: userStandard!,
                            subject: subjectName,
                            chapters: subjectsData[subjectName]!,
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget subjectTile(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFAEEBFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF081062),
            ),
          ),
        ),
      ),
    );
  }
}
