import 'package:flutter/material.dart';
import 'admin_page.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  final String adminUser = "admin";
  final String adminPass = "1234";

  void login() {
    if (_username.text == adminUser && _password.text == adminPass) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Admin Credentials")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: const Text("Login")),
          ],
        ),
      ),
    );
  }
}