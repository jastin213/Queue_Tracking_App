import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentApprovalSettings {
  const AppointmentApprovalSettings({
    required this.conditionalAutoApprovalEnabled,
    required this.conditionalAutoRejectionEnabled,
    required this.minimumScore,
  });

  static const bool defaultEnabled = false;
  static const bool defaultAutoRejectionEnabled = false;
  static const int defaultMinimumScore = 85;
  static const String documentPath = 'system_config/appointment_approval';

  final bool conditionalAutoApprovalEnabled;
  final bool conditionalAutoRejectionEnabled;
  final int minimumScore;

  factory AppointmentApprovalSettings.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return AppointmentApprovalSettings(
      conditionalAutoApprovalEnabled:
          data?['conditionalAutoApprovalEnabled'] == true,
      conditionalAutoRejectionEnabled:
          data?['conditionalAutoRejectionEnabled'] == true,
      // The current policy has one fixed threshold. Ignoring an older stored
      // value also migrates installations that previously saved 95 percent.
      minimumScore: defaultMinimumScore,
    );
  }

  static DocumentReference<Map<String, dynamic>> get document =>
      FirebaseFirestore.instance.doc(documentPath);

  static Stream<AppointmentApprovalSettings> watch() {
    return document.snapshots().map(AppointmentApprovalSettings.fromSnapshot);
  }

  static Future<void> setConditionalAutoApprovalEnabled(bool enabled) {
    return _updateAutomationSettings(autoApprovalEnabled: enabled);
  }

  static Future<void> setConditionalAutoRejectionEnabled(bool enabled) {
    return _updateAutomationSettings(autoRejectionEnabled: enabled);
  }

  static Future<void> _updateAutomationSettings({
    bool? autoApprovalEnabled,
    bool? autoRejectionEnabled,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final data = snapshot.data();
      final approval =
          autoApprovalEnabled ??
          (data?['conditionalAutoApprovalEnabled'] == true);
      final rejection =
          autoRejectionEnabled ??
          (data?['conditionalAutoRejectionEnabled'] == true);
      final mode = switch ((approval, rejection)) {
        (true, true) => 'conditional_auto_approval_and_rejection',
        (true, false) => 'conditional_auto_approval',
        (false, true) => 'conditional_auto_rejection',
        (false, false) => 'manual',
      };
      transaction.set(document, {
        'conditionalAutoApprovalEnabled': approval,
        'conditionalAutoRejectionEnabled': rejection,
        'minimumScore': defaultMinimumScore,
        'mode': mode,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
      }, SetOptions(merge: true));
    });
  }
}
