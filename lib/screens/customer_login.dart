import 'package:flutter/material.dart';
import 'customer_register.dart';
import 'customer_home.dart';

class CustomerLogin extends StatefulWidget {
  const CustomerLogin({super.key});

  @override
  State<CustomerLogin> createState() =>
      _CustomerLoginState();
}

class _CustomerLoginState
    extends State<CustomerLogin> {
  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  void login() {
    if (nameController.text.isNotEmpty &&
        passwordController.text.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CustomerHome(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter credentials"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 222, 240, 247),

      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(25),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person,
                size: 50,
              ),

              const SizedBox(height: 20),

              const Text(
                "Customer Portal",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: login,
                  child: const Text("LOGIN"),
                ),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () {
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}