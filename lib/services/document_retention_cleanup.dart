import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ExpiredDocumentCandidate {
  const ExpiredDocumentCandidate({
    required this.id,
    required this.reference,
    required this.data,
    required this.expiresAt,
    required this.estimatedBytes,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> data;
  final DateTime expiresAt;
  final int estimatedBytes;

  String get customerName =>
      data['fullName']?.toString().trim().isNotEmpty == true
      ? data['fullName'].toString().trim()
      : 'Unknown customer';

  String get plate => data['plate']?.toString().trim().isNotEmpty == true
      ? data['plate'].toString().trim()
      : 'No plate recorded';

  String get appointmentDate =>
      data['date']?.toString().trim().isNotEmpty == true
      ? data['date'].toString().trim()
      : 'Date unavailable';

  String get queue => data['queue']?.toString().trim().isNotEmpty == true
      ? data['queue'].toString().trim()
      : 'No queue code';

  String get backend =>
      data['documentBackend']?.toString().trim().isNotEmpty == true
      ? data['documentBackend'].toString().trim()
      : 'unknown';
}

class DocumentCleanupResult {
  const DocumentCleanupResult({
    required this.appointmentId,
    required this.estimatedBytesFreed,
  });

  final String appointmentId;
  final int estimatedBytesFreed;
}

class DocumentRetentionCleanupService {
  DocumentRetentionCleanupService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  static const int retentionDays = 365;
  static const int maximumCandidatesPerLoad = 100;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<void> ensureCurrentUserIsAdmin() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An administrator must be signed in.');
    }

    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final role = userSnapshot.data()?['role']?.toString().toLowerCase();
    if (role != 'admin') {
      throw StateError('Only administrators can remove expired documents.');
    }
  }

  Future<List<ExpiredDocumentCandidate>> loadExpiredDocuments() async {
    await ensureCurrentUserIsAdmin();

    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('appointments')
        .where(
          'retentionDeleteAfter',
          isLessThanOrEqualTo: Timestamp.fromDate(now),
        )
        .orderBy('retentionDeleteAfter')
        .limit(maximumCandidatesPerLoad)
        .get(const GetOptions(source: Source.server));

    final candidates = <ExpiredDocumentCandidate>[];
    for (final document in snapshot.docs) {
      final data = document.data();
      final expiration = data['retentionDeleteAfter'];
      if (data['documentsPurged'] == true || expiration is! Timestamp) continue;

      final estimatedBytes = data['totalDocumentBytes'];
      candidates.add(
        ExpiredDocumentCandidate(
          id: document.id,
          reference: document.reference,
          data: Map<String, dynamic>.unmodifiable(data),
          expiresAt: expiration.toDate(),
          estimatedBytes: estimatedBytes is num ? estimatedBytes.round() : 0,
        ),
      );
    }
    return candidates;
  }

  Future<DocumentCleanupResult> archiveAndDelete(
    ExpiredDocumentCandidate candidate,
  ) async {
    await ensureCurrentUserIsAdmin();

    // Always re-read from the server immediately before a destructive action.
    // This prevents a stale cached appointment from being deleted by mistake.
    final latestSnapshot = await candidate.reference.get(
      const GetOptions(source: Source.server),
    );
    if (!latestSnapshot.exists) {
      throw StateError('This appointment no longer exists.');
    }

    final latestData = latestSnapshot.data()!;
    final expiration = latestData['retentionDeleteAfter'];
    if (latestData['documentsPurged'] == true) {
      throw StateError('These documents were already removed.');
    }
    if (expiration is! Timestamp ||
        expiration.toDate().isAfter(DateTime.now())) {
      throw StateError('These documents have not reached the retention date.');
    }

    final estimatedBytes = latestData['totalDocumentBytes'];
    final bytesToFree = estimatedBytes is num ? estimatedBytes.round() : 0;
    final archiveReference = _firestore
        .collection('appointment_archives')
        .doc(latestSnapshot.id);

    // The lightweight archive is committed before any file or chunk is removed.
    await archiveReference.set(
      _archiveSummary(latestSnapshot.id, latestData),
      SetOptions(merge: true),
    );

    await _deleteStorageFiles(latestData);
    await _deleteFirestoreFallback(latestSnapshot.reference);

    await latestSnapshot.reference.update({
      'archiveState': 'archived',
      'documentsPurged': true,
      'documentsPurgedAt': FieldValue.serverTimestamp(),
      'documentsPurgedBy': _auth.currentUser!.uid,
      'retentionDeleteAfter': FieldValue.delete(),
      'idFile': FieldValue.delete(),
      'orFile': FieldValue.delete(),
      'crFile': FieldValue.delete(),
      'idFileUrl': FieldValue.delete(),
      'orFileUrl': FieldValue.delete(),
      'crFileUrl': FieldValue.delete(),
      'idStoragePath': FieldValue.delete(),
      'orStoragePath': FieldValue.delete(),
      'crStoragePath': FieldValue.delete(),
      'idFileUploaded': false,
      'orFileUploaded': false,
      'crFileUploaded': false,
      'documentBackend': 'purged',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return DocumentCleanupResult(
      appointmentId: latestSnapshot.id,
      estimatedBytesFreed: bytesToFree,
    );
  }

  Future<void> recordManualCleanup({
    required int selected,
    required int purged,
    required int failed,
    required int estimatedBytesFreed,
  }) async {
    try {
      await _firestore.doc('system_config/storage_retention').set({
        'retentionDays': retentionDays,
        'lastManualCleanupAt': FieldValue.serverTimestamp(),
        'lastManualCleanupBy': _auth.currentUser?.uid,
        'lastManualCleanupSelected': selected,
        'lastManualCleanupPurged': purged,
        'lastManualCleanupFailed': failed,
        'lastManualCleanupEstimatedBytesFreed': estimatedBytesFreed,
      }, SetOptions(merge: true));
    } catch (_) {
      // Cleanup audit information is helpful but must never change whether an
      // already completed document purge is reported as successful.
    }
  }

  Map<String, dynamic> _archiveSummary(
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    return {
      'appointmentId': appointmentId,
      'customerId': data['customerId'],
      'customerEmail': data['customerEmail'],
      'fullName': data['fullName'],
      'fullNameSearch': data['fullNameSearch'],
      'municipality': data['municipality'],
      'barangay': data['barangay'],
      'plate': data['plate'],
      'plateSearch': data['plateSearch'],
      'vehicle': data['vehicle'],
      'queue': data['queue'],
      'date': data['date'],
      'dateKey': data['dateKey'],
      'monthKey': data['monthKey'],
      'status': data['status'],
      'source': data['source'] ?? 'Appointment',
      'createdAt': data['createdAt'],
      'updatedAt': data['updatedAt'],
      'totalDocumentBytes': data['totalDocumentBytes'] ?? 0,
      'documentsPurged': true,
      'archiveReason': 'Document retention period expired',
      'archiveSource': 'manual_admin_cleanup',
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': _auth.currentUser?.uid,
    };
  }

  Future<void> _deleteStorageFiles(Map<String, dynamic> data) async {
    final paths = <String>{
      for (final field in const [
        'idStoragePath',
        'orStoragePath',
        'crStoragePath',
      ])
        if ((data[field]?.toString().trim() ?? '').isNotEmpty)
          data[field].toString().trim(),
    };

    for (final path in paths) {
      try {
        await _storage.ref(path).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }

  Future<void> _deleteFirestoreFallback(
    DocumentReference<Map<String, dynamic>> appointmentReference,
  ) async {
    final documents = await appointmentReference
        .collection('documents')
        .get(const GetOptions(source: Source.server));

    for (final document in documents.docs) {
      final chunks = await document.reference
          .collection('chunks')
          .get(const GetOptions(source: Source.server));
      await _deleteReferences(
        chunks.docs.map((item) => item.reference).toList(),
      );
      await document.reference.delete();
    }
  }

  Future<void> _deleteReferences(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    for (int start = 0; start < references.length; start += 400) {
      final end = start + 400 < references.length
          ? start + 400
          : references.length;
      final batch = _firestore.batch();
      for (final reference in references.sublist(start, end)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }
}
