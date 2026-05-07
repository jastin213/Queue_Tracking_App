import 'package:flutter/material.dart';

class CustomerRegister extends StatefulWidget {
  const CustomerRegister({super.key});

  @override
  State<CustomerRegister> createState() =>
      _CustomerRegisterState();
}

class _CustomerRegisterState
    extends State<CustomerRegister> {
  final TextEditingController fullNameController =
      TextEditingController();

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

  final TextEditingController passwordController =
      TextEditingController();

  void register() {
    if (fullNameController.text.isEmpty ||
        addressList.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complete all fields"),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Account Created Successfully",
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
  value: selectedAddress,

  decoration: InputDecoration(
    labelText: "Municipality",
    border: OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(12),
    ),
  ),

  items: addressList.map((address) {
    return DropdownMenuItem(
      value: address,
      child: Text(address),
    );
  }).toList(),

  onChanged: (value) {
    setState(() {
      selectedAddress = value!;
    });
  },
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

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: register,
                child: const Text(
                  "CREATE ACCOUNT",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}