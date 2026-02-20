import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  String userName = "User";

  @override
  void initState() {
    super.initState();
    loadUserName();
  }

  Future<void> loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection("users").doc(uid).get();

    if (userDoc.exists) {
      setState(() {
        userName = userDoc["name"] ?? "User";
      });
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
            colors: [
              Color(0xFF8BEAFB),
              Color(0xFF081062),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🔹 TOP BAR WITH FIRESTORE NAME
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Hello, $userName",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pushNamed(context, "/profile"),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                //
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBAE9FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Continue Learning",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text("Last Topic: Oxidation & Reduction",
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF081062),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Continue"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // 🔹 GRID MENU
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    children: [
                      menuTile(Icons.menu_book, "Subjects",
                              () => Navigator.pushNamed(context, "/subjects")),
                      menuTile(Icons.psychology, "AI Assistant", () {}),
                      menuTile(Icons.edit_document, "Tests", () {}),
                      menuTile(Icons.show_chart, "Progress", () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      //  NAV BAR
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB8F2FF), Color(0xFFD3F5FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            bottomNavItem(Icons.home, "Home", 0, () {}),
            bottomNavItem(Icons.menu_book, "Subjects", 1,
                    () => Navigator.pushNamed(context, "/subjects")),
            bottomNavItem(Icons.edit_document, "Tests", 2, () {}),
            bottomNavItem(Icons.person, "Profile", 3,
                    () => Navigator.pushNamed(context, "/profile")),
          ],
        ),
      ),
    );
  }

  // 🔹 GRID TILE
  Widget menuTile(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFAEEBFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 65, color: const Color(0xFF081062)),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF081062))),
          ],
        ),
      ),
    );
  }

  // 🔹 BOTTOM NAV ITEM
  Widget bottomNavItem(
      IconData icon, String label, int index, VoidCallback onTap) {
    bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = index);
        onTap();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 30,
              color: isSelected ? Colors.blueAccent : const Color(0xFF081062)),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : const Color(0xFF081062),
            ),
          ),
        ],
      ),
    );
  }
}
