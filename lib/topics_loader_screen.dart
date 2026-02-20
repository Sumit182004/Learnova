import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'explanation_screen.dart';

class TopicsLoaderScreen extends StatefulWidget {
  final String className;
  final String subject;
  final String chapterFile;

  const TopicsLoaderScreen({
    super.key,
    required this.className,
    required this.subject,
    required this.chapterFile,
  });

  @override
  State<TopicsLoaderScreen> createState() => _TopicsLoaderScreenState();
}

class _TopicsLoaderScreenState extends State<TopicsLoaderScreen> {
  List topics = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTopics();
  }

  Future<void> loadTopics() async {
    try {
      final ref = FirebaseStorage.instance.ref(
        "syllabus/${widget.className}/${widget.subject}/${widget.chapterFile}",
      );

      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));

      final data = jsonDecode(response.body);
      topics = data["topics"] ?? [];

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // SAME GRADIENT
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

              // ---------- HEADER ----------
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
                    const Text(
                      "Topics",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ---------- TOPIC LIST ----------
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: topics.length,
                  itemBuilder: (_, index) {
                    final topic = topics[index];

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExplanationScreen(
                              topicTitle: topic["title"],
                              blocks: topic["blocks"],
                              subject: widget.subject,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAEEBFF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [

                            // ---------- ICON ----------
                            const Icon(
                              Icons.school_rounded,
                              color: Color(0xFF081062),
                              size: 26,
                            ),

                            const SizedBox(width: 14),

                            // ---------- TOPIC TITLE ----------
                            Expanded(
                              child: Text(
                                topic["title"] ?? "Topic",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF081062),
                                ),
                              ),
                            ),

                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: Color(0xFF081062),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
