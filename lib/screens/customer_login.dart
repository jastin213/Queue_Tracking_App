import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'customer_register.dart';
import 'customer_home.dart';

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

class CustomerLogin extends StatefulWidget {
  const CustomerLogin({super.key});

  @override
  State<CustomerLogin> createState() => _CustomerLoginState();
}

class _CustomerLoginState extends State<CustomerLogin> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String getFirebaseErrorMessage(FirebaseAuthException e) {
    if (e.code == "user-not-found") {
      return "Account not found. Please create an account first.";
    }

    if (e.code == "wrong-password") {
      return "Incorrect password.";
    }

    if (e.code == "invalid-email") {
      return "Please enter a valid email address.";
    }

    if (e.code == "invalid-credential") {
      return "Invalid email or password.";
    }

    if (e.code == "network-request-failed") {
      return "Network error. Please check your internet connection.";
    }

    return e.message ?? "Login failed.";
  }

  Future<void> login() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter credentials")),
      );
      return;
    }

    setState(() {
      isLoading = true;
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
          message: "Account not found.",
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;

        loggedInCustomerNameNotifier.value =
            (data["fullName"] ?? user.displayName ?? "").toString();

        loggedInCustomerEmailNotifier.value =
            (data["email"] ?? user.email ?? email).toString();

        loggedInCustomerIdNotifier.value = user.uid;
      } else {
        loggedInCustomerNameNotifier.value = user.displayName ?? "";
        loggedInCustomerEmailNotifier.value = user.email ?? email;
        loggedInCustomerIdNotifier.value = user.uid;

        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "fullName": user.displayName ?? "",
          "email": user.email ?? email,
          "municipality": "",
          "role": "customer",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHome()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFirebaseErrorMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration formDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryColor),
      labelStyle: const TextStyle(
        color: _mutedTextColor,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: _mutedTextColor),
      filled: true,
      fillColor: _backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: _primaryColor.withOpacity(0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  Container(
                    height: 92,
                    width: 92,
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
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    "Customer Portal",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Sign in to book appointments and track your queue.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: _mutedTextColor,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.08),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                                Icons.login_rounded,
                                color: _primaryColor,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Enter your registered email and password.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    color: _mutedTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: formDecoration(
                            label: "Email",
                            hint: "Enter your email address",
                            icon: Icons.email_outlined,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          style: const TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: formDecoration(
                            label: "Password",
                            hint: "Enter your password",
                            icon: Icons.lock_outline_rounded,
                          ),
                        ),

                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : login,
                            child: isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("LOGIN"),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "No account yet?",
                              style: TextStyle(
                                color: _mutedTextColor,
                                fontSize: 13.5,
                              ),
                            ),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CustomerRegister(),
                                        ),
                                      );
                                    },
                              child: const Text(
                                "Create Account",
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "Queue · Appointment · Tracking",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontSize: 13.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}