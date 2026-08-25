import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import '../services/document_image_optimizer.dart';
import '../services/firestore_query_fields.dart';
import '../services/platform_storage_upload.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_responsive_content.dart';
import 'location_data.dart';
import 'admin_page.dart';
import 'customer_register.dart';

// ================= COLOR THEME =================

const Color _backgroundColor = AppColors.background;
const Color _primaryColor = AppColors.primary;
const Color _cardColor = AppColors.surface;
const Color _borderColor = AppColors.border;
const Color _mutedTextColor = AppColors.mutedText;
const Color _softPrimaryColor = AppColors.softPrimary;
const int _maxDocumentBytes = 10 * 1024 * 1024;
const int _firestoreChunkBytes = 650 * 1024;

String normalizePhilippinePlateNumber(String value) {
  return value.trim().toUpperCase();
}

String? validatePhilippinePlateNumber(String value) {
  final String plateNumber = normalizePhilippinePlateNumber(value);

  if (plateNumber.isEmpty) {
    return "Enter the vehicle plate number.";
  }

  if (!RegExp(r'^[A-Z0-9]+$').hasMatch(plateNumber)) {
    return "Use letters and numbers only—no spaces or symbols.";
  }

  if (plateNumber.length < 6 || plateNumber.length > 7) {
    return "Plate number must contain 6–7 characters.";
  }

  if (!RegExp(r'[A-Z]').hasMatch(plateNumber) ||
      !RegExp(r'[0-9]').hasMatch(plateNumber)) {
    return "Plate number must include both letters and digits.";
  }

  return null;
}

// ================= GLOBAL BOOKING & QUEUE STORAGE =================
//
// These local notifiers are kept temporarily so the current admin dashboard,
// appointment status page, and existing UI will not break.
// Firestore is now the permanent backend source for submitted appointments.

ValueNotifier<List<Map<String, dynamic>>> pendingBookings = ValueNotifier([]);
ValueNotifier<List<Map<String, dynamic>>> approvedBookings = ValueNotifier([]);
ValueNotifier<List<Map<String, dynamic>>> rejectedBookings = ValueNotifier([]);

// ================= DAILY REPORT =================

ValueNotifier<List<Map<String, dynamic>>> dailyReport = ValueNotifier([]);

// ================= BOOK APPOINTMENT PAGE =================

class BookAppointment extends StatefulWidget {
  const BookAppointment({super.key});

  @override
  State<BookAppointment> createState() => _BookAppointmentState();
}

