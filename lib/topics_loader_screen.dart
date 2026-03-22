import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'explanation_screen.dart';

class TopicsLoaderScreen extends StatefulWidget {
  final String className;
  final String subject;
  final String chapterFile; // e.g. "real_numbers.json"

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
  String errorMsg = "";

  // FIX: derive chapter ID from filename for cache key
  String get chapterId =>
      widget.chapterFile.replaceAll(".json", "");

  @override
  void initState() {
    super.initState();
    loadTopics();
  }

  Future<void> loadTopics() async {
    setState(() {
      isLoading = true;
      errorMsg = "";
    });

    try {
      final ref = FirebaseStorage.instance.ref(
        "syllabus/${widget.className}/${widget.subject}/${widget.chapterFile}",
      );

      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        setState(() {
          errorMsg = "Failed to load topics. Please retry.";
          isLoading = false;
        });
        return;
      }

      final data = jsonDecode(response.body);
      setState(() {
        topics = data["topics"] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = "Could not load topics. Check your connection.";
        isLoading = false;
      });
    }
  }

  // clean chapter name for display
  String get chapterDisplayName => chapterId
      .replaceAll("_", " ")
      .split(" ")
      .map((w) => w.isNotEmpty
      ? w[0].toUpperCase() + w.substring(1)
      : w)
      .join(" ");

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

              // ── header ────────────────────────────────────────────────
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
                    Expanded(
                      child: Text(
                        chapterDisplayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── body ──────────────────────────────────────────────────
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text("Loading topics...",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      );
    }

    if (errorMsg.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.white70, size: 60),
              const SizedBox(height: 16),
              Text(
                errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: loadTopics,
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

    if (topics.isEmpty) {
      return const Center(
        child: Text(
          "No topics found in this chapter",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: topics.length,
      itemBuilder: (_, index) {
        final topic = topics[index];
        final topicId = topic["id"]?.toString() ?? "topic_$index";
        final topicTitle = topic["title"]?.toString() ?? "Topic ${index + 1}";
        final blocks = topic["blocks"] ?? [];

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExplanationScreen(
                  topicTitle: topicTitle,
                  // FIX: pass topicId and chapterId for cache key
                  topicId: topicId,
                  chapterId: chapterId,
                  blocks: blocks,
                  subject: widget.subject,
                  className: widget.className,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFAEEBFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded,
                    color: Color(0xFF081062), size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    topicTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF081062),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 18, color: Color(0xFF081062)),
              ],
            ),
          ),
        );
      },
    );
  }
}