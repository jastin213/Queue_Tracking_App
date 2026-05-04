import 'package:flutter/material.dart';
import 'admin_login.dart';
import 'track_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 222, 240, 247),
      body: SafeArea(
        child: Stack(
          children: [
            // Title (top-left)
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

            // Center Card
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
                    // Main deep shadow (bottom)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),

                    // Soft ambient shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),

                    // Light top highlight (illusion effect)
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
                    // Icon with soft elevated background
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
                      child: const Icon(Icons.directions_car, size: 40),
                    ),

                    const SizedBox(height: 30),

                    // Admin Login (black button)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8, // adds depth
                          shadowColor: Colors.black.withOpacity(0.4),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminLogin(),
                            ),
                          );
                        },
                        child: const Text("Admin Login"),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Track Queue (outlined button)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(color: Colors.black54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TrackPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Track My Queue",
                          style: TextStyle(color: Colors.black),
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