class _BookAppointmentState extends State<BookAppointment> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController plateController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  DateTime? selectedDate;
  String selectedVehicle = "Gas";
  String selectedQueueCode = "G001";
  String selectedMunicipality = "Ligao";

  String? idFileName;
  String? orFileName;
  String? crFileName;

  String? idFilePath;
  String? orFilePath;
  String? crFilePath;

  Uint8List? idFileBytes;
  Uint8List? orFileBytes;
  Uint8List? crFileBytes;

  bool isSubmitting = false;
  double uploadProgress = 0;
  String? plateNumberError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _appointmentAvailabilitySubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _queueAvailabilitySubscription;
  Set<String> _appointmentUnavailableCodes = {};
  Set<String> _queueUnavailableCodes = {};
  bool _appointmentAvailabilityLoaded = false;
  bool _queueAvailabilityLoaded = false;
  Object? _availabilityError;

  static const int maxQueueLimit = 80;

  String get loggedInCustomerName => loggedInCustomerNameNotifier.value.trim();

  String get loggedInCustomerEmail =>
      loggedInCustomerEmailNotifier.value.trim();

  String get loggedInCustomerId => loggedInCustomerIdNotifier.value.trim();

  @override
  void initState() {
    super.initState();

    if (loggedInCustomerName.isNotEmpty) {
      fullNameController.text = loggedInCustomerName;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => showBookingPolicy());
  }

  @override
  void dispose() {
    _appointmentAvailabilitySubscription?.cancel();
    _queueAvailabilitySubscription?.cancel();
    fullNameController.dispose();
    plateController.dispose();
    super.dispose();
  }

  String get formattedDate {
    if (selectedDate == null) return "";
    return "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}";
  }

  String normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void showBookingPolicy() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          "Appointment Policy",
          style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Before booking an appointment, please confirm the following:",
                style: TextStyle(color: _mutedTextColor),
              ),
              SizedBox(height: 14),
              Text(
                "1. Provide your full name.",
                style: TextStyle(color: _primaryColor),
              ),
              SizedBox(height: 6),
              Text(
                "2. Upload a valid ID, OR, and CR.",
                style: TextStyle(color: _primaryColor),
              ),
              SizedBox(height: 6),
              Text(
                "3. Be present when your queue is called.",
                style: TextStyle(color: _primaryColor),
              ),
              SizedBox(height: 6),
              Text(
                "4. Missed turns will be moved to the bottom of the queue.",
                style: TextStyle(color: _primaryColor),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          SizedBox(
            height: 45,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "I UNDERSTAND",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= QUEUE CODE HELPERS =================

  String queueDateId(String date) => date.replaceAll("/", "-");

  CollectionReference<Map<String, dynamic>> queueItemsRef(String date) {
    return FirebaseFirestore.instance
        .collection("queues")
        .doc(queueDateId(date))
        .collection("items");
  }

  bool get isAvailabilityLoading =>
      selectedDate != null &&
      (!_appointmentAvailabilityLoaded || !_queueAvailabilityLoaded);

  Set<String> get realtimeUnavailableCodes => {
    ..._appointmentUnavailableCodes,
    ..._queueUnavailableCodes,
  };

  Set<String> unavailableAppointmentCodes(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .where((doc) {
          final status = doc.data()["status"]?.toString() ?? "";
          return status == "Pending" || status == "Approved";
        })
        .map((doc) => doc.data()["queue"]?.toString() ?? "")
        .where((code) {
          return code.isNotEmpty;
        })
        .toSet();
  }

  Set<String> unavailableQueueCodes(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .where((doc) {
          final status = doc.data()["status"]?.toString() ?? "";
          return status != "Cancelled" && status != "Reset";
        })
        .map((doc) => doc.data()["queue"]?.toString() ?? doc.id)
        .where((code) {
          return code.isNotEmpty;
        })
        .toSet();
  }

  void keepSelectedQueueAvailable() {
    if (selectedDate == null) return;
    if (selectedQueueCode.isEmpty || isQueueTaken(selectedQueueCode)) {
      selectedQueueCode = getFirstAvailableQueueCode();
    }
  }

  void listenToQueueAvailability() {
    _appointmentAvailabilitySubscription?.cancel();
    _queueAvailabilitySubscription?.cancel();

    final date = formattedDate;
    if (date.isEmpty) return;

    setState(() {
      _appointmentUnavailableCodes = {};
      _queueUnavailableCodes = {};
      _appointmentAvailabilityLoaded = false;
      _queueAvailabilityLoaded = false;
      _availabilityError = null;
    });

    _appointmentAvailabilitySubscription = FirebaseFirestore.instance
        .collection("appointments")
        .where("date", isEqualTo: date)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || formattedDate != date) return;
            setState(() {
              _appointmentUnavailableCodes = unavailableAppointmentCodes(
                snapshot,
              );
              _appointmentAvailabilityLoaded = true;
              _availabilityError = null;
              keepSelectedQueueAvailable();
            });
          },
          onError: (Object error) {
            if (!mounted || formattedDate != date) return;
            setState(() {
              _appointmentAvailabilityLoaded = true;
              _availabilityError = error;
            });
          },
        );

    _queueAvailabilitySubscription = queueItemsRef(date).snapshots().listen(
      (snapshot) {
        if (!mounted || formattedDate != date) return;
        setState(() {
          _queueUnavailableCodes = unavailableQueueCodes(snapshot);
          _queueAvailabilityLoaded = true;
          _availabilityError = null;
          keepSelectedQueueAvailable();
        });
      },
      onError: (Object error) {
        if (!mounted || formattedDate != date) return;
        setState(() {
          _queueAvailabilityLoaded = true;
          _availabilityError = error;
        });
      },
    );
  }

  Future<void> refreshQueueAvailability() async {
    final date = formattedDate;
    if (date.isEmpty) return;

    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection("appointments")
          .where("date", isEqualTo: date)
          .get(const GetOptions(source: Source.server)),
      queueItemsRef(date).get(const GetOptions(source: Source.server)),
    ]);

    if (!mounted || formattedDate != date) return;
    setState(() {
      _appointmentUnavailableCodes = unavailableAppointmentCodes(results[0]);
      _queueUnavailableCodes = unavailableQueueCodes(results[1]);
      _appointmentAvailabilityLoaded = true;
      _queueAvailabilityLoaded = true;
      _availabilityError = null;
      keepSelectedQueueAvailable();
    });
  }

  List<String> getQueueCodes() {
    String prefix = selectedVehicle == "Gas" ? "G" : "D";

    return List.generate(maxQueueLimit, (index) {
      return "$prefix${(index + 1).toString().padLeft(3, '0')}";
    });
  }

  bool isQueueTaken(String code) {
    if (selectedDate == null) return false;

    if (realtimeUnavailableCodes.contains(code)) return true;

    bool inIssued =
        issuedQueueCodesNotifier.value[formattedDate]?.contains(code) ?? false;

    bool inPending = pendingBookings.value.any(
      (b) => b["date"] == formattedDate && b["queue"] == code,
    );

    bool inApproved = approvedBookings.value.any(
      (b) => b["date"] == formattedDate && b["queue"] == code,
    );

    bool inWaitingQueue = waitingQueueNotifier.value.any(
      (customer) =>
          customer["date"] == formattedDate && customer["queue"] == code,
    );

    bool inNowServing =
        nowServingNotifier.value != null &&
        nowServingNotifier.value!["date"] == formattedDate &&
        nowServingNotifier.value!["queue"] == code;

    return inIssued ||
        inPending ||
        inApproved ||
        inWaitingQueue ||
        inNowServing;
  }

  Future<bool> isQueueTakenInFirestore(String date, String queueCode) async {
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection("appointments")
          .where("date", isEqualTo: date)
          .get(const GetOptions(source: Source.server)),
      queueItemsRef(
        date,
      ).doc(queueCode).get(const GetOptions(source: Source.server)),
    ]);
    final appointmentSnapshot =
        results[0] as QuerySnapshot<Map<String, dynamic>>;
    final queueSnapshot = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final reservedAppointment = appointmentSnapshot.docs.any((doc) {
      final data = doc.data();
      final status = data["status"]?.toString() ?? "";
      return data["queue"]?.toString() == queueCode &&
          (status == "Pending" || status == "Approved");
    });
    final queueStatus = queueSnapshot.data()?["status"]?.toString() ?? "";
    final activeQueue =
        queueSnapshot.exists &&
        queueStatus != "Cancelled" &&
        queueStatus != "Reset";

    return reservedAppointment || activeQueue;
  }

  String getFirstAvailableQueueCode() {
    final codes = getQueueCodes();

    for (var code in codes) {
      if (!isQueueTaken(code)) return code;
    }

    return "";
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _appointmentUnavailableCodes = {};
        _queueUnavailableCodes = {};
        selectedDate = picked;
        selectedQueueCode = getFirstAvailableQueueCode();
      });
      listenToQueueAvailability();
    }
  }

  // ================= DOCUMENT PICKING =================

  Future<void> pickDocument(String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ["jpg", "jpeg", "png", "pdf"],
      );

      if (result == null || !mounted) return;

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to read selected file. Please try again."),
          ),
        );
        return;
      }

      final optimizedImage = await optimizeDocumentImage(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      final Uint8List selectedBytes = optimizedImage.bytes;

      if (selectedBytes.length > _maxDocumentBytes) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Each document must be 10 MB or smaller."),
          ),
        );
        return;
      }

      final String? safePath = kIsWeb || optimizedImage.wasOptimized
          ? null
          : file.path;

      setState(() {
        if (type == "ID") {
          idFileName = file.name;
          idFilePath = safePath;
          idFileBytes = selectedBytes;
        } else if (type == "OR") {
          orFileName = file.name;
          orFilePath = safePath;
          orFileBytes = selectedBytes;
        } else if (type == "CR") {
          crFileName = file.name;
          crFilePath = safePath;
          crFileBytes = selectedBytes;
        }
      });

      if (optimizedImage.wasOptimized && mounted) {
        final double originalMb = bytes.length / (1024 * 1024);
        final double optimizedMb = selectedBytes.length / (1024 * 1024);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Image optimized from ${originalMb.toStringAsFixed(1)} MB "
              "to ${optimizedMb.toStringAsFixed(1)} MB.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("File upload failed: $e")));
    }
  }

  Future<void> captureDocument(String type) async {
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo == null) return;

      final Uint8List bytes = await photo.readAsBytes();
      final String? safePath = kIsWeb ? null : photo.path;

      if (bytes.length > _maxDocumentBytes) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Each document must be 10 MB or smaller."),
          ),
        );
        return;
      }

      setState(() {
        if (type == "ID") {
          idFileName = photo.name;
          idFilePath = safePath;
          idFileBytes = bytes;
        } else if (type == "OR") {
          orFileName = photo.name;
          orFilePath = safePath;
          orFileBytes = bytes;
        } else if (type == "CR") {
          crFileName = photo.name;
          crFilePath = safePath;
          crFileBytes = bytes;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Camera is unavailable or permission was denied. Please choose a file instead. $e",
          ),
        ),
      );
    }
  }

  String documentContentType(String fileName) {
    final String extension = fileName.toLowerCase().split('.').last;

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  bool isPdfDocument(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf');
  }

  Future<void> showSelectedDocumentPreview({
    required String title,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final bool isPdf = isPdfDocument(fileName);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _cardColor,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
                  decoration: const BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        tooltip: "Close preview",
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isPdf
                      ? PdfPreview(
                          build: (_) async => bytes,
                          allowPrinting: false,
                          allowSharing: false,
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          pdfFileName: fileName,
                        )
                      : Container(
                          width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.04),
                          padding: const EdgeInsets.all(12),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              cacheWidth: 1600,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Text(
                                    "Unable to preview this image.",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget selectedDocumentPreview({
    required String title,
    required String fileName,
    required Uint8List bytes,
  }) {
    final bool isPdf = isPdfDocument(fileName);

    void openPreview() {
      showSelectedDocumentPreview(
        title: title,
        fileName: fileName,
        bytes: bytes,
      );
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        Material(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isSubmitting ? null : openPreview,
            child: Container(
              width: double.infinity,
              height: isPdf ? 96 : 150,
              decoration: BoxDecoration(
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isPdf
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 38,
                          color: Colors.red,
                        ),
                        SizedBox(height: 6),
                        Text(
                          "PDF selected — tap to view",
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          cacheHeight: 400,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                "Image preview unavailable",
                                style: TextStyle(color: _mutedTextColor),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Tap to view",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: isSubmitting ? null : openPreview,
            icon: const Icon(Icons.visibility_outlined, size: 19),
            label: const Text("View selected file"),
            style: TextButton.styleFrom(foregroundColor: _primaryColor),
          ),
        ),
      ],
    );
  }

  String safeStorageFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  Future<({String path, String url})> uploadAppointmentDocument({
    required String customerId,
    required String appointmentId,
    required String documentType,
    required String fileName,
    required Uint8List bytes,
    required String? filePath,
    void Function(double progress)? onProgress,
  }) async {
    final String safeFileName = safeStorageFileName(fileName);
    final Reference documentRef = FirebaseStorage.instance.ref().child(
      'appointment_documents/$customerId/$appointmentId/'
      '${documentType.toLowerCase()}_$safeFileName',
    );

    final UploadTask uploadTask = startPlatformStorageUpload(
      reference: documentRef,
      bytes: bytes,
      filePath: filePath,
      metadata: SettableMetadata(
        contentType: documentContentType(fileName),
        customMetadata: {
          'appointmentId': appointmentId,
          'customerId': customerId,
          'documentType': documentType,
          'originalFileName': fileName,
        },
      ),
    );
    final StreamSubscription<TaskSnapshot> progressSubscription = uploadTask
        .snapshotEvents
        .listen((snapshot) {
          final totalBytes = snapshot.totalBytes;
          if (totalBytes > 0) {
            onProgress?.call(snapshot.bytesTransferred / totalBytes);
          }
        });

    try {
      await uploadTask;
    } finally {
      await progressSubscription.cancel();
    }

    return (
      path: documentRef.fullPath,
      url: await documentRef.getDownloadURL(),
    );
  }

  Future<void> uploadAppointmentDocumentToFirestore({
    required DocumentReference<Map<String, dynamic>> appointmentRef,
    required String customerId,
    required String documentType,
    required String fileName,
    required Uint8List bytes,
    required List<DocumentReference<Map<String, dynamic>>> createdRefs,
  }) async {
    final documentRef = appointmentRef
        .collection('documents')
        .doc(documentType.toLowerCase());
    final int chunkCount =
        (bytes.length + _firestoreChunkBytes - 1) ~/ _firestoreChunkBytes;

    await documentRef.set({
      'customerId': customerId,
      'documentType': documentType,
      'fileName': fileName,
      'contentType': documentContentType(fileName),
      'size': bytes.length,
      'chunkCount': chunkCount,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    createdRefs.add(documentRef);

    const int chunksPerBatch = 8;

    for (
      int firstChunk = 0;
      firstChunk < chunkCount;
      firstChunk += chunksPerBatch
    ) {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final List<DocumentReference<Map<String, dynamic>>> batchRefs = [];
      final int lastChunk = (firstChunk + chunksPerBatch < chunkCount)
          ? firstChunk + chunksPerBatch
          : chunkCount;

      for (int index = firstChunk; index < lastChunk; index++) {
        final int start = index * _firestoreChunkBytes;
        final int end = (start + _firestoreChunkBytes < bytes.length)
            ? start + _firestoreChunkBytes
            : bytes.length;
        final chunkRef = documentRef
            .collection('chunks')
            .doc(index.toString().padLeft(3, '0'));

        batch.set(chunkRef, {
          'customerId': customerId,
          'index': index,
          'data': Blob(Uint8List.sublistView(bytes, start, end)),
        });
        batchRefs.add(chunkRef);
      }

      await batch.commit();
      createdRefs.addAll(batchRefs);
    }
  }

  // ================= SUBMIT APPOINTMENT =================

  Future<void> submitBooking() async {
    if (isSubmitting) return;

    final User? currentUser = FirebaseAuth.instance.currentUser;

    final String customerName = loggedInCustomerName.isNotEmpty
        ? normalizeName(loggedInCustomerName)
        : normalizeName(fullNameController.text);

    final String customerEmail = loggedInCustomerEmail.isNotEmpty
        ? loggedInCustomerEmail
        : (currentUser?.email ?? "");

    final String customerId = loggedInCustomerId.isNotEmpty
        ? loggedInCustomerId
        : (currentUser?.uid ?? "");

    final String plateNumber = normalizePhilippinePlateNumber(
      plateController.text,
    );

    if (currentUser == null || customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please login first before submitting an appointment."),
        ),
      );
      return;
    }

    final String? currentPlateError = validatePhilippinePlateNumber(
      plateNumber,
    );

    if (currentPlateError != null) {
      setState(() {
        plateNumberError = currentPlateError;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(currentPlateError)));
      return;
    }

    if (selectedDate == null ||
        customerName.isEmpty ||
        idFileBytes == null ||
        orFileBytes == null ||
        crFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete all fields and documents.")),
      );
      return;
    }

    if (getFirstAvailableQueueCode().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "All queue codes are taken for this date. Please select another date.",
          ),
        ),
      );
      return;
    }

    if (isQueueTaken(selectedQueueCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "This queue code is already taken. Please select another available queue.",
          ),
        ),
      );

      setState(() {
        selectedQueueCode = getFirstAvailableQueueCode();
      });

      return;
    }

    setState(() {
      isSubmitting = true;
      uploadProgress = 0;
    });

    final List<Reference> uploadedDocumentRefs = [];
    final List<DocumentReference<Map<String, dynamic>>>
    uploadedFirestoreDocumentRefs = [];
    bool appointmentSaved = false;

    try {
      final bool firestoreQueueTaken = await isQueueTakenInFirestore(
        formattedDate,
        selectedQueueCode,
      );

      if (firestoreQueueTaken) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "This queue code was already taken online. Please choose another queue.",
            ),
          ),
        );

        setState(() {
          selectedQueueCode = getFirstAvailableQueueCode();
        });

        return;
      }

      final DocumentReference<Map<String, dynamic>> appointmentRef =
          FirebaseFirestore.instance.collection("appointments").doc();

      String idFileUrl = '';
      String orFileUrl = '';
      String crFileUrl = '';
      String idStoragePath = '';
      String orStoragePath = '';
      String crStoragePath = '';
      String documentBackend = 'firebase_storage';

      try {
        FirebaseStorage.instance.setMaxUploadRetryTime(
          const Duration(seconds: 5),
        );
        FirebaseStorage.instance.setMaxOperationRetryTime(
          const Duration(seconds: 5),
        );

        final idUpload = await uploadAppointmentDocument(
          customerId: customerId,
          appointmentId: appointmentRef.id,
          documentType: 'ID',
          fileName: idFileName ?? 'valid_id.jpg',
          bytes: idFileBytes!,
          filePath: idFilePath,
          onProgress: (progress) {
            if (mounted) setState(() => uploadProgress = progress / 3);
          },
        );
        idFileUrl = idUpload.url;
        idStoragePath = idUpload.path;
        uploadedDocumentRefs.add(FirebaseStorage.instance.ref(idUpload.path));

        final orUpload = await uploadAppointmentDocument(
          customerId: customerId,
          appointmentId: appointmentRef.id,
          documentType: 'OR',
          fileName: orFileName ?? 'official_receipt.jpg',
          bytes: orFileBytes!,
          filePath: orFilePath,
          onProgress: (progress) {
            if (mounted) setState(() => uploadProgress = (1 + progress) / 3);
          },
        );
        orFileUrl = orUpload.url;
        orStoragePath = orUpload.path;
        uploadedDocumentRefs.add(FirebaseStorage.instance.ref(orUpload.path));

        final crUpload = await uploadAppointmentDocument(
          customerId: customerId,
          appointmentId: appointmentRef.id,
          documentType: 'CR',
          fileName: crFileName ?? 'certificate_of_registration.jpg',
          bytes: crFileBytes!,
          filePath: crFilePath,
          onProgress: (progress) {
            if (mounted) setState(() => uploadProgress = (2 + progress) / 3);
          },
        );
        crFileUrl = crUpload.url;
        crStoragePath = crUpload.path;
        uploadedDocumentRefs.add(FirebaseStorage.instance.ref(crUpload.path));
      } catch (_) {
        for (final Reference documentRef in uploadedDocumentRefs.reversed) {
          try {
            await documentRef.delete();
          } catch (_) {
            // Best-effort cleanup before switching to Firestore file storage.
          }
        }
        uploadedDocumentRefs.clear();
        documentBackend = 'firestore';
        if (mounted) setState(() => uploadProgress = 0.45);

        await uploadAppointmentDocumentToFirestore(
          appointmentRef: appointmentRef,
          customerId: customerId,
          documentType: 'ID',
          fileName: idFileName ?? 'valid_id.jpg',
          bytes: idFileBytes!,
          createdRefs: uploadedFirestoreDocumentRefs,
        );
        if (mounted) setState(() => uploadProgress = 0.65);
        await uploadAppointmentDocumentToFirestore(
          appointmentRef: appointmentRef,
          customerId: customerId,
          documentType: 'OR',
          fileName: orFileName ?? 'official_receipt.jpg',
          bytes: orFileBytes!,
          createdRefs: uploadedFirestoreDocumentRefs,
        );
        if (mounted) setState(() => uploadProgress = 0.82);
        await uploadAppointmentDocumentToFirestore(
          appointmentRef: appointmentRef,
          customerId: customerId,
          documentType: 'CR',
          fileName: crFileName ?? 'certificate_of_registration.jpg',
          bytes: crFileBytes!,
          createdRefs: uploadedFirestoreDocumentRefs,
        );
        if (mounted) setState(() => uploadProgress = 1);
      }

      final Map<String, dynamic> appointmentData = {
        "appointmentId": appointmentRef.id,
        "customerId": customerId,
        "customerEmail": customerEmail,
        "fullName": customerName,
        "municipality": selectedMunicipality,
        "plate": plateNumber,
        "vehicle": selectedVehicle,
        "queue": selectedQueueCode,
        "date": formattedDate,
        ...firestoreQueryFields(
          date: formattedDate,
          plate: plateNumber,
          name: customerName,
        ),
        "status": "Pending",

        "idFile": idFileName,
        "orFile": orFileName,
        "crFile": crFileName,
        "idFileUrl": idFileUrl,
        "orFileUrl": orFileUrl,
        "crFileUrl": crFileUrl,
        "idStoragePath": idStoragePath,
        "orStoragePath": orStoragePath,
        "crStoragePath": crStoragePath,
        "idFileUploaded": true,
        "orFileUploaded": true,
        "crFileUploaded": true,
        "documentBackend": documentBackend,
        "archiveState": "active",
        "documentsPurged": false,
        "retentionDeleteAfter": Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 365)),
        ),
        "totalDocumentBytes": idFileBytes!.lengthInBytes +
            orFileBytes!.lengthInBytes +
            crFileBytes!.lengthInBytes,

        "source": "Appointment",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      };

      await appointmentRef.set(appointmentData);
      appointmentSaved = true;

      // Keep local data temporarily so current frontend pages still work
      // until admin dashboard and appointment status are also converted to Firestore.
      pendingBookings.value = [
        ...pendingBookings.value,
        {
          ...appointmentData,
          "createdAt": DateTime.now().toIso8601String(),
          "updatedAt": DateTime.now().toIso8601String(),
          "idPath": idFilePath,
          "orPath": orFilePath,
          "crPath": crFilePath,
          "idBytes": idFileBytes,
          "orBytes": orFileBytes,
          "crBytes": crFileBytes,
        },
      ];

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment submitted successfully.")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!appointmentSaved) {
        for (final Reference documentRef in uploadedDocumentRefs.reversed) {
          try {
            await documentRef.delete();
          } catch (_) {
            // Best-effort cleanup for files uploaded before a failed submission.
          }
        }

        for (final documentRef in uploadedFirestoreDocumentRefs.reversed) {
          try {
            await documentRef.delete();
          } catch (_) {
            // Best-effort cleanup for Firestore chunks from a failed submission.
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Appointment submission failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
          uploadProgress = 0;
        });
      }
    }
  }

  // ================= UI HELPERS =================

  Widget sectionTitle({
    required String number,
    required String title,
    required IconData icon,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 24, color: _primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _mutedTextColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _primaryColor.withOpacity(0.06), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }

  InputDecoration formDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _mutedTextColor),
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget policyReminder() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: _primaryColor.withOpacity(0.05), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _softPrimaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.policy_outlined, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Please review the booking policy before submitting your appointment.",
              style: TextStyle(
                fontSize: 13,
                color: _mutedTextColor,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            onPressed: showBookingPolicy,
            child: const Text(
              "Review",
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget dateButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: isSubmitting ? null : pickDate,
        icon: const Icon(Icons.calendar_month_outlined, color: _primaryColor),
        label: Text(
          selectedDate == null ? "Choose Appointment Date" : formattedDate,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: _borderColor),
          backgroundColor: _backgroundColor,
        ),
      ),
    );
  }

  Widget queueMessageBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 22, color: _primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.left,
              style: const TextStyle(color: _primaryColor, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget liveAvailabilityStatus() {
    final prefix = selectedVehicle == "Gas" ? "G" : "D";
    final unavailableCount = realtimeUnavailableCodes.where((code) {
      return code.startsWith(prefix);
    }).length;
    final hasError = _availabilityError != null;
    final color = hasError
        ? Colors.red
        : isAvailabilityLoading
        ? Colors.blue
        : Colors.green;
    final message = hasError
        ? "Live update unavailable — pull down to retry"
        : isAvailabilityLoading
        ? "Connecting to live queue availability..."
        : "Live availability • $unavailableCount unavailable";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          if (isAvailabilityLoading && !hasError)
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              hasError ? Icons.sync_problem_rounded : Icons.circle,
              color: color,
              size: hasError ? 19 : 11,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(
            Icons.swipe_down_alt_rounded,
            color: _mutedTextColor,
            size: 19,
          ),
        ],
      ),
    );
  }

  Widget queueCodesView(List<String> codes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        liveAvailabilityStatus(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _softPrimaryColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Icon(
                selectedQueueCode.isEmpty
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 22,
                color: _primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selectedQueueCode.isEmpty
                      ? "No available queue code for this date."
                      : "Selected queue code: $selectedQueueCode",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: codes.map((code) {
            bool taken = isQueueTaken(code);
            bool selected = selectedQueueCode == code;

            return GestureDetector(
              onTap: taken || isSubmitting
                  ? null
                  : () {
                      setState(() {
                        selectedQueueCode = code;
                      });
                    },
              child: Container(
                width: 74,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: taken
                      ? const Color(0xFFE3E9EC)
                      : selected
                      ? _primaryColor
                      : _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? _primaryColor
                        : taken
                        ? const Color(0xFFD1DCE1)
                        : _borderColor,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  taken ? "Taken" : code,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? Colors.white
                        : taken
                        ? _mutedTextColor
                        : _primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ================= UPLOAD CARD =================

  Widget uploadCard({
    required String title,
    required String? fileName,
    required Uint8List? fileBytes,
    required VoidCallback onPick,
    required VoidCallback onCamera,
  }) {
    final bool hasFile = fileName != null && fileBytes != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasFile ? _primaryColor : _borderColor,
          width: hasFile ? 1.3 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: hasFile ? _softPrimaryColor : _backgroundColor,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: Icon(
                  hasFile ? Icons.check_circle_outline : Icons.upload_file,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileName ?? "No file uploaded",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasFile)
            selectedDocumentPreview(
              title: title,
              fileName: fileName,
              bytes: fileBytes,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onPick,
                  icon: Icon(
                    hasFile ? Icons.change_circle_outlined : Icons.attach_file,
                    size: 18,
                  ),
                  label: Text(hasFile ? "Choose Another" : "Choose File"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: const BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onCamera,
                  icon: Icon(
                    hasFile ? Icons.replay_rounded : Icons.camera_alt,
                    size: 18,
                  ),
                  label: Text(
                    hasFile
                        ? (kIsWeb ? "Choose New Photo" : "Retake Photo")
                        : (kIsWeb ? "Camera / Photo" : "Take Photo"),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: const BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    List<String> codes = getQueueCodes();

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
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: _primaryColor.withOpacity(0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text("Book Appointment")),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: _cardColor,
              border: const Border(top: BorderSide(color: _borderColor)),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.08),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.center,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submitBooking,
                    child: isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "UPLOADING ${(uploadProgress.clamp(0, 1) * 100).round()}%",
                              ),
                            ],
                          )
                        : const Text("SUBMIT APPOINTMENT"),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: AppRefreshIndicator(
            onRefresh: refreshQueueAvailability,
            child: AppResponsiveContent(
              maxWidth: 880,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: appPagePadding(context, top: 18, bottom: 26),
                children: [
                  policyReminder(),

                  sectionTitle(
                    number: "1",
                    title: "Appointment Details",
                    subtitle:
                        "Choose the date, location, vehicle type, and queue code.",
                    icon: Icons.event_available_outlined,
                  ),
                  sectionCard(
                    children: [
                      fieldLabel("Appointment Date"),
                      dateButton(),
                      const SizedBox(height: 18),

                      fieldLabel("Customer Location"),
                      DropdownButtonFormField<String>(
                        value: selectedMunicipality,
                        decoration: formDecoration("Select Location"),
                        dropdownColor: _cardColor,
                        iconEnabledColor: _primaryColor,
                        style: const TextStyle(color: _primaryColor),
                        items: albayThirdDistrictLocations.map((loc) {
                          return DropdownMenuItem(
                            value: loc.name,
                            child: Text(loc.name),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() {
                                  selectedMunicipality = v;
                                });
                              },
                      ),

                      const SizedBox(height: 18),

                      fieldLabel("Vehicle Type"),
                      DropdownButtonFormField<String>(
                        value: selectedVehicle,
                        decoration: formDecoration("Select Vehicle Type"),
                        dropdownColor: _cardColor,
                        iconEnabledColor: _primaryColor,
                        style: const TextStyle(color: _primaryColor),
                        items: const [
                          DropdownMenuItem(value: "Gas", child: Text("Gas")),
                          DropdownMenuItem(
                            value: "Diesel",
                            child: Text("Diesel"),
                          ),
                        ],
                        onChanged: isSubmitting
                            ? null
                            : (v) {
                                if (v == null) return;

                                setState(() {
                                  selectedVehicle = v;

                                  if (selectedDate != null) {
                                    selectedQueueCode =
                                        getFirstAvailableQueueCode();
                                  } else {
                                    selectedQueueCode = selectedVehicle == "Gas"
                                        ? "G001"
                                        : "D001";
                                  }
                                });
                              },
                      ),

                      const SizedBox(height: 18),

                      fieldLabel("Available Queue Codes"),
                      if (selectedDate == null)
                        queueMessageBox(
                          "Please choose an appointment date first to view available queue codes.",
                        )
                      else
                        queueCodesView(codes),
                    ],
                  ),

                  sectionTitle(
                    number: "2",
                    title: "Customer Information",
                    subtitle:
                        "The appointment name is linked to the logged-in customer account.",
                    icon: Icons.person_outline,
                  ),
                  sectionCard(
                    children: [
                      fieldLabel("Full Name"),
                      TextField(
                        controller: fullNameController,
                        readOnly:
                            loggedInCustomerName.isNotEmpty || isSubmitting,
                        style: const TextStyle(color: _primaryColor),
                        decoration: formDecoration("Enter full name").copyWith(
                          suffixIcon: loggedInCustomerName.isNotEmpty
                              ? const Icon(
                                  Icons.lock_outline_rounded,
                                  color: _primaryColor,
                                )
                              : null,
                        ),
                      ),
                      if (loggedInCustomerName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "This name is locked to your logged-in account so your appointment status will appear correctly.",
                          style: TextStyle(
                            color: _mutedTextColor,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      fieldLabel("Plate Number"),
                      TextField(
                        controller: plateController,
                        enabled: !isSubmitting,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 7,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(7),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            return newValue.copyWith(
                              text: newValue.text.toUpperCase(),
                              composing: TextRange.empty,
                            );
                          }),
                        ],
                        onChanged: (value) {
                          final String? error = validatePhilippinePlateNumber(
                            value,
                          );

                          if (error != plateNumberError) {
                            setState(() {
                              plateNumberError = error;
                            });
                          }
                        },
                        style: const TextStyle(color: _primaryColor),
                        decoration: formDecoration("Example: ABC1234").copyWith(
                          errorText: plateNumberError,
                          errorMaxLines: 2,
                          helperText:
                              "Enter exactly as printed: 6–7 letters and numbers.",
                          helperMaxLines: 2,
                          counterText: "",
                        ),
                      ),
                    ],
                  ),

                  sectionTitle(
                    number: "3",
                    title: "Required Documents",
                    subtitle:
                        "Upload or capture a photo of each required document.",
                    icon: Icons.folder_copy_outlined,
                  ),
                  sectionCard(
                    children: [
                      uploadCard(
                        title: "Valid ID",
                        fileName: idFileName,
                        fileBytes: idFileBytes,
                        onPick: () => pickDocument("ID"),
                        onCamera: () => captureDocument("ID"),
                      ),
                      const SizedBox(height: 14),

                      uploadCard(
                        title: "Official Receipt (OR)",
                        fileName: orFileName,
                        fileBytes: orFileBytes,
                        onPick: () => pickDocument("OR"),
                        onCamera: () => captureDocument("OR"),
                      ),
                      const SizedBox(height: 14),

                      uploadCard(
                        title: "Certificate of Registration (CR)",
                        fileName: crFileName,
                        fileBytes: crFileBytes,
                        onPick: () => pickDocument("CR"),
                        onCamera: () => captureDocument("CR"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
