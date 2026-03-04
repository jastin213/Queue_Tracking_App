import 'package:flutter/material.dart';
import 'admin_login.dart';
import 'track_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NPJN Smart Queue")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.car_repair, size: 100),
            const SizedBox(height: 40),
            ElevatedButton(
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrackPage(),
                  ),
                );
              },
              child: const Text("Track My Queue"),
            ),
          ],
        ),
      ),
    );
  }
}