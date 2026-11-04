import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'daily_queue_capacity.dart';
import 'firestore_query_fields.dart';
import 'queue_source.dart';
import 'vehicle_category.dart';

class DailyQueueSubmissionUnconfirmed extends FirebaseException {
  DailyQueueSubmissionUnconfirmed()
    : super(
        plugin: 'daily-queue-capacity',
        code: 'unavailable',
        message:
            'Submission could not be confirmed. Check My Appointment Status before trying again.',
      );
}

FirebaseException _capacityError(String code, String message) =>
    FirebaseException(
      plugin: 'daily-queue-capacity',
      code: code,
      message: message,
    );
Map<String, dynamic> _capacityMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
String _capacityCode(Map<String, dynamic> item) =>
    (item['queue'] ?? item['queueId'] ?? '').toString().trim();

/// One claim changes per atomic commit, validated by server-side Security Rules.
class CapacityDayTransaction {
  CapacityDayTransaction.fromData(
    this.date,
    this.policy,
    Map<String, dynamic>? data,
  ) : appointmentClaims = _capacityMap(data?['appointmentClaims']),
      walkInClaims = _capacityMap(data?['walkInClaims']),
      completedClaims = _capacityMap(data?['completedClaims']),
      legacyQueueClaims = _capacityMap(data?['legacyQueueClaims']);
  final String date;
  final DailyQueueCapacityPolicy policy;
  final Map<String, dynamic> appointmentClaims;
  final Map<String, dynamic> walkInClaims;
  final Map<String, dynamic> completedClaims;
  final Map<String, dynamic> legacyQueueClaims;
  Map<String, dynamic>? _mutation;
  bool get hasMutation => _mutation != null;
  bool codeIsReserved(String code) =>
      appointmentClaims.containsValue(code) || walkInClaims.containsValue(code);
  void _change(String action, String source, String id, String queue) {
    if (_mutation != null) {
      throw StateError('A capacity transaction changes one claim at a time.');
    }
    _mutation = {
      'action': action,
      'source': source,
      'claimId': id,
      'queue': queue,
    };
  }

  void _requireSpace(String source) {
    final used = source == 'appointment'
        ? appointmentClaims.length
        : walkInClaims.length;
    if (used >= policy.sourceLimit) {
      final label = source == 'appointment' ? 'Appointment' : 'Walk-in';
      throw _capacityError(
        'resource-exhausted',
        '$label allocation is full ($used/${policy.sourceLimit}). Choose another date.',
      );
    }
    if (appointmentClaims.length + walkInClaims.length >= policy.dailyLimit) {
      throw _capacityError(
        'resource-exhausted',
        'The combined daily capacity is full. Choose another date.',
      );
    }
  }

  void reserveAppointment(String id, String queue) {
    _requireSpace('appointment');
    if (codeIsReserved(queue) || appointmentClaims.containsKey(id)) {
      throw _capacityError(
        'already-exists',
        'This queue code is already reserved. Choose another code.',
      );
    }
    _change('reserve', 'appointment', id, queue);
    appointmentClaims[id] = queue;
  }

  void reserveWalkIn(String id, String queue) {
    _requireSpace('walkin');
    if (codeIsReserved(queue) || walkInClaims.containsKey(id)) {
      throw _capacityError(
        'already-exists',
        'This queue code is already reserved.',
      );
    }
    _change('reserve', 'walkin', id, queue);
    walkInClaims[id] = queue;
  }

  void releaseAppointment(String id, String queue) {
    if (!appointmentClaims.containsKey(id) ||
        completedClaims.containsKey('appointment:$id')) {
      return;
    }
    if (appointmentClaims[id] != queue) {
      throw _capacityError(
        'failed-precondition',
        'The appointment reservation changed. Refresh and retry.',
      );
    }
    _change('release', 'appointment', id, queue);
    appointmentClaims.remove(id);
  }

  void releaseWalkIn(String queue) {
    final binding = _capacityMap(legacyQueueClaims[queue]);
    if (binding['source'] == 'appointment' &&
        appointmentClaims.containsValue(queue)) {
      return;
    }
    final matches = walkInClaims.entries.where((entry) => entry.value == queue);
    if (matches.isEmpty) {
      return;
    }
    final id = matches.first.key;
    if (completedClaims.containsKey('walkin:$id')) {
      return;
    }
    _change('release', 'walkin', id, queue);
    walkInClaims.remove(id);
  }

