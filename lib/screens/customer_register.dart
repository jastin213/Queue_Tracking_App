import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

// ================= CUSTOMER ACCOUNT SESSION STORAGE =================
//
// These notifiers are still kept because other pages already use them.
// The backend now uses Firebase Auth + Firestore.
// Do not remove these yet because CustomerHome and Appointment Status depend on them.

ValueNotifier<List<Map<String, String>>> registeredCustomers = ValueNotifier([]);

ValueNotifier<String> loggedInCustomerNameNotifier = ValueNotifier("");
ValueNotifier<String> loggedInCustomerEmailNotifier = ValueNotifier("");
ValueNotifier<String> loggedInCustomerIdNotifier = ValueNotifier("");

class CustomerRegister extends StatefulWidget {
  const CustomerRegister({super.key});

  @override
  State<CustomerRegister> createState() => _CustomerRegisterState();
}

class _CustomerRegisterState extends State<CustomerRegister> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  String selectedAddress = "Ligao";

  final List<String> addressList = [
    "Ligao",
    "Guinobatan",
    "Jovellar",
    "Libon",
    "Oas",
    "Pio Duran",
    "Polangui",
  ];

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String getFirebaseErrorMessage(FirebaseAuthException e) {
    if (e.code == "email-already-in-use") {
      return "This email is already registered. Please login instead.";
    }

    if (e.code == "invalid-email") {
      return "Please enter a valid email address.";
    }

    if (e.code == "weak-password") {
      return "Password is too weak. Use at least 6 characters.";
    }

    if (e.code == "network-request-failed") {
      return "Network error. Please check your internet connection.";
    }

    return e.message ?? "Account creation failed.";
  }

  Future<void> register() async {
    final String fullName = fullNameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        selectedAddress.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete all fields")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters."),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: "user-not-created",
          message: "Account was not created.",
        );
      }

      await user.updateDisplayName(fullName);

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "fullName": fullName,
        "email": email,
        "municipality": selectedAddress,
        "role": "customer",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      loggedInCustomerNameNotifier.value = fullName;
      loggedInCustomerEmailNotifier.value = email;
      loggedInCustomerIdNotifier.value = user.uid;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account Created Successfully")),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFirebaseErrorMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account creation failed: $e")),
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
        appBarTheme: const AppBarTheme(
          backgroundColor: _backgroundColor,
          foregroundColor: _primaryColor,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
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
        appBar: AppBar(title: const Text("Create Account")),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 58,
                        width: 58,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Customer Registration",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Create your customer account to book appointments and access queue tracking services.",
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: _mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Account Details",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                    letterSpacing: 0.6,
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.06),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: fullNameController,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: formDecoration(
                          label: "Full Name",
                          hint: "Enter your full name",
                          icon: Icons.person_outline_rounded,
                        ),
                      ),

                      const SizedBox(height: 16),

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

                      DropdownButtonFormField<String>(
                        value: selectedAddress,
                        decoration: formDecoration(
                          label: "Municipality",
                          hint: "Select municipality",
                          icon: Icons.location_on_outlined,
                        ),
                        dropdownColor: _cardColor,
                        iconEnabledColor: _primaryColor,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        items: addressList.map((address) {
                          return DropdownMenuItem(
                            value: address,
                            child: Text(address),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedAddress = value;
                          });
                        },
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
                    ],
                  ),
                ),

                const SizedBox(height: 18),

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
                        Icons.info_outline_rounded,
                        color: _primaryColor,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Please use a valid email address. This will be used for secure account login.",
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

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text("CREATE ACCOUNT"),
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