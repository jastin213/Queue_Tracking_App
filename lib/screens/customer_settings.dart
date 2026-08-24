import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'customer_register.dart';

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);

ValueNotifier<bool> customerVoiceAlertsEnabledNotifier = ValueNotifier(true);

class CustomerSettings extends StatefulWidget {
  const CustomerSettings({super.key});

  @override
  State<CustomerSettings> createState() => _CustomerSettingsState();
}

class _CustomerSettingsState extends State<CustomerSettings> {
  final FlutterTts flutterTts = FlutterTts();
  bool isTestingVoice = false;

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> testVoiceAlert() async {
    if (isTestingVoice || !customerVoiceAlertsEnabledNotifier.value) return;

    setState(() {
      isTestingVoice = true;
    });

    try {
      await flutterTts.stop();
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setPitch(1.0);
      await flutterTts.speak("Please prepare. Your turn is near.");
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Voice playback is unavailable on this device."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isTestingVoice = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String customerName = loggedInCustomerNameNotifier.value.trim();
    final String customerEmail = loggedInCustomerEmailNotifier.value.trim();

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: _backgroundColor,
          foregroundColor: _primaryColor,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: _primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text("Customer Settings")),
        body: SafeArea(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _SettingsCard(
                  title: "Queue Alert Settings",
                  icon: Icons.volume_up_rounded,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: customerVoiceAlertsEnabledNotifier,
                    builder: (context, enabled, _) {
                      return Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              "Voice queue alerts",
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: const Text(
                              "Say “Please prepare. Your turn is near” when your tracked queue is within five positions.",
                              style: TextStyle(
                                color: _mutedTextColor,
                                height: 1.35,
                              ),
                            ),
                            value: enabled,
                            activeThumbColor: _primaryColor,
                            onChanged: (value) {
                              customerVoiceAlertsEnabledNotifier.value = value;
                              if (!value) {
                                flutterTts.stop();
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: enabled && !isTestingVoice
                                  ? testVoiceAlert
                                  : null,
                              icon: isTestingVoice
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                isTestingVoice
                                    ? "Playing voice alert..."
                                    : "Test voice alert",
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryColor,
                                side: const BorderSide(color: _primaryColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: "Account",
                  icon: Icons.person_outline_rounded,
                  child: Column(
                    children: [
                      _AccountRow(
                        label: "Name",
                        value: customerName.isEmpty ? "Customer" : customerName,
                      ),
                      const Divider(height: 24, color: _borderColor),
                      _AccountRow(
                        label: "Email",
                        value: customerEmail.isNotEmpty
                            ? customerEmail
                            : (user?.email ?? "Not available"),
                      ),
                    ],
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              color: _mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
