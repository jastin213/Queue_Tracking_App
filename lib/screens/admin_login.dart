import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_page.dart';

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String getFirebaseErrorMessage(FirebaseAuthException e) {
    if (e.code == "invalid-email") {
      return "Please enter a valid email address.";
    }

    if (e.code == "user-not-found") {
      return "Admin account not found.";
    }

    if (e.code == "wrong-password") {
      return "Incorrect password.";
    }

    if (e.code == "invalid-credential") {
      return "Invalid email or password.";
    }

    if (e.code == "network-request-failed") {
      return "Network error. Please check your internet connection.";
    }

    return e.message ?? "Admin login failed.";
  }

  Future<void> login() async {
    final String email = _email.text.trim();
    final String password = _password.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter admin email and password.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: "user-not-found",
          message: "Admin account not found.",
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get();

      if (!userDoc.exists || userDoc.data() == null) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin profile not found in Firestore."),
          ),
        );
        return;
      }

      final data = userDoc.data()!;
      final String role = (data["role"] ?? "").toString().trim().toLowerCase();

      if (role != "admin") {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Access denied. This account is not an admin."),
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set(
        {
          "lastLoginAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFirebaseErrorMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Admin login failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration inputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _mutedTextColor,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: _primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _backgroundColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryColor, width: 1.6),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _primaryColor,
            ),
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Admin Login",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 45),

                Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.16),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  "Welcome Admin",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Enter your Firebase admin account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, color: _mutedTextColor),
                ),

                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.08),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _softPrimaryColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _borderColor),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: _primaryColor,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Authorized admin access only.",
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                  color: _mutedTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: _email,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: inputStyle(
                          label: "Admin Email",
                          icon: Icons.email_rounded,
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _password,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: inputStyle(
                          label: "Password",
                          icon: Icons.lock_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: _primaryColor,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: _primaryColor.withOpacity(0.18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isLoading ? null : login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "LOGIN",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  "NPJN Emission Testing Center",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}