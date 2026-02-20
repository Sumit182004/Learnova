import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

  final TextEditingController imageNameController = TextEditingController();

  String selectedClass = "class10";
  String selectedSubject = "maths";

  // ---------- Upload JSON ----------
  Future<void> uploadSyllabusJson(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return;

    File file = File(result.files.single.path!);
    String fileName = result.files.single.name;

    String storagePath =
        "syllabus/$selectedClass/$selectedSubject/$fileName";

    await FirebaseStorage.instance.ref(storagePath).putFile(file);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("JSON uploaded:\n$storagePath")),
    );
  }

  // ---------- Upload Image ----------
  Future<void> uploadFormulaImage(BuildContext context) async {
    if (imageNameController.text.trim().isEmpty) return;

    FilePickerResult? result =
    await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    File imageFile = File(result.files.single.path!);

    String imageName = imageNameController.text.trim();
    if (!imageName.endsWith(".png")) {
      imageName = "$imageName.png";
    }

    String storagePath =
        "media/$selectedClass/$selectedSubject/$imageName";

    await FirebaseStorage.instance.ref(storagePath).putFile(imageFile);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Image stored:\n$storagePath")),
    );

    imageNameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // SAME GRADIENT AS OTHER SCREENS
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8BEAFB), Color(0xFF081062)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [

                const Text(
                  "Admin Dashboard",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),

                const SizedBox(height: 25),

                // CLASS DROPDOWN
                dropdownCard(
                  DropdownButtonFormField(
                    value: selectedClass,
                    items: ["class10", "class12"]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedClass = v!),
                    decoration: const InputDecoration(
                        labelText: "Select Class",
                        border: OutlineInputBorder()),
                  ),
                ),

                const SizedBox(height: 15),

                // SUBJECT DROPDOWN
                dropdownCard(
                  DropdownButtonFormField(
                    value: selectedSubject,
                    items: ["maths", "science-I", "science-II"]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedSubject = v!),
                    decoration: const InputDecoration(
                        labelText: "Select Subject",
                        border: OutlineInputBorder()),
                  ),
                ),

                const SizedBox(height: 20),

                actionButton(Icons.upload_file, "Upload Syllabus JSON",
                        () => uploadSyllabusJson(context)),

                const SizedBox(height: 20),

                dropdownCard(
                  TextField(
                    controller: imageNameController,
                    decoration: const InputDecoration(
                      labelText: "Image Name (factor_tree)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                actionButton(Icons.image, "Upload Image",
                        () => uploadFormulaImage(context)),

                const Spacer(),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, "/login");
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Styled Card ----------
  Widget dropdownCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFAEEBFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  // ---------- Styled Button ----------
  Widget actionButton(IconData icon, String text, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFAEEBFF),
        foregroundColor: const Color(0xFF081062),
        minimumSize: const Size(double.infinity, 55),
      ),
      icon: Icon(icon),
      label: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: onTap,
    );
  }
}
