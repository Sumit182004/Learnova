import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController     = TextEditingController();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey           = GlobalKey<FormState>();

  String selectedClass = "class10"; // FIX: lowercase, no space
  bool isLoading       = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ── register ───────────────────────────────────────────────────────────────
  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      UserCredential userCred =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .set({
        "name"     : nameController.text.trim(),
        "email"    : emailController.text.trim(),
        "standard" : selectedClass,  // saves "class10" or "class12"
        "role"     : "student",
        "createdAt": FieldValue.serverTimestamp(),
        "photoUrl" : "",
      });

      // FIX: go directly to home after signup — no need to login again
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  // ── friendly errors ────────────────────────────────────────────────────────
  String _friendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains("email-already-in-use")) return "Email already registered";
    if (msg.contains("weak-password"))        return "Password is too weak";
    if (msg.contains("invalid-email"))        return "Invalid email format";
    if (msg.contains("network-request-failed")) return "No internet connection";
    return "Signup failed. Please try again";
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width:  double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8BEAFB), Color(0xFF081062)],
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [

                    // ── logo ────────────────────────────────────────────────
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.18,
                      child: Image.asset("assets/logo.png"),
                    ),

                    const SizedBox(height: 20),

                    // ── card ────────────────────────────────────────────────
                    Container(
                      width: 330,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC9E9FF), Color(0xFF7AB8FF)],
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:       Colors.black.withOpacity(0.2),
                            blurRadius:  20,
                            spreadRadius: 2,
                            offset:      const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // title
                          const Center(
                            child: Text(
                              "Register",
                              style: TextStyle(
                                fontSize:   28,
                                fontWeight: FontWeight.bold,
                                color:      Color(0xFF081062),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── full name ──────────────────────────────────
                          const Text("Full Name",
                              style: TextStyle(fontSize: 15)),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller:         nameController,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Name cannot be empty";
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              hint: "Enter your full name",
                              icon: Icons.person,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── email ──────────────────────────────────────
                          const Text("Email",
                              style: TextStyle(fontSize: 15)),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller:   emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Email is required";
                              }
                              if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")
                                  .hasMatch(v.trim())) {
                                return "Invalid email format";
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              hint: "Enter your email",
                              icon: Icons.email,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── password ───────────────────────────────────
                          const Text("Password",
                              style: TextStyle(fontSize: 15)),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller:  passwordController,
                            obscureText: obscurePassword,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Password is required";
                              }
                              if (v.length < 6) {
                                return "Minimum 6 characters";
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              hint: "Create a password",
                              icon: Icons.lock,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                        () => obscurePassword = !obscurePassword),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── standard ───────────────────────────────────
                          const Text("Select Standard",
                              style: TextStyle(fontSize: 15)),
                          const SizedBox(height: 5),

                          // FIX: value="class10", label="Class 10"
                          // these must be different — value is what gets saved,
                          // label is what student sees
                          DropdownButtonFormField<String>(
                            value: selectedClass,
                            items: const [
                              DropdownMenuItem(value: "class10", child: Text("Class 10")),
                              DropdownMenuItem(value: "class12", child: Text("Class 12")),
                            ],
                            onChanged: (v) =>
                                setState(() => selectedClass = v!),
                            decoration: InputDecoration(
                              filled:    true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── signup button ──────────────────────────────
                          Center(
                            child: Container(
                              width: 200,
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
                                onPressed: isLoading ? null : registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor:     Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(35),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  child: isLoading
                                      ? const SizedBox(
                                    height: 20,
                                    width:  20,
                                    child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Text(
                                    "Sign Up",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color:    Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── go to login ────────────────────────────────
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Already have an account? Login",
                                style: TextStyle(color: Color(0xFF081062)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── input decoration helper ────────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      filled:     true,
      fillColor:  Colors.white,
      prefixIcon: Icon(icon),
      hintText:   hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF081062), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}