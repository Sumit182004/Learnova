import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

enum AdminPage { uploadJson, uploadImage, viewFiles, createTest }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

  AdminPage currentPage = AdminPage.uploadJson;

  final imageNameController   = TextEditingController();
  final chapterIdController   = TextEditingController();
  final chapterNameController = TextEditingController();

  String selectedClass   = "class10";
  String selectedSubject = "maths";

  bool   isUploadingJson  = false;
  bool   isUploadingImage = false;
  double uploadProgress   = 0;

  List<String> uploadedFiles = [];
  bool isLoadingFiles        = false;

  bool   isGeneratingTest = false;
  bool   isPublishingTest = false;
  int    numQuestions     = 5;
  Map<String, dynamic>? generatedTest;

  @override
  void dispose() {
    imageNameController.dispose();
    chapterIdController.dispose();
    chapterNameController.dispose();
    super.dispose();
  }

  // ── subject items based on class ───────────────────────────────────────────
  List<DropdownMenuItem<String>> _subjectItems() {
    if (selectedClass == "class10") {
      return const [
        DropdownMenuItem(value: "maths",   child: Text("Mathematics")),
        DropdownMenuItem(value: "science", child: Text("Science")),
      ];
    } else {
      return const [
        DropdownMenuItem(value: "maths",     child: Text("Mathematics")),
        DropdownMenuItem(value: "physics",   child: Text("Physics")),
        DropdownMenuItem(value: "chemistry", child: Text("Chemistry")),
        DropdownMenuItem(value: "biology",   child: Text("Biology")),
      ];
    }
  }

  // ── check if current subject is valid for selected class ───────────────────
  String _validSubject() {
    final items = _subjectItems().map((e) => e.value!).toList();
    if (items.contains(selectedSubject)) return selectedSubject;
    return items.first; // fallback to first valid subject
  }

  // ── shared class + subject dropdowns ──────────────────────────────────────
  Widget _classSubjectSelectors() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedClass,
          items: const [
            DropdownMenuItem(value: "class10", child: Text("Class 10")),
            DropdownMenuItem(value: "class12", child: Text("Class 12")),
          ],
          // FIX: reset subject to "maths" when class changes
          onChanged: (v) => setState(() {
            selectedClass   = v!;
            selectedSubject = "maths";
          }),
          decoration: _dropDec("Class"),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _validSubject(), // FIX: always use valid subject value
          items: _subjectItems(),
          // FIX: was setting selectedClass instead of selectedSubject
          onChanged: (v) => setState(() => selectedSubject = v!),
          decoration: _dropDec("Subject"),
        ),
      ],
    );
  }

  // ── upload JSON ────────────────────────────────────────────────────────────
  Future<void> uploadSyllabusJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return;

    final file     = File(result.files.single.path!);
    final fileName = result.files.single.name;
    final path     = "syllabus/$selectedClass/$selectedSubject/$fileName";

    setState(() { isUploadingJson = true; uploadProgress = 0; });
    try {
      final task = FirebaseStorage.instance.ref(path).putFile(file);
      task.snapshotEvents.listen((e) =>
          setState(() => uploadProgress = e.bytesTransferred / e.totalBytes));
      await task;
      setState(() { isUploadingJson = false; uploadProgress = 0; });
      _snack("Uploaded: $fileName", Colors.green);
    } catch (e) {
      setState(() { isUploadingJson = false; uploadProgress = 0; });
      _snack("Upload failed: $e", Colors.red);
    }
  }

  // ── upload image ───────────────────────────────────────────────────────────
  Future<void> uploadFormulaImage() async {
    final chapterId = chapterIdController.text.trim();
    final imageName = imageNameController.text.trim();

    if (chapterId.isEmpty) { _snack("Enter chapter ID", Colors.orange); return; }
    if (imageName.isEmpty) { _snack("Enter image name", Colors.orange); return; }

    FilePickerResult? result =
    await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    final imageFile = File(result.files.single.path!);
    final finalName = imageName.endsWith(".png") ? imageName : "$imageName.png";
    final path      = "media/$selectedClass/$selectedSubject/$chapterId/$finalName";

    setState(() { isUploadingImage = true; uploadProgress = 0; });
    try {
      final task = FirebaseStorage.instance.ref(path).putFile(imageFile);
      task.snapshotEvents.listen((e) =>
          setState(() => uploadProgress = e.bytesTransferred / e.totalBytes));
      await task;
      setState(() { isUploadingImage = false; uploadProgress = 0; });
      imageNameController.clear();
      _snack("Image uploaded: $finalName", Colors.green);
    } catch (e) {
      setState(() { isUploadingImage = false; uploadProgress = 0; });
      _snack("Upload failed: $e", Colors.red);
    }
  }

  // ── load files ─────────────────────────────────────────────────────────────
  Future<void> loadFiles() async {
    setState(() { isLoadingFiles = true; uploadedFiles = []; });
    try {
      final ref    = FirebaseStorage.instance
          .ref("syllabus/$selectedClass/$selectedSubject");
      final result = await ref.listAll();
      setState(() {
        uploadedFiles  = result.items.map((e) => e.name).toList();
        isLoadingFiles = false;
      });
    } catch (e) {
      setState(() => isLoadingFiles = false);
      _snack("Error: $e", Colors.red);
    }
  }

  // ── generate test ──────────────────────────────────────────────────────────
  Future<void> _generateTest() async {
    final chapterName = chapterNameController.text.trim();
    if (chapterName.isEmpty) {
      _snack("Enter chapter name", Colors.orange);
      return;
    }

    setState(() { isGeneratingTest = true; generatedTest = null; });

    try {
      final fileName = "${chapterName.toLowerCase().replaceAll(" ", "_")}.json";
      final path     = "syllabus/$selectedClass/$selectedSubject/$fileName";

      String chapterContent = "";
      try {
        final ref = FirebaseStorage.instance.ref(path);
        final url = await ref.getDownloadURL();
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          final data   = jsonDecode(res.body);
          final buffer = StringBuffer();
          final topics = data["topics"] as List? ?? [];
          for (var topic in topics) {
            buffer.writeln("Topic: ${topic["title"] ?? ""}");
            final blocks = topic["blocks"] as List? ?? [];
            for (var block in blocks) {
              if (block["type"] == "theory") {
                buffer.writeln(block["text"] ?? "");
              } else if (block["type"] == "example") {
                buffer.writeln("Example: ${block["question"] ?? ""}");
                buffer.writeln("Solution: ${block["solution"] ?? ""}");
              } else if (block["type"] == "formula") {
                buffer.writeln("Formula: ${block["description"] ?? ""}");
              }
            }
            buffer.writeln("---");
          }
          chapterContent = buffer.toString();
        }
      } catch (_) {
        chapterContent =
        "Chapter: $chapterName for $selectedSubject $selectedClass";
      }

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/generate_test"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chapter":       chapterName,
          "subject":       selectedSubject,
          "standard":      selectedClass,
          "content":       chapterContent,
          "num_questions": numQuestions,
          "language":      "english",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          generatedTest    = data["test"];
          isGeneratingTest = false;
        });
        _snack("Test generated! Review and publish.", Colors.green);
      } else {
        setState(() => isGeneratingTest = false);
        _snack("Failed to generate test. Please retry.", Colors.red);
      }
    } catch (e) {
      setState(() => isGeneratingTest = false);
      _snack("Error: $e", Colors.red);
    }
  }

  // ── publish test ───────────────────────────────────────────────────────────
  Future<void> _publishTest() async {
    if (generatedTest == null) return;
    setState(() => isPublishingTest = true);
    try {
      await FirebaseFirestore.instance.collection("tests").add({
        ...generatedTest!,
        "standard":  selectedClass,
        "subject":   selectedSubject,
        "published": true,
        "createdAt": FieldValue.serverTimestamp(),
        "createdBy": FirebaseAuth.instance.currentUser?.uid,
      });
      setState(() {
        isPublishingTest = false;
        generatedTest    = null;
        chapterNameController.clear();
      });
      _snack("Test published successfully!", Colors.green);
    } catch (e) {
      setState(() => isPublishingTest = false);
      _snack("Publish failed: $e", Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ── PAGE: upload JSON ──────────────────────────────────────────────────────
  Widget _uploadJsonPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle("Upload Chapter JSON"),
          const SizedBox(height: 6),
          const Text("Select class, subject, then upload the .json file.",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 20),
          _card(_classSubjectSelectors()),
          const SizedBox(height: 20),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "The filename will be used as the chapter ID.\nExample: real_numbers.json → chapter ID: real_numbers",
                style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 14),
              if (isUploadingJson) ...[
                LinearProgressIndicator(value: uploadProgress),
                const SizedBox(height: 6),
                Text("Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
              ],
              _actionBtn(Icons.upload_file, "Select & Upload JSON",
                  isUploadingJson ? null : uploadSyllabusJson),
            ],
          )),
        ],
      ),
    );
  }

  // ── PAGE: upload image ─────────────────────────────────────────────────────
  Widget _uploadImagePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle("Upload Chapter Image"),
          const SizedBox(height: 6),
          const Text("Images stored under media/{class}/{subject}/{chapterId}/",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 20),
          _card(_classSubjectSelectors()),
          const SizedBox(height: 20),
          _card(Column(
            children: [
              TextField(
                controller: chapterIdController,
                decoration: const InputDecoration(
                  labelText:  "Chapter ID",
                  hintText:   "e.g. real_numbers",
                  helperText: "Must match JSON filename without .json",
                  border:     OutlineInputBorder(),
                  filled:     true,
                  fillColor:  Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageNameController,
                decoration: const InputDecoration(
                  labelText:  "Image name",
                  hintText:   "e.g. factor_tree",
                  helperText: ".png will be added automatically",
                  border:     OutlineInputBorder(),
                  filled:     true,
                  fillColor:  Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              if (isUploadingImage) ...[
                LinearProgressIndicator(value: uploadProgress),
                const SizedBox(height: 6),
                Text("Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
              ],
              _actionBtn(Icons.image, "Select & Upload Image",
                  isUploadingImage ? null : uploadFormulaImage),
            ],
          )),
        ],
      ),
    );
  }

  // ── PAGE: view files ───────────────────────────────────────────────────────
  Widget _viewFilesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle("View Uploaded Files"),
          const SizedBox(height: 6),
          const Text("Select class & subject to see uploaded JSON files.",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 20),
          _card(_classSubjectSelectors()),
          const SizedBox(height: 16),
          _actionBtn(Icons.search, "Load Files", loadFiles),
          const SizedBox(height: 24),
          if (isLoadingFiles)
            const Center(child: Column(children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text("Loading files...",
                  style: TextStyle(color: Colors.white70)),
            ])),
          if (!isLoadingFiles && uploadedFiles.isEmpty)
            Center(child: Column(children: [
              const Icon(Icons.folder_open, color: Colors.white38, size: 60),
              const SizedBox(height: 12),
              Text(
                "No files found.\nSelect class & subject then tap Load Files.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
            ])),
          if (!isLoadingFiles && uploadedFiles.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${uploadedFiles.length} file(s) — $selectedClass / $selectedSubject",
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            ...uploadedFiles.map((f) => Container(
              margin:  const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:        const Color(0xFFAEEBFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.description, color: Color(0xFF081062), size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(f,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: Color(0xFF081062)))),
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ]),
            )),
          ],
        ],
      ),
    );
  }

  // ── PAGE: create test ──────────────────────────────────────────────────────
  Widget _createTestPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle("Create Test"),
          const SizedBox(height: 6),
          const Text("AI will generate test questions from your chapter JSON.",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 20),

          _sectionLabel("Step 1 — Select class & subject"),
          _card(_classSubjectSelectors()),
          const SizedBox(height: 20),

          _sectionLabel("Step 2 — Chapter details"),
          _card(Column(
            children: [
              TextField(
                controller: chapterNameController,
                decoration: const InputDecoration(
                  labelText:  "Chapter name",
                  hintText:   "e.g. Real Numbers",
                  helperText: "Must match your uploaded JSON filename",
                  border:     OutlineInputBorder(),
                  filled:     true,
                  fillColor:  Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Text("Questions: ",
                    style: TextStyle(fontSize: 14, color: Color(0xFF334155))),
                Text("$numQuestions",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: Color(0xFF081062))),
              ]),
              Slider(
                value:      numQuestions.toDouble(),
                min:        3,
                max:        15,
                divisions:  12,
                label:      "$numQuestions",
                activeColor: const Color(0xFF081062),
                onChanged:  (v) => setState(() => numQuestions = v.toInt()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_timeInfo(), _marksInfo()],
              ),
            ],
          )),
          const SizedBox(height: 20),

          if (!isGeneratingTest && generatedTest == null)
            _actionBtn(Icons.auto_awesome, "Generate Test with AI",
                _generateTest),

          if (isGeneratingTest)
            _card(const Column(children: [
              CircularProgressIndicator(color: Color(0xFF081062)),
              SizedBox(height: 12),
              Text(
                "AI is generating questions...\nThis may take up to 30 seconds.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ])),

          if (generatedTest != null) ...[
            _sectionLabel("Step 3 — Review & Publish"),
            _buildTestPreview(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _generateTest,
              icon:  const Icon(Icons.refresh, color: Colors.white),
              label: const Text("Regenerate",
                  style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side:        const BorderSide(color: Colors.white),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            _actionBtn(Icons.publish,
                isPublishingTest ? "Publishing..." : "Publish Test",
                isPublishingTest ? null : _publishTest),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── test preview ───────────────────────────────────────────────────────────
  Widget _buildTestPreview() {
    if (generatedTest == null) return const SizedBox.shrink();

    final questions  = generatedTest!["questions"] as List? ?? [];
    final totalMarks = generatedTest!["total_marks"] ?? 0;
    final timeLimit  = generatedTest!["time_limit_minutes"] ?? 0;
    final isMaths    = selectedSubject.toLowerCase().contains("math");

    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _chip("${questions.length} Questions", const Color(0xFF081062)),
          const SizedBox(width: 8),
          _chip("$totalMarks Marks", const Color(0xFF1D9E75)),
          const SizedBox(width: 8),
          _chip("$timeLimit mins", const Color(0xFFEF9F27)),
        ]),
        const SizedBox(height: 16),
        ...questions.asMap().entries.map((entry) {
          final i = entry.key;
          final q = entry.value;
          return Container(
            margin:  const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Q${i + 1}. ${q["question"] ?? ""}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13,
                        color: Color(0xFF081062))),
                const SizedBox(height: 8),
                if (isMaths && q["options"] != null)
                  ...(q["options"] as Map<String, dynamic>)
                      .entries
                      .map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: opt.key == q["correct_option"]
                              ? const Color(0xFF1D9E75)
                              : Colors.grey.shade200,
                        ),
                        child: Center(child: Text(opt.key,
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold,
                                color: opt.key == q["correct_option"]
                                    ? Colors.white : Colors.grey))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(opt.value.toString(),
                          style: const TextStyle(fontSize: 12))),
                    ]),
                  )),
                if (!isMaths && q["model_answer"] != null) ...[
                  const Text("Model Answer:",
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D9E75))),
                  const SizedBox(height: 4),
                  Text(q["model_answer"].toString(),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF334155)),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Text("${q["marks"] ?? 1} mark(s)",
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        }),
      ],
    ));
  }

  Widget _timeInfo() {
    final isMaths  = selectedSubject.toLowerCase().contains("math");
    final timeMins = isMaths ? numQuestions * 2 : numQuestions * 6;
    return Text("⏱ $timeMins minutes",
        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)));
  }

  Widget _marksInfo() {
    final isMaths    = selectedSubject.toLowerCase().contains("math");
    final totalMarks = isMaths ? numQuestions * 1 : numQuestions * 5;
    return Text("⭐ $totalMarks total marks",
        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)));
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  // ── DRAWER ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
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
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color:  Colors.white.withOpacity(0.2),
                      shape:  BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Admin Panel",
                          style: TextStyle(color: Colors.white,
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Learnova",
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ]),
              ),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),
              _drawerItem(icon: Icons.upload_file, label: "Upload JSON",
                  page: AdminPage.uploadJson),
              _drawerItem(icon: Icons.image, label: "Upload Image",
                  page: AdminPage.uploadImage),
              _drawerItem(icon: Icons.folder_open, label: "View Files",
                  page: AdminPage.viewFiles),
              _drawerItem(icon: Icons.quiz, label: "Create Test",
                  page: AdminPage.createTest),
              const Spacer(),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout",
                    style: TextStyle(color: Colors.redAccent,
                        fontSize: 15, fontWeight: FontWeight.w600)),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, "/login");
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData  icon,
    required String    label,
    required AdminPage page,
  }) {
    final isActive = currentPage == page;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color:        isActive
            ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isActive ? Colors.white : Colors.white60, size: 22),
        title: Text(label,
            style: TextStyle(
              color:      isActive ? Colors.white : Colors.white60,
              fontSize:   15,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            )),
        trailing: isActive
            ? const Icon(Icons.circle, color: Colors.white, size: 8) : null,
        onTap: () {
          setState(() => currentPage = page);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final titles = {
      AdminPage.uploadJson:  "Upload JSON",
      AdminPage.uploadImage: "Upload Image",
      AdminPage.viewFiles:   "View Files",
      AdminPage.createTest:  "Create Test",
    };

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF081062),
        foregroundColor: Colors.white,
        title: Text(titles[currentPage]!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, "/login");
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8BEAFB), Color(0xFF081062)],
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
          ),
        ),
        child: currentPage == AdminPage.uploadJson
            ? _uploadJsonPage()
            : currentPage == AdminPage.uploadImage
            ? _uploadImagePage()
            : currentPage == AdminPage.viewFiles
            ? _viewFilesPage()
            : _createTestPage(),
      ),
    );
  }

  // ── shared UI helpers ──────────────────────────────────────────────────────
  Widget _pageTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white));

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        const Color(0xFFAEEBFF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  Widget _actionBtn(IconData icon, String text, VoidCallback? onTap) =>
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor:         const Color(0xFF081062),
          foregroundColor:         Colors.white,
          disabledBackgroundColor: Colors.grey,
          minimumSize:             const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon:      Icon(icon),
        label:     Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        onPressed: onTap,
      );

  InputDecoration _dropDec(String label) => InputDecoration(
    labelText: label,
    filled:    true,
    fillColor: Colors.white,
    border:    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:   BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF081062), width: 1.5)),
  );
}