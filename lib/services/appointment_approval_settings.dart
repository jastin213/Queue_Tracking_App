import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentApprovalSettings {
  const AppointmentApprovalSettings({
    required this.conditionalAutoApprovalEnabled,
    required this.minimumScore,
  });

  static const bool defaultEnabled = false;
  static const int defaultMinimumScore = 95;
  static const String documentPath = 'system_config/appointment_approval';

  final bool conditionalAutoApprovalEnabled;
  final int minimumScore;

  factory AppointmentApprovalSettings.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final configuredScore = data?['minimumScore'];
    return AppointmentApprovalSettings(
      conditionalAutoApprovalEnabled:
          data?['conditionalAutoApprovalEnabled'] == true,
      minimumScore: configuredScore is num
          ? configuredScore.round().clamp(90, 100)
          : defaultMinimumScore,
    );
  }

  static DocumentReference<Map<String, dynamic>> get document =>
      FirebaseFirestore.instance.doc(documentPath);

  static Stream<AppointmentApprovalSettings> watch() {
    return document.snapshots().map(AppointmentApprovalSettings.fromSnapshot);
  }

  static Future<void> setConditionalAutoApprovalEnabled(bool enabled) {
    final user = FirebaseAuth.instance.currentUser;
    return document.set({
      'conditionalAutoApprovalEnabled': enabled,
      'minimumScore': defaultMinimumScore,
      'mode': enabled ? 'conditional_auto_approval' : 'manual',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user?.uid,
    }, SetOptions(merge: true));
  }
}
