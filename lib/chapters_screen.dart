import 'package:flutter/material.dart';
import 'topics_loader_screen.dart';

class ChaptersScreen extends StatelessWidget {
  final String className;
  final String subject;
  final List<String> chapters;

  const ChaptersScreen({
    super.key,
    required this.className,
    required this.subject,
    required this.chapters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // SAME GRADIENT AS SUBJECT SCREEN
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
                    Text(
                      subject.toUpperCase(),
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

              // ---------- CHAPTER LIST ----------
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapterFile = chapters[index];
                    final chapterName = chapterFile
                        .replaceAll(".json", "")
                        .replaceAll("_", " ");

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TopicsLoaderScreen(
                              className: className,
                              subject: subject,
                              chapterFile: chapterFile,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAEEBFF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            chapterName.toUpperCase(),
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
