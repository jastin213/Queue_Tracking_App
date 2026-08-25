import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'customer_register.dart';
import 'customer_home.dart';
import 'admin_page.dart';
import 'track_page.dart';

const Color _backgroundColor = AppColors.background;
const Color _primaryColor = AppColors.primary;
const Color _cardColor = AppColors.surface;
const Color _borderColor = AppColors.border;
const Color _mutedTextColor = AppColors.mutedText;

class CustomerLogin extends StatefulWidget {
  const CustomerLogin({super.key});

  @override
  State<CustomerLogin> createState() => _CustomerLoginState();
}

class _CustomerLoginState extends State<CustomerLogin> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isSendingPasswordReset = false;
  bool obscurePassword = true;

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

  String getPasswordResetErrorMessage(FirebaseAuthException e) {
    if (e.code == "invalid-email") {
      return "Please enter a valid email address.";
    }

    if (e.code == "user-not-found") {
      return "No account was found for that email address.";
    }

    if (e.code == "too-many-requests") {
      return "Too many attempts. Please wait before trying again.";
    }

    if (e.code == "network-request-failed") {
      return "Network error. Please check your internet connection.";
    }

    return e.message ?? "Unable to send the password reset email.";
  }

  Future<void> resetPassword() async {
    String resetEmailValue = emailController.text.trim();
    final formKey = GlobalKey<FormState>();

    final String? resetEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.lock_reset_rounded,
            color: _primaryColor,
            size: 36,
          ),
          title: const Text("Reset Password"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter your registered email. We will send a secure link where you can create a new password.",
                  style: TextStyle(height: 1.4, color: _mutedTextColor),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  initialValue: resetEmailValue,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? "";

                    if (email.isEmpty ||
                        !RegExp(
                          r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
                        ).hasMatch(email)) {
                      return "Enter a valid email address";
                    }

                    return null;
                  },
                  onChanged: (value) {
                    resetEmailValue = value.trim();
                  },
                  onFieldSubmitted: (value) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(dialogContext, value.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("CANCEL"),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, resetEmailValue);
                }
              },
              child: const Text("SEND RESET LINK"),
            ),
          ],
        );
      },
    );

    if (resetEmail == null || !mounted) return;

    setState(() {
      isSendingPasswordReset = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: resetEmail);

      if (!mounted) return;

      emailController.text = resetEmail;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password reset email sent. Open the link to create a new password.",
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getPasswordResetErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() {
          isSendingPasswordReset = false;
        });
      }
    }
  }

  Future<void> login() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter credentials")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

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

      if (!userDoc.exists || userDoc.data() == null) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account profile not found. Please contact support."),
          ),
        );
        return;
      }

      final data = userDoc.data()!;
      final String role = (data["role"] ?? "").toString().trim().toLowerCase();

      if (!mounted) return;

      if (role == "admin") {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "lastLoginAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPage()),
        );
        return;
      }

      if (role == "customer" || role == "user") {
        loggedInCustomerNameNotifier.value =
            (data["fullName"] ?? user.displayName ?? "").toString();
        loggedInCustomerEmailNotifier.value =
            (data["email"] ?? user.email ?? email).toString();
        loggedInCustomerIdNotifier.value = user.uid;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHome()),
        );
        return;
      }

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access denied. This account has no valid role."),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFirebaseErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
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
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryColor),
      suffixIcon: suffixIcon,
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
            shadowColor: _primaryColor.withValues(alpha: 0.18),
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
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(overscroll: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
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
                            color: _primaryColor.withValues(alpha: 0.16),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_circle_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      "Account Login",
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
                      "Continue as a walk-in, or use your registered account.",
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
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.16),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.directions_walk_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Walk-In Customer",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Get your queue number at the center, then track your position here without an account.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: isLoading || isSendingPasswordReset
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TrackPage(),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.search_rounded),
                              label: const Text(
                                "CONTINUE AS WALK-IN",
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          child: Divider(color: _borderColor),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "ACCOUNT",
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontSize: 12,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Divider(color: _borderColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

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
                            color: _primaryColor.withValues(alpha: 0.08),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Login or Create Account",
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
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
                            obscureText: obscurePassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            style: const TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: formDecoration(
                              label: "Password",
                              hint: "Enter your password",
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? "Show password"
                                    : "Hide password",
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          obscurePassword = !obscurePassword;
                                        });
                                      },
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLoading || isSendingPasswordReset
                                  ? null
                                  : resetPassword,
                              child: Text(
                                isSendingPasswordReset
                                    ? "Sending reset link..."
                                    : "Forgot Password?",
                                style: const TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: isLoading || isSendingPasswordReset
                                  ? null
                                  : login,
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

                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
      ),
    );
  }
}
