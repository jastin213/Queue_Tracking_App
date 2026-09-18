import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const String documentUploadConsentVersion = '2026-09-08-v1';

/// Shows the authorization notice without creating an account or writing data.
/// Registration uses this first so choosing "Not now" cancels account creation.
Future<bool> requestDocumentUploadConsent(BuildContext context) async {
  if (!context.mounted) return false;
  bool authorized = false;

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined),
                    SizedBox(width: 10),
                    Expanded(child: Text('Document Upload Authorization')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NPJN needs your authorization before you upload a '
                        'Valid ID, Official Receipt (OR), and Certificate of '
                        'Registration (CR).',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The documents will be used only to verify your '
                        'appointment and may be viewed by authorized '
                        'administrators. Invalid, altered, or mismatched '
                        'documents may cause the appointment to be rejected.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Uploaded documents are protected by the application\'s '
                        'access rules and are subject to the configured data '
                        'retention policy.',
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: authorized,
                        onChanged: (value) {
                          setDialogState(() => authorized = value ?? false);
                        },
                        title: const Text(
                          'I authorize the collection, review, and temporary '
                          'storage of these documents for appointment '
                          'verification.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('NOT NOW'),
                  ),
                  FilledButton.icon(
                    onPressed: authorized
                        ? () => Navigator.pop(dialogContext, true)
                        : null,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('ACCEPT & CONTINUE'),
                  ),
                ],
              );
            },
          );
        },
      ) ??
      false;
}

/// Requests and records the customer's authorization before sensitive
/// appointment documents are selected or uploaded.
Future<bool> ensureDocumentUploadConsent(
  BuildContext context, {
  bool forcePrompt = false,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  if (!forcePrompt) {
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = profile.data();
      if (data?['documentUploadConsent'] == true &&
          data?['documentUploadConsentVersion'] ==
              documentUploadConsentVersion) {
        return true;
      }
    } catch (_) {
      // Continue to the notice. No upload is allowed unless saving succeeds.
    }
  }

  if (!context.mounted) return false;
  final accepted = await requestDocumentUploadConsent(context);

  if (!accepted) return false;

  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'documentUploadConsent': true,
      'documentUploadConsentVersion': documentUploadConsentVersion,
      'documentUploadConsentAcceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Authorization could not be saved. Please check your connection '
            'and try again. $error',
          ),
        ),
      );
    }
    return false;
  }
}
