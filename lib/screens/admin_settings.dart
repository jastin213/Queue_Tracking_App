import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ============================================================================
// THEME COLORS
// ============================================================================

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

// ============================================================================
// ADMIN SETTINGS GLOBAL NOTIFIERS
// ============================================================================

// Existing settings
ValueNotifier<String> voiceLanguageNotifier = ValueNotifier("English");
ValueNotifier<String> appLanguageNotifier = ValueNotifier("English");

// New settings
ValueNotifier<String> voiceSpeedNotifier = ValueNotifier("Normal");
ValueNotifier<bool> requireResetConfirmationNotifier = ValueNotifier(true);
ValueNotifier<int> dailyQueueLimitNotifier = ValueNotifier(80);

ValueNotifier<String> displayAnnouncementNotifier = ValueNotifier(
  "Please wait for your queue number to be called.",
);

ValueNotifier<bool> showCustomerNameNotifier = ValueNotifier(true);
ValueNotifier<bool> showVehicleTypeNotifier = ValueNotifier(true);
ValueNotifier<bool> showEstimatedWaitingTimeNotifier = ValueNotifier(true);
ValueNotifier<bool> autoApproveAppointmentsNotifier = ValueNotifier(false);

// ============================================================================
// ADMIN SETTINGS PAGE
// ============================================================================

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController announcementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    announcementController.text = displayAnnouncementNotifier.value;
  }

  @override
  void dispose() {
    announcementController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // VOICE FUNCTIONS
  // ==========================================================================

  double getSpeechRate() {
    if (voiceSpeedNotifier.value == "Slow") return 0.35;
    if (voiceSpeedNotifier.value == "Fast") return 0.60;
    return 0.45;
  }

  Future<void> testVoice() async {
    if (voiceLanguageNotifier.value == "Filipino") {
      await flutterTts.setLanguage("fil-PH");
      await flutterTts.setSpeechRate(getSpeechRate());
      await flutterTts.setPitch(1.0);

      await flutterTts.speak(
        "Tinatawag ang numero G001, pumunta na po sa testing area",
      );
    } else {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(getSpeechRate());
      await flutterTts.setPitch(1.0);

      await flutterTts.speak(
        "Now serving G001, please proceed to the testing area",
      );
    }
  }

  // ==========================================================================
  // SAVE FUNCTIONS
  // ==========================================================================

  void saveAnnouncement() {
    displayAnnouncementNotifier.value = announcementController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Display announcement saved.")),
    );

    setState(() {});
  }

  void updateQueueLimit(int value) {
    dailyQueueLimitNotifier.value = value;
    setState(() {});
  }

  // ==========================================================================
  // INPUT STYLE
  // ==========================================================================

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _mutedTextColor),
      filled: true,
      fillColor: _backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      shadowColor: _primaryColor.withOpacity(0.16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }

  // ==========================================================================
  // BUILD PAGE
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _primaryColor,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _backgroundColor,
          foregroundColor: _primaryColor,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text("Admin Settings")),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wideWeb = constraints.maxWidth >= 900;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  wideWeb ? 24 : 16,
                  10,
                  wideWeb ? 24 : 16,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wideWeb ? 900 : double.infinity,
                    ),
                    child: buildOneLineSettingsLayout(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // RESPONSIVE LAYOUT
  // ==========================================================================

  Widget buildOneLineSettingsLayout() {
    return Column(
      children: [
        buildVoiceSettings(),
        const SizedBox(height: 16),
        buildAppLanguageSettings(),
        const SizedBox(height: 16),
        buildQueueSettings(),
        const SizedBox(height: 16),
        buildDisplaySettings(),
        const SizedBox(height: 16),
        buildAppointmentSettings(),
        const SizedBox(height: 16),
        buildAdminReminders(),
      ],
    );
  }

  // ==========================================================================
  // SECTION: VOICE SETTINGS
  // ==========================================================================

  Widget buildVoiceSettings() {
    return settingsCard(
      icon: Icons.record_voice_over_rounded,
      title: "Voice Settings",
      subtitle: "Control the queue calling voice.",
      child: Column(
        children: [
          settingLabel("Voice Language"),
          ValueListenableBuilder<String>(
            valueListenable: voiceLanguageNotifier,
            builder: (context, value, _) {
              return DropdownButtonFormField<String>(
                value: value,
                dropdownColor: _cardColor,
                decoration: inputDecoration("Select voice language"),
                iconEnabledColor: _primaryColor,
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                ),
                items: const [
                  DropdownMenuItem(value: "English", child: Text("English")),
                  DropdownMenuItem(value: "Filipino", child: Text("Filipino")),
                ],
                onChanged: (newValue) {
                  voiceLanguageNotifier.value = newValue!;
                  setState(() {});
                },
              );
            },
          ),
          const SizedBox(height: 14),
          settingLabel("Voice Speed"),
          ValueListenableBuilder<String>(
            valueListenable: voiceSpeedNotifier,
            builder: (context, value, _) {
              return DropdownButtonFormField<String>(
                value: value,
                dropdownColor: _cardColor,
                decoration: inputDecoration("Select voice speed"),
                iconEnabledColor: _primaryColor,
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                ),
                items: const [
                  DropdownMenuItem(value: "Slow", child: Text("Slow")),
                  DropdownMenuItem(value: "Normal", child: Text("Normal")),
                  DropdownMenuItem(value: "Fast", child: Text("Fast")),
                ],
                onChanged: (newValue) {
                  voiceSpeedNotifier.value = newValue!;
                  setState(() {});
                },
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: primaryButtonStyle(),
              onPressed: testVoice,
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text("TEST VOICE"),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION: APP LANGUAGE SETTINGS
  // ==========================================================================

  Widget buildAppLanguageSettings() {
    return settingsCard(
      icon: Icons.language_rounded,
      title: "App Language",
      subtitle: "Choose the admin interface language.",
      child: ValueListenableBuilder<String>(
        valueListenable: appLanguageNotifier,
        builder: (context, value, _) {
          return DropdownButtonFormField<String>(
            value: value,
            dropdownColor: _cardColor,
            decoration: inputDecoration("Select app language"),
            iconEnabledColor: _primaryColor,
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w700,
            ),
            items: const [
              DropdownMenuItem(value: "English", child: Text("English")),
              DropdownMenuItem(value: "Filipino", child: Text("Filipino")),
            ],
            onChanged: (newValue) {
              appLanguageNotifier.value = newValue!;
              setState(() {});
            },
          );
        },
      ),
    );
  }

  // ==========================================================================
  // SECTION: QUEUE SETTINGS
  // ==========================================================================

  Widget buildQueueSettings() {
    return settingsCard(
      icon: Icons.confirmation_number_rounded,
      title: "Queue Settings",
      subtitle: "Manage daily queue safety and limits.",
      child: Column(
        children: [
          settingTile(
            icon: Icons.restart_alt_rounded,
            title: "Confirm Before Daily Reset",
            subtitle: "Prevents accidental queue reset.",
            trailing: ValueListenableBuilder<bool>(
              valueListenable: requireResetConfirmationNotifier,
              builder: (context, value, _) {
                return Switch(
                  value: value,
                  activeColor: _primaryColor,
                  onChanged: (newValue) {
                    requireResetConfirmationNotifier.value = newValue;
                    setState(() {});
                  },
                );
              },
            ),
          ),
          const Divider(color: _borderColor),
          settingLabel("Daily Queue Limit"),
          ValueListenableBuilder<int>(
            valueListenable: dailyQueueLimitNotifier,
            builder: (context, value, _) {
              return Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value.toDouble(),
                      min: 20,
                      max: 150,
                      divisions: 13,
                      activeColor: _primaryColor,
                      inactiveColor: _borderColor,
                      label: value.toString(),
                      onChanged: (newValue) {
                        updateQueueLimit(newValue.round());
                      },
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _softPrimaryColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      "$value",
                      style: const TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION: DISPLAY SETTINGS
  // ==========================================================================

  Widget buildDisplaySettings() {
    return settingsCard(
      icon: Icons.tv_rounded,
      title: "Display Settings",
      subtitle: "Control what appears on the customer display.",
      child: Column(
        children: [
          settingTile(
            icon: Icons.person_outline_rounded,
            title: "Show Customer Name",
            subtitle: "Display customer name on screen.",
            trailing: ValueListenableBuilder<bool>(
              valueListenable: showCustomerNameNotifier,
              builder: (context, value, _) {
                return Switch(
                  value: value,
                  activeColor: _primaryColor,
                  onChanged: (newValue) {
                    showCustomerNameNotifier.value = newValue;
                    setState(() {});
                  },
                );
              },
            ),
          ),
          const Divider(color: _borderColor),
          settingTile(
            icon: Icons.directions_car_rounded,
            title: "Show Vehicle Type",
            subtitle: "Display Gas or Diesel label.",
            trailing: ValueListenableBuilder<bool>(
              valueListenable: showVehicleTypeNotifier,
              builder: (context, value, _) {
                return Switch(
                  value: value,
                  activeColor: _primaryColor,
                  onChanged: (newValue) {
                    showVehicleTypeNotifier.value = newValue;
                    setState(() {});
                  },
                );
              },
            ),
          ),
          const Divider(color: _borderColor),
          settingTile(
            icon: Icons.timer_outlined,
            title: "Show Estimated Waiting Time",
            subtitle: "Display estimated waiting time if available.",
            trailing: ValueListenableBuilder<bool>(
              valueListenable: showEstimatedWaitingTimeNotifier,
              builder: (context, value, _) {
                return Switch(
                  value: value,
                  activeColor: _primaryColor,
                  onChanged: (newValue) {
                    showEstimatedWaitingTimeNotifier.value = newValue;
                    setState(() {});
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          settingLabel("Display Announcement"),
          TextField(
            controller: announcementController,
            maxLines: 3,
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w600,
            ),
            decoration: inputDecoration("Enter display announcement"),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: primaryButtonStyle(),
              onPressed: saveAnnouncement,
              icon: const Icon(Icons.save_rounded),
              label: const Text("SAVE ANNOUNCEMENT"),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION: APPOINTMENT SETTINGS
  // ==========================================================================

  Widget buildAppointmentSettings() {
    return settingsCard(
      icon: Icons.event_available_rounded,
      title: "Appointment Settings",
      subtitle: "Control how online appointments are handled.",
      child: settingTile(
        icon: Icons.auto_mode_rounded,
        title: "Auto-Approve Appointments",
        subtitle: "Recommended OFF for document checking.",
        trailing: ValueListenableBuilder<bool>(
          valueListenable: autoApproveAppointmentsNotifier,
          builder: (context, value, _) {
            return Switch(
              value: value,
              activeColor: _primaryColor,
              onChanged: (newValue) {
                autoApproveAppointmentsNotifier.value = newValue;
                setState(() {});
              },
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // SECTION: ADMIN REMINDERS
  // ==========================================================================

  Widget buildAdminReminders() {
    return settingsCard(
      icon: Icons.info_outline_rounded,
      title: "Admin Reminders",
      subtitle: "Quick guide for daily operation.",
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReminderText("Check pending appointments daily."),
          SizedBox(height: 8),
          ReminderText("Review uploaded documents before approval."),
          SizedBox(height: 8),
          ReminderText("Reset the queue only after the operating day."),
          SizedBox(height: 8),
          ReminderText("Use Test Voice before calling customers."),
        ],
      ),
    );
  }

  // ==========================================================================
  // REUSABLE WIDGETS
  // ==========================================================================

  Widget settingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: _primaryColor.withOpacity(0.06), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _softPrimaryColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Icon(icon, color: _primaryColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _mutedTextColor,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }

  Widget settingLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget iconBox(IconData icon) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

// ============================================================================
// REMINDER TEXT WIDGET
// ============================================================================

class ReminderText extends StatelessWidget {
  final String text;

  const ReminderText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: _primaryColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _mutedTextColor,
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}