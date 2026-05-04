import 'package:flutter/material.dart';
import 'admin_page.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    String nowServing = currentServingNumber == 0
        ? "-"
        : "A$currentServingNumber";

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: SafeArea(
        // The Center widget ensures the Column stays in the middle horizontally
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              // This aligns the content vertically in the middle
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "NPJN EMISSION CENTER",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 60), // Fixed gap

                Text(
                  "NOW SERVING",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 22,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w300,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  nowServing,
                  style: const TextStyle(
                    color: Color(0xFFFF4500),
                    fontSize: 160,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),

                const SizedBox(height: 60), // Fixed gap

                const Text(
                  "NEXT IN LINE",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                // Wrap naturally aligns center with alignment property
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: globalQueue.map((q) {
                    return Container(
                      width: 80,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        q,
                        style: const TextStyle(
                          color: Color(0xFF0A0E14),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 60), // Fixed gap

                const Text(
                  "Please prepare. Stay alert for your turn.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
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