import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/customer_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/app_responsive_content.dart';
import '../widgets/app_section_card.dart';
import 'customer_register.dart';

export '../services/customer_preferences.dart'
    show customerVoiceAlertsEnabledNotifier;

Color get _backgroundColor => AppColors.activeBackground;
Color get _primaryColor => AppColors.activePrimary;
Color get _cardColor => AppColors.activeSurface;
Color get _borderColor => AppColors.activeBorder;
Color get _mutedTextColor => AppColors.activeMutedText;

class CustomerSettings extends StatefulWidget {
  const CustomerSettings({super.key});

  @override
  State<CustomerSettings> createState() => _CustomerSettingsState();
}

class _CustomerSettingsState extends State<CustomerSettings> {
  final FlutterTts flutterTts = FlutterTts();
  bool isTestingVoice = false;
  bool isSavingAccount = false;

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> testVoiceAlert() async {
    if (isTestingVoice || !customerVoiceAlertsEnabledNotifier.value) return;
    setState(() => isTestingVoice = true);

    try {
      final filipino = customerVoiceLanguageNotifier.value == 'Filipino';
      await flutterTts.stop();
      await flutterTts.setLanguage(filipino ? 'fil-PH' : 'en-US');
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setPitch(1.0);
      await flutterTts.speak(
        filipino
            ? 'Maghanda na po. Malapit na ang inyong turno.'
            : 'Please prepare. Your turn is near.',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice playback is unavailable on this device.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isTestingVoice = false);
    }
  }

  Future<void> editName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || isSavingAccount) return;
    final controller = TextEditingController(
      text: loggedInCustomerNameNotifier.value.trim(),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change account name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) Navigator.pop(dialogContext, value);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;

    setState(() => isSavingAccount = true);
    try {
      await user.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      loggedInCustomerNameNotifier.value = name;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account name updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update name: $error')));
    } finally {
      if (mounted) setState(() => isSavingAccount = false);
    }
  }

  Future<void> requestEmailChange() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || isSavingAccount) return;
    final controller = TextEditingController(text: user.email ?? '');
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change email address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'New email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('SEND VERIFICATION'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email == user.email || !mounted) return;

    setState(() => isSavingAccount = true);
    try {
      await user.verifyBeforeUpdateEmail(email);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pendingEmail': email,
        'emailChangeRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification sent to $email. Open the email to confirm the change.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'requires-recent-login'
          ? 'For security, log out and sign in again before changing your email.'
          : (error.message ?? 'Unable to change email.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => isSavingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final customerName = loggedInCustomerNameNotifier.value.trim();
    final customerEmail = loggedInCustomerEmailNotifier.value.trim();

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: _cardColor,
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
        appBar: AppBar(title: const Text('Customer Settings')),
        body: SafeArea(
          child: AppResponsiveContent(
            maxWidth: 760,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: appPagePadding(context, top: 10),
              children: [
                _voiceSettings(),
                const SizedBox(height: 16),
                _languageSettings(),
                const SizedBox(height: 16),
                _reminderSettings(),
                const SizedBox(height: 16),
                AppSectionCard(
                  title: 'Account Settings',
                  icon: Icons.manage_accounts_outlined,
                  child: Column(
                    children: [
                      _AccountRow(
                        label: 'Name',
                        value: customerName.isEmpty ? 'Customer' : customerName,
                        actionLabel: 'Edit',
                        onAction: isSavingAccount ? null : editName,
                      ),
                      Divider(height: 24, color: _borderColor),
                      _AccountRow(
                        label: 'Email',
                        value: customerEmail.isNotEmpty
                            ? customerEmail
                            : (user?.email ?? 'Not available'),
                        actionLabel: 'Change',
                        onAction: isSavingAccount ? null : requestEmailChange,
                      ),
                      if (isSavingAccount) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(),
                      ],
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

  Widget _voiceSettings() {
    return AppSectionCard(
      title: 'Voice Settings',
      icon: Icons.record_voice_over_rounded,
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: customerVoiceAlertsEnabledNotifier,
            builder: (context, enabled, _) => SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Voice queue alerts',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Play a reminder when the tracked queue is near.',
                style: TextStyle(color: _mutedTextColor),
              ),
              value: enabled,
              activeThumbColor: _primaryColor,
              onChanged: (value) {
                setCustomerVoiceAlertsEnabled(value);
                if (!value) flutterTts.stop();
              },
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: customerVoiceLanguageNotifier,
            builder: (context, value, _) => DropdownButtonFormField<String>(
              initialValue: value,
              decoration: const InputDecoration(labelText: 'Voice language'),
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Filipino', child: Text('Filipino')),
              ],
              onChanged: (next) {
                if (next != null) setCustomerVoiceLanguage(next);
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ValueListenableBuilder<bool>(
              valueListenable: customerVoiceAlertsEnabledNotifier,
              builder: (context, enabled, _) => OutlinedButton.icon(
                onPressed: enabled && !isTestingVoice ? testVoiceAlert : null,
                icon: isTestingVoice
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  isTestingVoice
                      ? 'Playing voice alert...'
                      : 'Test voice alert',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageSettings() {
    return AppSectionCard(
      title: 'App Language',
      icon: Icons.language_rounded,
      child: ValueListenableBuilder<String>(
        valueListenable: customerAppLanguageNotifier,
        builder: (context, value, _) => DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Preferred language'),
          items: const [
            DropdownMenuItem(value: 'English', child: Text('English')),
            DropdownMenuItem(value: 'Filipino', child: Text('Filipino')),
          ],
          onChanged: (next) {
            if (next != null) setCustomerAppLanguage(next);
          },
        ),
      ),
    );
  }

  Widget _reminderSettings() {
    return AppSectionCard(
      title: 'Appointment Reminders',
      icon: Icons.notifications_active_outlined,
      child: ValueListenableBuilder<bool>(
        valueListenable: customerAppointmentRemindersEnabledNotifier,
        builder: (context, enabled, _) => Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'In-app appointment reminders',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Show appointment decisions and queue reminders in the app.',
                style: TextStyle(color: _mutedTextColor),
              ),
              value: enabled,
              activeThumbColor: _primaryColor,
              onChanged: setCustomerAppointmentRemindersEnabled,
            ),
            if (enabled) ...[
              Divider(color: _borderColor),
              const _ReminderRow(
                icon: Icons.fact_check_outlined,
                text: 'Check your appointment status before traveling.',
              ),
              const _ReminderRow(
                icon: Icons.folder_copy_outlined,
                text: 'Bring the original ID, OR, and CR for verification.',
              ),
              const _ReminderRow(
                icon: Icons.schedule_rounded,
                text: 'Arrive before your queue number is called.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(
              color: _mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
