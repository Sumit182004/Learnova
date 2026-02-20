import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;

  Future<void> loginUser() async {
    try {
      UserCredential cred =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      final role = userDoc["role"];

      if (role == "admin") {
        Navigator.pushReplacementNamed(context, "/admin");
      } else {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login failed: $e")));
    }
  }

  Future<UserCredential?> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication googleAuth =
      await googleUser!.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential cred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final uid = cred.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      final role = userDoc["role"];

      if (role == "admin") {
        Navigator.pushReplacementNamed(context, "/admin");
      } else {
        Navigator.pushReplacementNamed(context, "/home");
      }

      return cred;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Google Login failed: $e")));
      return null;
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
              Color(0xFF8BEAFB), // Sky blue
              Color(0xFF081062), // Navy blue
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [

                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.25,
                    child: Image.asset("assets/logo.png"),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: 330,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFC9E9FF),
                          Color(0xFF7AB8FF),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 3,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const Center(
                          child: Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF081062),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // EMAIL FIELD
                        const Text("Email", style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email),
                            hintText: "Enter your email",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),


                        const Text("Password", style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock),
                            hintText: "Enter your password",
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text("Forgot Password?"),
                          ),
                        ),

                        const SizedBox(height: 10),


                        Center(
                          child: Container(
                            width: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(35),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF081062),
                                  Color(0xFF1433A1),
                                ],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(35)),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  "Login",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text("Login with Google"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              final user = await loginWithGoogle();
                              if (user != null) {
                                Navigator.pushReplacementNamed(
                                    context, "/home");
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, "/signup");
                            },
                            child: const Text("Don't have an account? Register"),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
