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
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            const Text(
              "NPJN EMISSION CENTER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 50),

            const Text(
              "NOW SERVING",
              style: TextStyle(color: Colors.white70, fontSize: 24),
            ),

            const SizedBox(height: 20),

            Text(
              nowServing,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 90,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              "NEXT IN LINE",
              style: TextStyle(color: Colors.white70, fontSize: 20),
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 20,
              children: globalQueue.take(5).map((q) {
                return Chip(
                  label: Text(q, style: const TextStyle(fontSize: 20)),
                );
              }).toList(),
            ),

            const Spacer(),

            const Text(
              "Please prepare. Stay alert for your turn.",
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}