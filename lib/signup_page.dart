import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String selectedClass = "Class 10";

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      UserCredential userCred =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "standard": selectedClass,
        "role": "student",
        "createdAt": DateTime.now(),
      });

      Navigator.pushReplacementNamed(context, "/login");

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Signup failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8BEAFB), Color(0xFF081062)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey, // ⭐ FORM FOR VALIDATION
                child: Column(
                  children: [
                    // LOGO
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.20,
                      child: Image.asset("assets/logo.png"),
                    ),

                    const SizedBox(height: 20),

                    // CARD
                    Container(
                      width: 330,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC9E9FF), Color(0xFF7AB8FF)],
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          const Text("Full Name", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 5),

                          TextFormField(
                            controller: nameController,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Name cannot be empty";
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.person),
                              hintText: "Enter your full name",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // EMAIL FIELD
                          const Text("Email", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 5),

                          TextFormField(
                            controller: emailController,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Email is required";
                              }
                              if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")
                                  .hasMatch(value.trim())) {
                                return "Invalid email format";
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.email),
                              hintText: "Enter your email address",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // PASSWORD FIELD
                          const Text("Password", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 5),

                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Password is required";
                              }
                              if (value.length < 6) {
                                return "Password must be at least 6 characters";
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.lock),
                              hintText: "Create a password",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // STANDARD
                          const Text("Select Standard",
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 5),

                          DropdownButtonFormField(
                            value: selectedClass,
                            items: ["Class 10", "Class 12"]
                                .map((cls) =>
                                DropdownMenuItem(value: cls, child: Text(cls)))
                                .toList(),
                            onChanged: (value) => setState(() {
                              selectedClass = value!;
                            }),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          Center(
                            child: Container(
                              width: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF081062), Color(0xFF1433A1)],
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    "Sign Up",
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          // GO TO LOGIN
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Already have an account? Login"),
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
        ),
      ),
    );
  }
}
