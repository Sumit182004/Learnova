import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learnova/TakeTestScreen.dart';


class TestSeriesScreen extends StatefulWidget {
  const TestSeriesScreen({super.key});

  @override
  State<TestSeriesScreen> createState() => _TestSeriesScreenState();
}

class _TestSeriesScreenState extends State<TestSeriesScreen> {
  String userStandard = "class10";
  bool   isLoading    = true;
  List<Map<String, dynamic>> availableTests = [];

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // get student standard
      final userDoc = await FirebaseFirestore.instance
          .collection("users").doc(uid).get();
      userStandard = userDoc["standard"]?.toString() ?? "class10";

      // load tests for this standard
      final testsSnap = await FirebaseFirestore.instance
          .collection("tests")
          .where("standard", isEqualTo: userStandard)
          .where("published", isEqualTo: true)
          .get();

      // load best scores for this student
      final scoresSnap = await FirebaseFirestore.instance
          .collection("test_attempts")
          .doc(uid)
          .collection("attempts")
          .get();

      final scoresMap = <String, int>{};
      for (var doc in scoresSnap.docs) {
        scoresMap[doc.id] = doc["best_score"] ?? 0;
      }

      setState(() {
        availableTests = testsSnap.docs.map((doc) {
          final data  = doc.data();
          data["id"]  = doc.id;
          data["best_score"] = scoresMap[doc.id];
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
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

              // ── header ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 15, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Test Series",
                      style: TextStyle(
                        fontSize:   24,
                        fontWeight: FontWeight.bold,
                        color:      Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // ── body ─────────────────────────────────────────────────
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
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (availableTests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined,
                color: Colors.white54, size: 70),
            const SizedBox(height: 16),
            const Text(
              "No tests available yet.\nCheck back soon!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => isLoading = true);
                _loadTests();
              },
              icon:  const Icon(Icons.refresh),
              label: const Text("Refresh"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF081062),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: availableTests.length,
      itemBuilder: (context, index) {
        final test = availableTests[index];
        return _buildTestCard(test);
      },
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    final subject     = test["subject"]?.toString() ?? "";
    final chapter     = test["chapter"]?.toString() ?? "";
    final totalMarks  = test["total_marks"] ?? 0;
    final timeLimit   = test["time_limit_minutes"] ?? 0;
    final numQ        = (test["questions"] as List?)?.length ?? 0;
    final bestScore   = test["best_score"] as int?;
    final isMaths     = subject.toLowerCase().contains("math");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:        const Color(0xFFAEEBFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // subject badge + chapter name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        isMaths
                        ? const Color(0xFF081062)
                        : const Color(0xFF1D9E75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subject.toUpperCase(),
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        isMaths
                        ? const Color(0xFFEEEDFE)
                        : const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isMaths ? "MCQ" : "Written",
                    style: TextStyle(
                      color:      isMaths
                          ? const Color(0xFF3C3489)
                          : const Color(0xFF0F6E56),
                      fontSize:   11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // chapter name
            Text(
              chapter,
              style: const TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.bold,
                color:      Color(0xFF081062),
              ),
            ),

            const SizedBox(height: 10),

            // test info row
            Row(
              children: [
                _infoChip(Icons.quiz_outlined, "$numQ Questions"),
                const SizedBox(width: 8),
                _infoChip(Icons.star_outline, "$totalMarks Marks"),
                const SizedBox(width: 8),
                _infoChip(Icons.timer_outlined, "$timeLimit mins"),
              ],
            ),

            // best score
            if (bestScore != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        const Color(0xFF1D9E75).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Color(0xFF0F6E56), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Best Score: $bestScore / $totalMarks",
                      style: const TextStyle(
                        color:      Color(0xFF0F6E56),
                        fontSize:   13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // start button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startTest(test),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF081062),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  bestScore != null ? "Retake Test" : "Start Test",
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF334155)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF334155))),
      ],
    );
  }

  void _startTest(Map<String, dynamic> test) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TakeTestScreen(test: test),
      ),
    ).then((_) => _loadTests()); // refresh scores when returning
  }
}