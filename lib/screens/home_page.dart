import 'package:flutter/material.dart';
import 'admin_login.dart';
import 'customer_login.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 222, 240, 247),

      body: SafeArea(
        child: Stack(
          children: [
            // TITLE
            const Positioned(
              top: 20,
              left: 20,
              child: Text(
                "NPJN Smart Queue",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),

            // CENTER CARD
            Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),

                  borderRadius: BorderRadius.circular(30),

                  boxShadow: [
                    // MAIN SHADOW
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),

                    // SOFT SHADOW
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),

                    // LIGHT EFFECT
                    BoxShadow(
                      color: Colors.white.withOpacity(0.7),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ICON
                    Container(
                      padding: const EdgeInsets.all(18),

                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,

                        borderRadius: BorderRadius.circular(20),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0),
                            blurRadius: 10,
                          ),

                          BoxShadow(
                            color: Colors.white.withOpacity(0.7),
                            blurRadius: 10,
                          ),
                        ],
                      ),

                      child: const Icon(
                        Icons.directions_car,
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ================= ADMIN LOGIN =================

                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30),
                          ),

                          elevation: 8,

                          shadowColor:
                              Colors.black.withOpacity(0.4),
                        ),

                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminLogin(),
                            ),
                          );
                        },

                        child: const Text("Admin Login"),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ================= CUSTOMER PORTAL =================

                    SizedBox(
                      width: double.infinity,

                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),

                          side: const BorderSide(
                            color: Colors.black54,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30),
                          ),
                        ),

                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CustomerLogin(),
                            ),
                          );
                        },

                        child: const Text(
                          "Customer Portal",
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}