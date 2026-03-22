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
  bool isLoading = false; // FIX: loading state added

  // ── navigate based on role ─────────────────────────────────────────────────
  void _navigateByRole(String role) {
    if (role == "admin") {
      Navigator.pushReplacementNamed(context, "/admin");
    } else {
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  // ── email login ────────────────────────────────────────────────────────────
  Future<void> loginUser() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => isLoading = true);

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

      if (!userDoc.exists) {
        // FIX: doc might not exist
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User record not found. Contact support.")),
        );
        return;
      }

      final role = userDoc["role"] ?? "student";
      _navigateByRole(role);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${_friendlyError(e)}")),
      );
    }
  }

  // ── google login ───────────────────────────────────────────────────────────
  Future<void> loginWithGoogle() async {
    setState(() => isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // user cancelled
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential cred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final uid = cred.user!.uid;
      final userRef =
      FirebaseFirestore.instance.collection("users").doc(uid);
      final userDoc = await userRef.get();

      // FIX: create Firestore doc for new Google users
      if (!userDoc.exists) {
        await userRef.set({
          "name": cred.user!.displayName ?? "Student",
          "email": cred.user!.email ?? "",
          "role": "student",
          "standard": "class10", // default — they can change in profile
          "createdAt": FieldValue.serverTimestamp(),
          "photoUrl": cred.user!.photoURL ?? "",
        });
        // new user — go home (no admin role possible via Google)
        Navigator.pushReplacementNamed(context, "/home");
        return;
      }

      final role = userDoc["role"] ?? "student";
      // FIX: removed duplicate navigation — only navigate here, not in onPressed
      _navigateByRole(role);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google login failed: ${_friendlyError(e)}")),
      );
    }
  }

  // ── forgot password ────────────────────────────────────────────────────────
  Future<void> forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email above first")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${_friendlyError(e)}")),
      );
    }
  }

  // ── friendly error messages ────────────────────────────────────────────────
  String _friendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains("user-not-found")) return "No account found with this email";
    if (msg.contains("wrong-password")) return "Incorrect password";
    if (msg.contains("invalid-email")) return "Invalid email format";
    if (msg.contains("too-many-requests")) return "Too many attempts. Try later";
    if (msg.contains("network-request-failed")) return "No internet connection";
    return "Something went wrong. Try again";
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
                        colors: [Color(0xFFC9E9FF), Color(0xFF7AB8FF)],
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

                        const Text("Email", style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
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
                              icon: Icon(obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                      () => obscurePassword = !obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // FIX: forgot password now works
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: forgotPassword,
                            child: const Text("Forgot Password?"),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // FIX: loading indicator on button
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
                              onPressed: isLoading ? null : loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(35)),
                              ),
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                child: isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  "Login",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // FIX: onPressed no longer navigates — loginWithGoogle handles it
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
                            onPressed: isLoading ? null : loginWithGoogle,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Center(
                          child: TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, "/signup"),
                            child: const Text(
                                "Don't have an account? Register"),
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