  void completeQueue(Map<String, dynamic> item) {
    final queue = _capacityCode(item);
    final binding = _capacityMap(legacyQueueClaims[queue]);
    final quotaSource = item['quotaSource']?.toString().trim().toLowerCase();
    final hasAppointmentId =
        (item['appointmentId']?.toString().trim() ?? '').isNotEmpty ||
        (item['_appointmentDocumentPath']?.toString().trim() ?? '').isNotEmpty;
    final hasWalkInId =
        (item['capacityRequestId']?.toString().trim() ?? '').isNotEmpty;
    final sourceHint = quotaSource == 'appointment' || quotaSource == 'walkin'
        ? quotaSource
        : hasAppointmentId
        ? 'appointment'
        : hasWalkInId
        ? 'walkin'
        : binding['source'];
    final appointment =
        sourceHint == 'appointment' ||
        (sourceHint != 'walkin' &&
            normalizedQueueSource(item) == appointmentQueueSource);
    final source = appointment ? 'appointment' : 'walkin';
    var id = appointment
        ? item['appointmentId']?.toString().trim() ?? ''
        : item['capacityRequestId']?.toString().trim() ?? '';
    if (id.isEmpty && appointment) {
      id = (item['_appointmentDocumentPath']?.toString().trim() ?? '')
          .split('/')
          .last;
    }
    if (id.isEmpty) {
      id = binding['claimId']?.toString() ?? '';
    }
    final claims = appointment ? appointmentClaims : walkInClaims;
    if (id.isEmpty || claims[id] != queue) {
      throw _capacityError(
        'failed-precondition',
        'The queue allocation could not be verified. Refresh before continuing.',
      );
    }
    final token = '$source:$id';
    if (completedClaims.containsKey(token)) {
      return;
    }
    _change('complete', source, id, queue);
    completedClaims[token] = {
      'source': source,
      'queue': queue,
      if (appointment) 'appointmentId': id,
    };
  }

