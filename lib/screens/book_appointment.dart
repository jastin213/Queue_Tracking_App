import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'location_data.dart';
import 'admin_page.dart';
import 'customer_register.dart';

// ================= COLOR THEME =================

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

// ================= GLOBAL BOOKING & QUEUE STORAGE =================

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

  static const int maxQueueLimit = 80;

  String get loggedInCustomerName => loggedInCustomerNameNotifier.value.trim();

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
          "Booking Policy",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Before booking, please confirm the following:",
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

  List<String> getQueueCodes() {
    String prefix = selectedVehicle == "Gas" ? "G" : "D";

    return List.generate(maxQueueLimit, (index) {
      return "$prefix${(index + 1).toString().padLeft(3, '0')}";
    });
  }

  bool isQueueTaken(String code) {
    if (selectedDate == null) return false;

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
        selectedDate = picked;
        selectedQueueCode = getFirstAvailableQueueCode();
      });
    }
  }

  // ================= DOCUMENT PICKING =================

  Future<void> pickDocument(String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          "jpg",
          "jpeg",
          "png",
          "pdf",
        ],
      );

      if (result == null) return;

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

      final String? safePath = kIsWeb ? null : file.path;

      setState(() {
        if (type == "ID") {
          idFileName = file.name;
          idFilePath = safePath;
          idFileBytes = bytes;
        } else if (type == "OR") {
          orFileName = file.name;
          orFilePath = safePath;
          orFileBytes = bytes;
        } else if (type == "CR") {
          crFileName = file.name;
          crFilePath = safePath;
          crFileBytes = bytes;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File upload failed: $e")),
      );
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

  // ================= SUBMIT BOOKING =================

  void submitBooking() {
    final String customerName = loggedInCustomerName.isNotEmpty
        ? normalizeName(loggedInCustomerName)
        : normalizeName(fullNameController.text);

    if (selectedDate == null ||
        customerName.isEmpty ||
        plateController.text.trim().isEmpty ||
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

    pendingBookings.value = [
      ...pendingBookings.value,
      {
        "fullName": customerName,
        "municipality": selectedMunicipality,
        "plate": plateController.text.trim().toUpperCase(),
        "vehicle": selectedVehicle,
        "queue": selectedQueueCode,
        "date": formattedDate,
        "status": "Pending",
        "idFile": idFileName,
        "orFile": orFileName,
        "crFile": crFileName,
        "idPath": idFilePath,
        "orPath": orFilePath,
        "crPath": crFilePath,
        "idBytes": idFileBytes,
        "orBytes": orFileBytes,
        "crBytes": crFileBytes,
      },
    ];

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Appointment submitted successfully.")),
    );

    Navigator.pop(context);
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
        onPressed: pickDate,
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

  Widget queueCodesView(List<String> codes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onTap: taken
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
    required VoidCallback onPick,
    required VoidCallback onCamera,
  }) {
    final bool hasFile = fileName != null;

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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text("Choose File"),
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
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(kIsWeb ? "Camera / Photo" : "Take Photo"),
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
            child: SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: submitBooking,
                child: const Text("SUBMIT APPOINTMENT"),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
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
                    onChanged: (v) {
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
                      DropdownMenuItem(value: "Diesel", child: Text("Diesel")),
                    ],
                    onChanged: (v) {
                      if (v == null) return;

                      setState(() {
                        selectedVehicle = v;

                        if (selectedDate != null) {
                          selectedQueueCode = getFirstAvailableQueueCode();
                        } else {
                          selectedQueueCode =
                              selectedVehicle == "Gas" ? "G001" : "D001";
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
                    "The booking name is linked to the logged-in customer account.",
                icon: Icons.person_outline,
              ),
              sectionCard(
                children: [
                  fieldLabel("Full Name"),
                  TextField(
                    controller: fullNameController,
                    readOnly: loggedInCustomerName.isNotEmpty,
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
                      "This name is locked to your logged-in account so your booking status will appear correctly.",
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
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: _primaryColor),
                    decoration: formDecoration("Enter plate number"),
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
                    onPick: () => pickDocument("ID"),
                    onCamera: () => captureDocument("ID"),
                  ),
                  const SizedBox(height: 14),

                  uploadCard(
                    title: "Official Receipt (OR)",
                    fileName: orFileName,
                    onPick: () => pickDocument("OR"),
                    onCamera: () => captureDocument("OR"),
                  ),
                  const SizedBox(height: 14),

                  uploadCard(
                    title: "Certificate of Registration (CR)",
                    fileName: crFileName,
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
    );
  }
}