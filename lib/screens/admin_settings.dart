import 'package:flutter/material.dart';

// ================= ADMIN SETTINGS GLOBALS =================

ValueNotifier<String> voiceLanguageNotifier = ValueNotifier("English");
ValueNotifier<String> appLanguageNotifier = ValueNotifier("English");

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),
      appBar: AppBar(
        title: const Text("Admin Settings"),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            settingsCard(
              title: "Voice Message Language",
              subtitle: "Choose the language used when calling queue numbers.",
              child: ValueListenableBuilder<String>(
                valueListenable: voiceLanguageNotifier,
                builder: (context, value, _) {
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "English",
                        child: Text("English"),
                      ),
                      DropdownMenuItem(
                        value: "Filipino",
                        child: Text("Filipino"),
                      ),
                    ],
                    onChanged: (newValue) {
                      voiceLanguageNotifier.value = newValue!;
                      setState(() {});
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            settingsCard(
              title: "App Language Preference",
              subtitle: "Choose preferred admin interface language.",
              child: ValueListenableBuilder<String>(
                valueListenable: appLanguageNotifier,
                builder: (context, value, _) {
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "English",
                        child: Text("English"),
                      ),
                      DropdownMenuItem(
                        value: "Filipino",
                        child: Text("Filipino"),
                      ),
                    ],
                    onChanged: (newValue) {
                      appLanguageNotifier.value = newValue!;
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget settingsCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}