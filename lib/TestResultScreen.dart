import 'package:flutter/material.dart';

class TestResultScreen extends StatelessWidget {
  final String testId;
  final String testName;
  final String subject;
  final int    score;
  final int    totalMarks;
  final List<Map<String, dynamic>> results;
  final bool   isMaths;

  const TestResultScreen({
    super.key,
    required this.testId,
    required this.testName,
    required this.subject,
    required this.score,
    required this.totalMarks,
    required this.results,
    required this.isMaths,
  });

  double get percentage =>
      totalMarks > 0 ? (score / totalMarks) * 100 : 0;

  Color get scoreColor {
    if (percentage >= 80) return const Color(0xFF1D9E75);
    if (percentage >= 50) return const Color(0xFFEF9F27);
    return Colors.red;
  }

  String get scoreMessage {
    if (percentage >= 80) return "Excellent! 🎉";
    if (percentage >= 60) return "Good Job! 👍";
    if (percentage >= 40) return "Keep Practicing! 💪";
    return "Don't Give Up! 📚";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

              // ── header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.quiz, color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        testName,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── score card ────────────────────────────────────────────
              Container(
                margin:  const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      scoreMessage,
                      style: const TextStyle(
                        fontSize:   22,
                        fontWeight: FontWeight.bold,
                        color:      Color(0xFF081062),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // score circle
                    Container(
                      width:  120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withOpacity(0.1),
                        border: Border.all(color: scoreColor, width: 4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$score",
                            style: TextStyle(
                              fontSize:   36,
                              fontWeight: FontWeight.bold,
                              color:      scoreColor,
                            ),
                          ),
                          Text(
                            "/ $totalMarks",
                            style: TextStyle(
                                fontSize: 14, color: scoreColor),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      "${percentage.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize:   20,
                        fontWeight: FontWeight.bold,
                        color:      scoreColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value:           percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(scoreColor),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── question results ──────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return isMaths
                        ? _buildMCQResult(index, result)
                        : _buildWrittenResult(index, result);
                  },
                ),
              ),

              // ── go home button ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(
                      context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF081062),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Go to Home",
                    style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MCQ result card ────────────────────────────────────────────────────────
  Widget _buildMCQResult(int index, Map<String, dynamic> result) {
    final isCorrect = result["is_correct"] as bool? ?? false;
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCorrect
                      ? const Color(0xFF1D9E75)
                      : Colors.red,
                ),
                child: Icon(
                  isCorrect ? Icons.check : Icons.close,
                  color: Colors.white,
                  size:  16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Q${index + 1}. ${result["question"] ?? ""}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize:   14,
                    color:      Color(0xFF081062),
                  ),
                ),
              ),
              Text(
                "${result["marks_obtained"]}/${result["total_marks"]}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      isCorrect
                      ? const Color(0xFF1D9E75)
                      : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isCorrect) ...[
            Text(
              "Your answer: ${result["student_answer"] ?? "Not answered"}",
              style: const TextStyle(
                  fontSize: 12, color: Colors.red),
            ),
            Text(
              "Correct answer: ${result["correct_answer"] ?? ""}",
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF1D9E75)),
            ),
          ],
          if (result["explanation"] != null &&
              result["explanation"].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "💡 ${result["explanation"]}",
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  // ── Written result card ────────────────────────────────────────────────────
  Widget _buildWrittenResult(int index, Map<String, dynamic> result) {
    final marksObtained = result["marks_obtained"] as int? ?? 0;
    final totalMarks    = result["total_marks"] as int? ?? 5;
    final percentage    = totalMarks > 0
        ? (marksObtained / totalMarks) * 100
        : 0.0;
    final color = percentage >= 60
        ? const Color(0xFF1D9E75)
        : Colors.orange;

    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "Q${index + 1}. ${result["question"] ?? ""}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize:   14,
                    color:      Color(0xFF081062),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "$marksObtained/$totalMarks",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   15,
                  color:      color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (result["student_answer"] != null &&
              result["student_answer"].toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Your answer: ${result["student_answer"]}",
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
          if (result["feedback"] != null &&
              result["feedback"].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "💡 ${result["feedback"]}",
                style: const TextStyle(
                    fontSize: 12,
                    color:    Colors.grey,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}