  Map<String, dynamic> _data() => {
    'schemaVersion': 2,
    'date': date,
    'appointmentClaims': appointmentClaims,
    'walkInClaims': walkInClaims,
    'completedClaims': completedClaims,
    'legacyQueueClaims': legacyQueueClaims,
    'lastMutation': _mutation!,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class DailyQueueCapacityService {
  static DocumentReference<Map<String, dynamic>> get _settings =>
      FirebaseFirestore.instance.doc('system_config/queue_capacity');
  static String _dateId(String date) {
    final parsed = dateFromMdy(date);
    if (parsed == null ||
        '${parsed.month}/${parsed.day}/${parsed.year}' != date) {
      throw _capacityError(
        'invalid-argument',
        'The selected queue date is invalid.',
      );
    }
    return date.replaceAll('/', '-');
  }

  static DocumentReference<Map<String, dynamic>> _dayRef(String date) =>
      FirebaseFirestore.instance.doc('capacity_days/${_dateId(date)}');
  static Stream<DailyQueueCapacityPolicy> watchPolicy() async* {
    yield* _settings.snapshots().map(
      (snapshot) => DailyQueueCapacityPolicy.fromData(snapshot.data()),
    );
  }

  static Stream<Map<String, dynamic>> watchCompletedClaims(String date) async* {
    yield* _dayRef(date).snapshots().map(
      (snapshot) => _capacityMap(snapshot.data()?['completedClaims']),
    );
  }

  static Future<void> savePolicy(int dailyLimit) async {
    if (DailyQueueCapacityPolicy.tryParse(dailyLimit) == null) {
      throw _capacityError(
        'invalid-argument',
        'Choose a daily limit from 20 to 150 in steps of 10.',
      );
    }
    await _settings.update({
      'dailyLimit': dailyLimit,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<T> runDayTransaction<T>(
    String date,
    Future<T> Function(Transaction transaction, CapacityDayTransaction day)
    action,
  ) {
    final dayRef = _dayRef(date);
    return FirebaseFirestore.instance.runTransaction<T>((transaction) async {
      final config = (await transaction.get(_settings)).data();
      if (config?['schemaVersion'] != 2 ||
          config?['migrationComplete'] != true) {
        throw _capacityError(
          'unavailable',
          'Queue allocation is being initialized. Please retry shortly.',
        );
      }
      final data = (await transaction.get(dayRef)).data();
      if (data != null &&
          (data['schemaVersion'] != 2 || data['date'] != date)) {
        throw _capacityError(
          'failed-precondition',
          'This date needs an allocation update. Please contact the administrator.',
        );
      }
      final day = CapacityDayTransaction.fromData(
        date,
        DailyQueueCapacityPolicy.fromData(config),
        data,
      );
      final result = await action(transaction, day);
      if (day.hasMutation) {
        transaction.set(dayRef, day._data());
      }
      return result;
    });
  }

  static Future<void> submitAppointment(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> appointment,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || appointment['customerId'] != user.uid) {
      throw _capacityError(
        'unauthenticated',
        'Please sign in before booking an appointment.',
      );
    }
    final date = appointment['date'].toString();
    final queue = appointment['queue'].toString();
    try {
      await runDayTransaction<void>(date, (transaction, day) async {
        final existing = (await transaction.get(reference)).data();
        if (existing != null) {
          if (existing['customerId'] == user.uid &&
              existing['date'] == date &&
              existing['queue'] == queue) {
            return;
          }
          throw _capacityError(
            'already-exists',
            'This appointment is already in use.',
          );
        }
        if (!RegExp(r'^[GD][0-9]{3}$').hasMatch(queue) ||
            int.parse(queue.substring(1)) < 1 ||
            int.parse(queue.substring(1)) > day.policy.dailyLimit) {
          throw _capacityError(
            'invalid-argument',
            'Choose an available queue code.',
          );
        }
        day.reserveAppointment(reference.id, queue);
        transaction.set(reference, {
          ...appointment,
          'appointmentId': reference.id,
          'customerId': user.uid,
          'status': 'Pending',
          'source': 'Appointment',
          'quotaSource': 'appointment',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      if (!{
        'unavailable',
        'deadline-exceeded',
        'unknown',
      }.contains(error.code)) {
        rethrow;
      }
      try {
        final saved =
            (await reference
                    .get(const GetOptions(source: Source.server))
                    .timeout(const Duration(seconds: 8)))
                .data();
        if (saved?['customerId'] == user.uid &&
            saved?['date'] == date &&
            saved?['queue'] == queue) {
          return;
        }
      } catch (_) {}
      throw DailyQueueSubmissionUnconfirmed();
    }
  }

  static Future<String> generateWalkIn({
    required String requestId,
    required String date,
    required String type,
    required String name,
    required String plate,
    required String vehicleCategory,
    String? vehicleCategoryOther,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw _capacityError('unauthenticated', 'Please sign in again.');
    }
    final payload = {
      'date': date,
      'type': type,
      'name': name.trim().replaceAll(RegExp(r'\s+'), ' '),
      'plate': plate.trim().toUpperCase(),
      ...vehicleCategoryFields(
        category: vehicleCategory,
        other: vehicleCategoryOther,
      ),
    };
    final digest = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    final receiptRef = _dayRef(date).collection('requests').doc(requestId);
    return runDayTransaction<String>(date, (transaction, day) async {
      final receipt = (await transaction.get(receiptRef)).data();
      if (receipt != null) {
        if (receipt['adminId'] == user.uid &&
            receipt['payloadFingerprint'] == digest) {
          return receipt['queue'].toString();
        }
        throw _capacityError(
          'already-exists',
          'This form was already used for another queue request.',
        );
      }
      final prefix = type == 'Gas' ? 'G' : 'D';
      var queue = '';
      for (var number = 1; number <= day.policy.dailyLimit; number++) {
        final candidate = '$prefix${number.toString().padLeft(3, '0')}';
        if (!day.codeIsReserved(candidate)) {
          queue = candidate;
          break;
        }
      }
      if (queue.isEmpty) {
        throw _capacityError(
          'resource-exhausted',
          'No queue code is available for this fuel type.',
        );
      }
      final queueRef = FirebaseFirestore.instance.doc(
        'queues/${_dateId(date)}/items/$queue',
      );
      final existing = (await transaction.get(queueRef)).data();
      if (existing != null &&
          !{
            'cancelled',
            'reset',
          }.contains(existing['status']?.toString().trim().toLowerCase())) {
        throw _capacityError(
          'failed-precondition',
          'Queue availability changed. Refresh before retrying.',
        );
      }
      day.reserveWalkIn(requestId, queue);
      transaction.set(queueRef, {
        ...payload,
        'queueId': queue,
        'queue': queue,
        'source': 'Walk-in',
        'quotaSource': 'walkin',
        'capacityRequestId': requestId,
        'status': 'Waiting',
        ...firestoreQueryFields(
          date: date,
          plate: payload['plate'],
          name: payload['name'],
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(receiptRef, {
        'adminId': user.uid,
        'payloadFingerprint': digest,
        'queue': queue,
        'date': date,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return queue;
    });
  }

  static Future<void> preserveCompletedUsage({
    required String date,
    required String queue,
    String? appointmentId,
  }) {
    return runDayTransaction<void>(date, (transaction, day) async {
      final reference = FirebaseFirestore.instance.doc(
        'queues/${_dateId(date)}/items/$queue',
      );
      final current = (await transaction.get(reference)).data();
      if (current == null) {
        if (day.completedClaims.values.any(
          (claim) => claim is Map && claim['queue'] == queue,
        )) {
          return;
        }
        throw _capacityError(
          'failed-precondition',
          'The completed record is unavailable. Refresh before deleting it.',
        );
      }
      if (!{
        'passed',
        'failed',
      }.contains(current['status']?.toString().trim().toLowerCase())) {
        throw _capacityError(
          'failed-precondition',
          'The queue record changed. Refresh before deleting it.',
        );
      }
      day.completeQueue({...current, 'queue': queue});
    });
  }
}
