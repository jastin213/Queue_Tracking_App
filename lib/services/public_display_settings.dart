import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const String defaultDisplayAnnouncement =
    'Please wait for your queue number to be called.';

final ValueNotifier<String> displayAnnouncementNotifier = ValueNotifier(
  defaultDisplayAnnouncement,
);

class PublicDisplaySettings {
  const PublicDisplaySettings._();

  static const String documentPath = 'system_config/display_settings';

  static DocumentReference<Map<String, dynamic>> get document =>
      FirebaseFirestore.instance.doc(documentPath);

  static Stream<String> watchAnnouncement() {
    if (Firebase.apps.isEmpty) {
      return Stream<String>.value(displayAnnouncementNotifier.value);
    }

    return document.snapshots().map((snapshot) {
      final savedAnnouncement = snapshot.data()?['announcement'];
      final announcement = savedAnnouncement is String
          ? savedAnnouncement.trim()
          : '';
      final resolvedAnnouncement = announcement.isEmpty
          ? defaultDisplayAnnouncement
          : announcement;
      displayAnnouncementNotifier.value = resolvedAnnouncement;
      return resolvedAnnouncement;
    });
  }

  static Future<void> saveAnnouncement(String value) async {
    final announcement = value.trim();
    final resolvedAnnouncement = announcement.isEmpty
        ? defaultDisplayAnnouncement
        : announcement;

    if (Firebase.apps.isNotEmpty) {
      await document.set({
        'announcement': resolvedAnnouncement,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));
    }

    displayAnnouncementNotifier.value = resolvedAnnouncement;
  }
}
