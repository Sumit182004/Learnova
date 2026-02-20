import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ExplanationScreen extends StatefulWidget {
  final String topicTitle;
  final List blocks;
  final String subject;

  const ExplanationScreen({
    super.key,
    required this.topicTitle,
    required this.blocks,
    required this.subject,
  });

  @override
  State<ExplanationScreen> createState() => _ExplanationScreenState();
}

class _ExplanationScreenState extends State<ExplanationScreen>
    with TickerProviderStateMixin {

  bool loading = true;
  Map<String, dynamic>? explanationData;
  String error = "";
  int visibleStep = 0;

  @override
  void initState() {
    super.initState();
    fetchExplanation();
  }

  // ================= SAFE HELPERS =================

  List<String> safeList(dynamic data) {
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  Map<String, dynamic> safeMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  String safeText(dynamic data) {
    if (data == null) return "";
    return data.toString();
  }

  // ================= BUILD AI CONTENT =================

  String buildAIContent(List blocks) {
    final buffer = StringBuffer();

    for (var block in blocks) {
      if (block is Map<String, dynamic>) {
        switch (block["type"]) {
          case "theory":
            buffer.writeln(block["text"] ?? "");
            break;
          case "example":
            buffer.writeln("Example Question: ${block["question"] ?? ""}");
            buffer.writeln("Textbook Solution: ${block["solution"] ?? ""}");
            break;
          case "formula":
            buffer.writeln("Formula: ${block["description"] ?? ""}");
            break;
          case "proof":
            buffer.writeln("Proof: ${block["title"] ?? ""}");
            break;
        }
      }
    }

    return buffer.toString();
  }

  // ================= FETCH EXPLANATION =================

  Future<void> fetchExplanation() async {
    setState(() {
      loading = true;
      error = "";
      visibleStep = 0;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/explain"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "topic": widget.topicTitle,
          "content": buildAIContent(widget.blocks),
          "subject": widget.subject,
        }),
      );

      print("STATUS CODE: ${response.statusCode}");
      print("RAW BODY: ${response.body}");

      if (response.statusCode != 200) {
        setState(() {
          error = "Server Error ${response.statusCode}";
          loading = false;
        });
        return;
      }

      final data = jsonDecode(response.body);

      if (!data.containsKey("explanation")) {
        setState(() {
          error = "Invalid AI response";
          loading = false;
        });
        return;
      }

      final explanation = data["explanation"];

      setState(() {
        explanationData = Map<String, dynamic>.from(explanation);
        loading = false;
      });

      startTeacherFlow();

    } catch (e) {
      print("FLUTTER ERROR: $e");
      setState(() {
        error = "Something went wrong";
        loading = false;
      });
    }
  }


  // ================= TEACHER FLOW =================

  void startTeacherFlow() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => visibleStep = 1);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => visibleStep = 2);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => visibleStep = 3);
  }

  // ================= UI HELPERS =================

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget bulletList(List<String> list) {
    if (list.isEmpty) {
      return const Text("No data available");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• "),
            Expanded(child: Text(e)),
          ],
        ),
      )).toList(),
    );
  }

  Widget fadeIn(int step, Widget child) {
    return AnimatedOpacity(
      opacity: visibleStep >= step ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: child,
    );
  }

  bool get isMath {
    return explanationData?["general_steps"] is List &&
        (explanationData?["general_steps"] as List).isNotEmpty;
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topicTitle)),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topicTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: fetchExplanation,
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    if (explanationData == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topicTitle)),
        body: const Center(child: Text("No explanation available")),
      );
    }

    final textbookExample =
    safeMap(explanationData?["textbook_example"]);
    final newExample =
    safeMap(explanationData?["new_example"]);

    return Scaffold(
      appBar: AppBar(title: Text(widget.topicTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===== CONCEPT =====
            fadeIn(
              1,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle("Concept"),
                  Text(
                    safeText(explanationData?["concept_explanation"]),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            // ===== MATH =====
            if (isMath)
              fadeIn(
                2,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionTitle("Steps"),
                    bulletList(
                        safeList(explanationData?["general_steps"])),

                    sectionTitle("Textbook Example"),
                    Text(
                      "Q: ${safeText(textbookExample["question"])}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    bulletList(
                        safeList(textbookExample["solution_steps"])),
                    Text(
                      "Answer: ${safeText(textbookExample["final_answer"])}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    sectionTitle("New Example"),
                    Text(
                      "Q: ${safeText(newExample["question"])}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    bulletList(
                        safeList(newExample["solution_steps"])),
                    Text(
                      "Answer: ${safeText(newExample["final_answer"])}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // ===== SCIENCE =====
            if (!isMath)
              fadeIn(
                2,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionTitle("Key Points"),
                    bulletList(
                        safeList(explanationData?["key_points"])),

                    sectionTitle("Textbook Example"),
                    Text(
                      safeText(explanationData?["textbook_example"]),
                    ),

                    sectionTitle("Real Life Application"),
                    Text(
                      safeText(
                          explanationData?["real_life_application"]),
                    ),
                  ],
                ),
              ),

            // ===== SUMMARY =====
            fadeIn(
              3,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle("Summary"),
                  Text(
                    safeText(explanationData?["summary"]),
                  ),
                ],
              ),
            ),

            // ===== PRACTICE =====
            if (safeList(explanationData?["practice_questions"])
                .isNotEmpty)
              fadeIn(
                3,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionTitle("Practice Time"),
                    bulletList(
                        safeList(explanationData?["practice_questions"])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
