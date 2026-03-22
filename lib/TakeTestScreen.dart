import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'TestResultScreen.dart';
import 'api_config.dart';


class TakeTestScreen extends StatefulWidget {
  final Map<String, dynamic> test;
  const TakeTestScreen({super.key, required this.test});

  @override
  State<TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<TakeTestScreen> {

  int    currentQuestion = 0;
  bool   isSubmitting    = false;
  bool   testAbandoned   = false;

  // timer
  late Timer  _timer;
  int         secondsLeft = 0;

  // answers
  Map<int, String>  mcqAnswers     = {}; // question index → selected option
  Map<int, String>  writtenAnswers = {}; // question index → typed answer

  // text controllers for written answers
  Map<int, TextEditingController> controllers = {};

  bool get isMaths => normalize(widget.test["subject"] ?? "").contains("math");

  String normalize(String s) =>
      s.toLowerCase().replaceAll(" ", "").replaceAll("-", "");

  List get questions => widget.test["questions"] as List? ?? [];

  @override
  void initState() {
    super.initState();
    _startTimer();
    // init controllers for written answers
    if (!isMaths) {
      for (int i = 0; i < questions.length; i++) {
        controllers[i] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  // ── timer ──────────────────────────────────────────────────────────────────
  void _startTimer() {
    final timeLimit = widget.test["time_limit_minutes"] ?? 15;
    secondsLeft = timeLimit * 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft <= 0) {
        timer.cancel();
        _autoSubmit();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  String get timerDisplay {
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  bool get isTimerWarning => secondsLeft <= 60;

  // ── back button warning ────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text("Leave Test?"),
          ],
        ),
        content: const Text(
          "If you leave now your test will be marked as incomplete and you will score 0.\n\nAre you sure you want to exit?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Continue Test",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text("Exit Test",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      _timer.cancel();
      // save score as 0
      await _saveScore(0, abandoned: true);
      return true;
    }
    return false;
  }

  // ── auto submit when time runs out ─────────────────────────────────────────
  Future<void> _autoSubmit() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Time's up! Submitting your test..."),
        backgroundColor: Colors.orange,
      ),
    );
    await _submitTest();
  }

  // ── submit test ────────────────────────────────────────────────────────────
  Future<void> _submitTest() async {
    _timer.cancel();
    setState(() => isSubmitting = true);

    int totalScore    = 0;
    int totalMarks    = 0;
    List<Map<String, dynamic>> results = [];

    if (isMaths) {
      // MCQ evaluation — instant, no backend needed
      for (int i = 0; i < questions.length; i++) {
        final q             = questions[i];
        final correctOption = q["correct_option"]?.toString() ?? "";
        final studentOption = mcqAnswers[i] ?? "";
        final marks         = q["marks"] as int? ?? 1;
        final isCorrect     = studentOption == correctOption;

        totalMarks += marks;
        if (isCorrect) totalScore += marks;

        results.add({
          "question":        q["question"],
          "student_answer":  studentOption,
          "correct_answer":  correctOption,
          "is_correct":      isCorrect,
          "marks_obtained":  isCorrect ? marks : 0,
          "total_marks":     marks,
          "explanation":     q["explanation"] ?? "",
        });
      }
    } else {
      // Written — evaluate each answer with backend
      for (int i = 0; i < questions.length; i++) {
        final q             = questions[i];
        final studentAnswer = controllers[i]?.text.trim() ?? "";
        final marks         = q["marks"] as int? ?? 5;
        totalMarks         += marks;

        if (studentAnswer.isEmpty) {
          results.add({
            "question":       q["question"],
            "student_answer": "",
            "model_answer":   q["model_answer"] ?? "",
            "marks_obtained": 0,
            "total_marks":    marks,
            "feedback":       "No answer provided",
          });
          continue;
        }

        try {
          final response = await http.post(
            Uri.parse("${ApiConfig.baseUrl}/evaluate_answer"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "question":       q["question"],
              "model_answer":   q["model_answer"] ?? "",
              "student_answer": studentAnswer,
              "marks":          marks,
              "subject":        widget.test["subject"] ?? "science",
              "word_limit":     100,
            }),
          );

          if (response.statusCode == 200) {
            final data       = jsonDecode(response.body);
            final evaluation = data["evaluation"];
            final scored     = evaluation["scaled_score"] as int? ?? 0;
            totalScore      += scored;

            results.add({
              "question":       q["question"],
              "student_answer": studentAnswer,
              "model_answer":   q["model_answer"] ?? "",
              "marks_obtained": scored,
              "total_marks":    marks,
              "feedback":       evaluation["feedback"] ?? "",
              "evaluation":     evaluation,
            });
          } else {
            results.add({
              "question":       q["question"],
              "student_answer": studentAnswer,
              "model_answer":   q["model_answer"] ?? "",
              "marks_obtained": 0,
              "total_marks":    marks,
              "feedback":       "Could not evaluate. Please retry.",
            });
          }
        } catch (e) {
          results.add({
            "question":       q["question"],
            "student_answer": studentAnswer,
            "model_answer":   q["model_answer"] ?? "",
            "marks_obtained": 0,
            "total_marks":    marks,
            "feedback":       "Evaluation failed.",
          });
        }
      }
    }

    // save score to Firestore
    await _saveScore(totalScore, totalMarks: totalMarks);

    if (!mounted) return;

    // go to result screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TestResultScreen(
          testId:      widget.test["id"]?.toString() ?? "",
          testName:    widget.test["chapter"]?.toString() ?? "",
          subject:     widget.test["subject"]?.toString() ?? "",
          score:       totalScore,
          totalMarks:  totalMarks,
          results:     results,
          isMaths:     isMaths,
        ),
      ),
    );
  }

  Future<void> _saveScore(int score,
      {int? totalMarks, bool abandoned = false}) async {
    try {
      final uid    = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final testId = widget.test["id"]?.toString() ?? "";
      final ref    = FirebaseFirestore.instance
          .collection("test_attempts")
          .doc(uid)
          .collection("attempts")
          .doc(testId);

      final existing = await ref.get();
      final prevBest = existing.exists
          ? (existing.data()?["best_score"] as int? ?? 0)
          : 0;

      await ref.set({
        "test_id":      testId,
        "chapter":      widget.test["chapter"],
        "subject":      widget.test["subject"],
        "standard":     widget.test["standard"],
        "score":        score,
        "total_marks":  totalMarks ?? widget.test["total_marks"] ?? 0,
        "best_score":   score > prevBest ? score : prevBest,
        "abandoned":    abandoned,
        "attempted_at": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── word count ─────────────────────────────────────────────────────────────
  int _wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          width:  double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8BEAFB), Color(0xFF081062)],
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [

                // ── top bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // back with warning
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 26),
                        onPressed: () async {
                          final pop = await _onWillPop();
                          if (pop && mounted) Navigator.pop(context);
                        },
                      ),

                      Expanded(
                        child: Text(
                          widget.test["chapter"]?.toString() ?? "Test",
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isTimerWarning
                              ? Colors.red.withOpacity(0.8)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              color: Colors.white,
                              size:  16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timerDisplay,
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── progress bar ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Question ${currentQuestion + 1} of ${questions.length}",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (currentQuestion + 1) / questions.length,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── question content ───────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: questions.isEmpty
                        ? const Center(
                        child: Text("No questions found",
                            style: TextStyle(color: Colors.white)))
                        : isMaths
                        ? _buildMCQQuestion(currentQuestion)
                        : _buildWrittenQuestion(currentQuestion),
                  ),
                ),

                // ── navigation buttons ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // previous
                      if (currentQuestion > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(
                                    () => currentQuestion--),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Previous"),
                          ),
                        ),

                      if (currentQuestion > 0)
                        const SizedBox(width: 12),

                      // next or submit
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                            if (currentQuestion <
                                questions.length - 1) {
                              setState(() => currentQuestion++);
                            } else {
                              _confirmSubmit();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentQuestion ==
                                questions.length - 1
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFF081062),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                            height: 20,
                            width:  20,
                            child: CircularProgressIndicator(
                              color:       Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            currentQuestion ==
                                questions.length - 1
                                ? "Submit Test"
                                : "Next",
                            style: const TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── MCQ question ───────────────────────────────────────────────────────────
  Widget _buildMCQQuestion(int index) {
    final q       = questions[index];
    final options = q["options"] as Map<String, dynamic>? ?? {};
    final selected = mcqAnswers[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // question card
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Q${index + 1}. ${q["question"] ?? ""}",
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFF081062),
                  height:     1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${q["marks"] ?? 1} mark",
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // options
        ...options.entries.map((entry) {
          final isSelected = selected == entry.key;
          return GestureDetector(
            onTap: () => setState(
                    () => mcqAnswers[index] = entry.key),
            child: Container(
              margin:  const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF081062)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF081062)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width:  28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF081062)
                          .withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:      isSelected
                              ? const Color(0xFF081062)
                              : const Color(0xFF081062),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color:    isSelected
                            ? Colors.white
                            : const Color(0xFF081062),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Written question ───────────────────────────────────────────────────────
  Widget _buildWrittenQuestion(int index) {
    final q          = questions[index];
    final controller = controllers[index]!;
    final wordCount  = _wordCount(controller.text);
    final isOverLimit = wordCount > 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // question card
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Q${index + 1}. ${q["question"] ?? ""}",
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFF081062),
                  height:     1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "${q["marks"] ?? 5} marks",
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Word limit: 100 words",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // answer input
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: controller,
            maxLines:   8,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF081062)),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText:       "Write your answer here...",
              hintStyle:      TextStyle(color: Colors.grey),
              border:         InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // word count indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOverLimit
                    ? Colors.red.withOpacity(0.15)
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$wordCount / 100 words",
                style: TextStyle(
                  color:      isOverLimit ? Colors.red : Colors.white,
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        if (isOverLimit)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              "⚠️ Word limit exceeded — this will affect your score",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ── confirm submit dialog ──────────────────────────────────────────────────
  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Submit Test?"),
        content: Text(
          isMaths
              ? "You have answered ${mcqAnswers.length} of ${questions.length} questions.\nAre you sure you want to submit?"
              : "You have answered ${controllers.values.where((c) => c.text.trim().isNotEmpty).length} of ${questions.length} questions.\nAre you sure you want to submit?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Review First"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75)),
            child: const Text("Submit",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}