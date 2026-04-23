import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learnova/video_player_widget..dart';
import 'api_config.dart';

class ExplanationScreen extends StatefulWidget {
  final String topicTitle;
  final String topicId;
  final String chapterId;
  final List blocks;
  final String subject;
  final String className;

  const ExplanationScreen({
    super.key,
    required this.topicTitle,
    required this.topicId,
    required this.chapterId,
    required this.blocks,
    required this.subject,
    required this.className,
  });

  @override
  State<ExplanationScreen> createState() => _ExplanationScreenState();
}

class _ExplanationScreenState extends State<ExplanationScreen>
    with TickerProviderStateMixin {

  bool loading         = true;
  bool loadedFromCache = false;
  Map<String, dynamic>? explanationData;
  String error    = "";
  int visibleStep = 0;

  String get cacheKey =>
      "${widget.className}_${widget.subject}_${widget.chapterId}_${widget.topicId}";

  @override
  void initState() {
    super.initState();
    fetchExplanation();
  }
  String? videoUrl;
  bool generatingVideo = false;

  Widget _buildAvatarSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "AI Teacher",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF081062),
            ),
          ),

          const SizedBox(height: 10),

          if (videoUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoPlayerWidget(url: videoUrl!),
            )
          else
            Column(
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("AI Teacher is preparing your video..."),
              ],
            ),
        ],
      ),
    );
  }
  Future<void> loadVideoIfExists() async {
    final cached = await _getCachedVideo();
    if (cached != null) {
      setState(() => videoUrl = cached);
    }
  }
  Future<void> generateAvatarVideo() async {
    setState(() => generatingVideo = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/generate-avatar-video"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "topic": widget.topicTitle,
          "language": "English",
          "detail_level": "medium",
        }),
      );

      final data = jsonDecode(response.body);

      setState(() {
        videoUrl = data["video_url"];
        generatingVideo = false;
      });

    } catch (e) {
      setState(() => generatingVideo = false);
    }
  }
  // ── safe helpers ───────────────────────────────────────────────────────────
  List<String> safeList(dynamic data) {
    if (data is List) return data.map((e) => e.toString()).toList();
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
  Future<String?> _getCachedVideo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("videos")
          .doc(cacheKey)
          .get();

      if (doc.exists) {
        return doc.data()?["video_url"];
      }
    } catch (_) {}

    return null;
  }
  // ── get block types ────────────────────────────────────────────────────────
  List<String> getBlockTypes() {
    final types = <String>{};
    for (var block in widget.blocks) {
      if (block is Map && block["type"] != null) {
        types.add(block["type"].toString());
      }
    }
    return types.toList();
  }

  // ── check topic type ───────────────────────────────────────────────────────
  bool get isExerciseTopic {
    final types = getBlockTypes().toSet();
    return types.contains("exercise") &&
        !types.contains("theory") &&
        !types.contains("proof");
  }

  bool get isSummaryTopic {
    final types = getBlockTypes().toSet();
    return types.contains("summary") && types.length == 1;
  }

  // ── build AI content ───────────────────────────────────────────────────────
  String buildAIContent(List blocks) {
    final buffer = StringBuffer();
    for (var block in blocks) {
      if (block is Map<String, dynamic>) {
        switch (block["type"]) {
          case "theory":
            buffer.writeln(block["text"] ?? "");
            break;
          case "example":
            buffer.writeln("Example: ${block["question"] ?? ""}");
            buffer.writeln("Solution: ${block["solution"] ?? ""}");
            break;
          case "formula":
            buffer.writeln(
                "Formula: ${block["description"] ?? ""} — ${block["latex"] ?? ""}");
            break;
          case "proof":
            buffer.writeln("Proof: ${block["title"] ?? ""}");
            final steps = block["steps"];
            if (steps is List) {
              for (var step in steps) buffer.writeln("  - $step");
            }
            break;
          case "theorem":
            buffer.writeln(
                "Theorem: ${block["title"] ?? ""} — ${block["statement"] ?? ""}");
            break;
          case "activity":
            buffer.writeln(
                "Activity: ${block["title"] ?? ""} — ${block["description"] ?? ""}");
            break;
          case "image":
            final caption = block["caption"]?.toString() ?? "";
            if (caption.isNotEmpty) {
              buffer.writeln(
                  "[Diagram present in textbook: $caption — reference this diagram in your explanation]");
            }
            break;
          case "exercise":
            final questions = block["questions"];
            if (questions is List) {
              buffer.writeln("Exercise Questions:");
              for (var q in questions) buffer.writeln("  - $q");
            }
            break;
          case "summary":
            buffer.writeln("Chapter Summary: ${block["text"] ?? ""}");
            break;
        }
      }
    }
    return buffer.toString();
  }

  // ── cache ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _readCache() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("explanations")
          .doc(cacheKey)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!["explanation"] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeCache(Map<String, dynamic> explanation) async {
    try {
      await FirebaseFirestore.instance
          .collection("explanations")
          .doc(cacheKey)
          .set({
        "explanation": explanation,
        "topicTitle":  widget.topicTitle,
        "subject":     widget.subject,
        "className":   widget.className,
        "chapterId":   widget.chapterId,
        "topicId":     widget.topicId,
        "blockTypes":  getBlockTypes(),
        "generatedAt": FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
  Future<void> loadOrGenerateVideo() async {
    try {
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/generate-avatar-video"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "topic": widget.topicTitle,
          "script": explanationData?["concept_explanation"] ?? "",
        }),
      );

      final data = jsonDecode(res.body);
      String videoId = data["video_id"];
      print("VIDEO ID: $videoId");
      // start polling
      pollVideo(videoId);


    } catch (e) {
      debugPrint("Video error: $e");
    }
  }
  Future<void> pollVideo(String videoId) async {
    int tries = 0;

    while (tries < 40) { // max ~2 minutes
      try {
        final res = await http.get(
          Uri.parse("${ApiConfig.baseUrl}/video-status/$videoId"),
        );
        print("VIDEO STATUS RESPONSE: ${res.body}");
        final data = jsonDecode(res.body);

        print("VIDEO STATUS: $data");

        if (data["status"] == "completed") {
          setState(() {
            videoUrl = data["video_url"];
          });
          return;
        }

        if (data["status"] == "failed") {
          print("Video generation failed");
          return;
        }

        await Future.delayed(const Duration(seconds: 3));
        tries++;

      } catch (e) {
        print("Polling error: $e");
        return;
      }
    }

    print("Polling timeout");
  }
  // ── fetch ──────────────────────────────────────────────────────────────────
  Future<void> fetchExplanation() async {
    setState(() {
      loading         = true;
      error           = "";
      visibleStep     = 0;
      loadedFromCache = false;
    });

    // check cache first
    final cached = await _readCache();
    if (cached != null) {
      setState(() {
        explanationData = cached;
        loading         = false;
        loadedFromCache = true;
      });

      startTeacherFlow();

      // 👇 ADD THIS HERE
      loadOrGenerateVideo();

      return;
    }

    // call backend — ALL topics now get AI explanation
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/explain"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "topic":       widget.topicTitle,
          "content":     buildAIContent(widget.blocks),
          "subject":     widget.subject,
          "block_types": getBlockTypes(),
        }),
      );

      if (response.statusCode != 200) {
        setState(() { error = "Something went wrong. Please retry."; loading = false; });
        return;
      }

      final data = jsonDecode(response.body);
      if (!data.containsKey("explanation")) {
        setState(() { error = "Something went wrong. Please retry."; loading = false; });
        return;
      }

      final explanation = Map<String, dynamic>.from(data["explanation"]);
      await _writeCache(explanation);

      setState(() { explanationData = explanation; loading = false; });
      startTeacherFlow();
      loadOrGenerateVideo();

    } catch (e) {
      setState(() { error = "Something went wrong. Please retry."; loading = false; });
    }
  }

  // ── teacher flow ───────────────────────────────────────────────────────────
  void startTeacherFlow() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => visibleStep = 1);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => visibleStep = 2);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => visibleStep = 3);
  }

  bool get isMath {
    return explanationData?["general_steps"] is List &&
        (explanationData!["general_steps"] as List).isNotEmpty;
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF081062))),
    );
  }

  Widget _bulletList(List<String> list) {
    if (list.isEmpty) {
      return const Text("No data available",
          style: TextStyle(color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF081062))),
            Expanded(child: Text(e, style: const TextStyle(fontSize: 15))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _fadeIn(int step, Widget child) {
    return AnimatedOpacity(
      opacity: visibleStep >= step ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: child,
    );
  }

  Widget _buildImageBlocks() {
    final imageBlocks = widget.blocks
        .where((b) => b is Map && b["type"] == "image")
        .toList();
    if (imageBlocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Diagrams & Figures"),
        ...imageBlocks.map((b) {
          final url     = b["url"] as String? ?? "";
          final caption = b["caption"] as String? ?? "";
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE9FF)),
            ),
            child: Column(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                      height: 160, child: Center(child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) => const SizedBox(
                      height: 80,
                      child: Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey))),
                ),
              ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF334155))),
                ),
            ]),
          );
        }),
      ],
    );
  }

  Widget _exampleCard(String title, Map<String, dynamic> ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7F77DD).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3C3489), fontSize: 15)),
        const SizedBox(height: 8),
        Text("Q: ${safeText(ex["question"])}", style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _bulletList(safeList(ex["solution_steps"])),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1D9E75).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text("Answer: ${safeText(ex["final_answer"])}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F6E56))),
        ),
      ]),
    );
  }

  // ── exercise questions block ───────────────────────────────────────────────
  // shown BELOW AI explanation for exercise topics
  Widget _buildExerciseQuestions() {
    final exerciseBlocks = widget.blocks
        .where((b) => b is Map && b["type"] == "exercise")
        .toList();
    if (exerciseBlocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Exercise Questions"),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            "Now try solving these yourself using the approach above:",
            style: TextStyle(fontSize: 14, color: Color(0xFF334155), fontStyle: FontStyle.italic),
          ),
        ),
        ...exerciseBlocks.map((b) {
          final questions = b["questions"] as List? ?? [];
          return Column(
            children: questions.asMap().entries.map((entry) =>
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE9FF)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: Color(0xFF081062), shape: BoxShape.circle),
                        child: Center(
                          child: Text("${entry.key + 1}",
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.value.toString(), style: const TextStyle(fontSize: 15))),
                    ],
                  ),
                ),
            ).toList(),
          );
        }),
      ],
    );
  }

  // ── summary text block ─────────────────────────────────────────────────────
  // shown BELOW AI explanation for summary topics
  Widget _buildSummaryText() {
    final summaryBlocks = widget.blocks
        .where((b) => b is Map && b["type"] == "summary")
        .toList();
    if (summaryBlocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Textbook Summary"),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF9F27).withOpacity(0.4)),
          ),
          child: Text(
            summaryBlocks.first["text"]?.toString() ?? "",
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ),
      ],
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {

    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.topicTitle),
          backgroundColor: const Color(0xFF081062),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Preparing your explanation...",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Please wait while AI generates your lesson.\nNext time this topic will load instantly!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.topicTitle),
          backgroundColor: const Color(0xFF081062),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 60, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  "Could not load explanation.\nPlease check your connection and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: fetchExplanation,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Try Again"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF081062),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (explanationData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.topicTitle),
          backgroundColor: const Color(0xFF081062),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text("No explanation available")),
      );
    }

    final textbookExample = safeMap(explanationData?["textbook_example"]);
    final newExample      = safeMap(explanationData?["new_example"]);
    final practiceQs      = safeList(explanationData?["practice_questions"]);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: Text(widget.topicTitle, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF081062),
        foregroundColor: Colors.white,
        actions: [
          if (loadedFromCache)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text("Cached",
                    style: TextStyle(fontSize: 11, color: Color(0xFF0F6E56))),
                backgroundColor: const Color(0xFFE1F5EE),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── concept ──────────────────────────────────────────────────
            _fadeIn(1, Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Concept"),
                if (visibleStep >= 1)
                  _fadeIn(1, _buildAvatarSection()),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE9FF)),
                  ),
                  child: Text(safeText(explanationData?["concept_explanation"]),
                      style: const TextStyle(fontSize: 15, height: 1.6)),
                ),
              ],
            )),

            // ── images ─
            _fadeIn(2, _buildImageBlocks()),

            // ── math content ─
            if (isMath)
              _fadeIn(2, Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Steps to Solve"),
                  _bulletList(safeList(explanationData?["general_steps"])),
                  _sectionTitle("Textbook Example"),
                  if (textbookExample.isNotEmpty)
                    _exampleCard("Example", textbookExample),
                  _sectionTitle("Try This Example"),
                  if (newExample.isNotEmpty)
                    _exampleCard("New Example", newExample),
                ],
              )),

            // ── science content ───────────────────────────────────────────
            if (!isMath)
              _fadeIn(2, Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Key Points"),
                  _bulletList(safeList(explanationData?["key_points"])),
                  _sectionTitle("Example"),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(safeText(explanationData?["textbook_example"]),
                        style: const TextStyle(fontSize: 15, height: 1.6)),
                  ),
                  _sectionTitle("Real Life Application"),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(safeText(explanationData?["real_life_application"]),
                        style: const TextStyle(fontSize: 15, height: 1.6)),
                  ),
                ],
              )),

            // ── summary ───────────────────────────────────────────────────
            _fadeIn(3, Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Summary"),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF9F27).withOpacity(0.4)),
                  ),
                  child: Text(safeText(explanationData?["summary"]),
                      style: const TextStyle(fontSize: 15, height: 1.6)),
                ),
              ],
            )),

            // ── practice questions (from AI) ──────────────────────────────
            if (practiceQs.isNotEmpty)
              _fadeIn(3, Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Practice Questions"),
                  ...practiceQs.asMap().entries.map((entry) =>
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBAE9FF)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: const BoxDecoration(color: Color(0xFF081062), shape: BoxShape.circle),
                              child: Center(
                                child: Text("${entry.key + 1}",
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 15))),
                          ],
                        ),
                      ),
                  ),
                ],
              )),

            // ── exercise questions from JSON (shown below AI explanation) ──
            _fadeIn(3, _buildExerciseQuestions()),

            // ── textbook summary text (shown below AI recap) ───────────────
            _fadeIn(3, _buildSummaryText()),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}