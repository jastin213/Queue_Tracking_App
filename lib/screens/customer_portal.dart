import 'package:flutter/material.dart';
import 'track_page.dart';
import 'customer_login.dart';

class CustomerPortal extends StatelessWidget {
  const CustomerPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 222, 240, 247),
      body: SafeArea(
        child: Stack(
          children: [
            // Title
            const Positioned(
              top: 20,
              left: 20,
              child: Text(
                "Customer Portal",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),

            // Center Card
            Center(
              child: SingleChildScrollView(
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
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
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
                      // Icon
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
                          Icons.person_outline,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Choose Customer Option",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 25),

                      // TRACK MY QUEUE BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.4),
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text("Track My Queue"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TrackPage(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 15),

                      // LOGIN / CREATE ACCOUNT BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                            side: const BorderSide(
                              color: Colors.black54,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: const Icon(
                            Icons.calendar_month,
                            color: Colors.black,
                          ),
                          label: const Text(
                            "Login / Create Account",
                            style: TextStyle(
                              color: Colors.black,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CustomerLogin(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 15),

                      // BACK BUTTON
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Back",
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}