import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, dynamic>?> getUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return null;

    DocumentSnapshot snapshot =
    await FirebaseFirestore.instance.collection("users").doc(uid).get();

    return snapshot.data() as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // 🔹 SAME GRADIENT LIKE OTHER SCREENS
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
          child: Column(
            children: [
              // 🔹 TOP BAR (Back Arrow + Title)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      "Profile",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: getUserData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Center(
                        child: Text(
                          "User data not found!",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      );
                    }

                    final userData = snapshot.data!;
                    final name = userData["name"] ?? "Unknown";
                    final standard = userData["standard"] ?? "N/A";
                    final email = authUser?.email ?? "Unknown";

                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.person,
                              size: 110, color: Colors.white),
                          const SizedBox(height: 25),

                          // 🔹 INFO CARD
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFAEEBFF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                profileItem("Name", name),
                                profileItem("Email", email),
                                profileItem("Standard", standard),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // 🔴 LOGOUT BUTTON
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF9D0000),
                                  Color(0xFFE53935),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                Navigator.pushReplacementNamed(
                                    context, "/login");
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text(
                                "Logout",
                                style:
                                TextStyle(fontSize: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
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

  // 🔹 STYLED TEXT ROW INSIDE PROFILE CARD
  Widget profileItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        "$title: $value",
        style: const TextStyle(
          fontSize: 18,
          color: Color(0xFF081062),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
