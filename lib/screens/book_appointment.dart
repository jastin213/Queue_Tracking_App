import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'location_data.dart';

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

  static const int maxQueueLimit = 80;

  @override
  void initState() {
    super.initState();
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

  void showBookingPolicy() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Booking Policy"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Before booking, please follow these policies:"),
              SizedBox(height: 10),
              Text("1. Provide your full name."),
              Text("2. Provide your OR and CR."),
              Text("3. Provide a valid ID."),
              Text("4. Be present when your queue is called."),
              Text("5. If you miss your turn, you will be moved to the bottom."),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("I AGREE"),
          ),
        ],
      ),
    );
  }

  // ================= DYNAMIC QUEUE CODES =================
  List<String> getQueueCodes() {
    String prefix = selectedVehicle == "Gas" ? "G" : "D";
    return List.generate(maxQueueLimit, (index) {
      return "$prefix${(index + 1).toString().padLeft(3, '0')}";
    });
  }

  bool isQueueTaken(String code) {
    if (selectedDate == null) return false;

    bool inPending = pendingBookings.value.any(
      (b) => b["date"] == formattedDate && b["queue"] == code,
    );

    bool inApproved = approvedBookings.value.any(
      (b) => b["date"] == formattedDate && b["queue"] == code,
    );

    return inPending || inApproved;
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
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedQueueCode = getFirstAvailableQueueCode();
      });
    }
  }

  Future<void> pickDocument(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() {
        if (type == "ID") {
          idFileName = result.files.single.name;
          idFilePath = result.files.single.path!;
        } else if (type == "OR") {
          orFileName = result.files.single.name;
          orFilePath = result.files.single.path!;
        } else if (type == "CR") {
          crFileName = result.files.single.name;
          crFilePath = result.files.single.path!;
        }
      });
    }
  }

  Future<void> captureDocument(String type) async {
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo != null) {
      setState(() {
        if (type == "ID") { idFileName = photo.name; idFilePath = photo.path; }
        else if (type == "OR") { orFileName = photo.name; orFilePath = photo.path; }
        else if (type == "CR") { crFileName = photo.name; crFilePath = photo.path; }
      });
    }
  }

  void submitBooking() {
    if (selectedDate == null ||
        fullNameController.text.isEmpty ||
        plateController.text.isEmpty ||
        idFilePath == null ||
        orFilePath == null ||
        crFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete all fields and documents.")),
      );
      return;
    }

    if (getFirstAvailableQueueCode() == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All queue codes are taken today. Please select another date.")),
      );
      return;
    }

    pendingBookings.value = [
      ...pendingBookings.value,
      {
        "fullName": fullNameController.text.trim(),
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
      }
    ];

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Appointment submitted successfully.")),
    );

    Navigator.pop(context);
  }

  Widget uploadCard({required String title, required String? fileName, required VoidCallback onPick, required VoidCallback onCamera}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          const Icon(Icons.upload_file, size: 40),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(fileName ?? "No file selected", textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: onPick, icon: const Icon(Icons.attach_file), label: const Text("Choose File"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: onCamera, icon: const Icon(Icons.camera_alt), label: const Text("Take Photo"))),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> codes = getQueueCodes();

    return Scaffold(
      appBar: AppBar(title: const Text("Book Appointment")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text("Select Appointment Date", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: pickDate,
              child: Text(selectedDate == null ? "Choose Date" : formattedDate),
            ),
            const SizedBox(height: 25),
            TextField(controller: fullNameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            const Text("Customer Location", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedMunicipality,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: albayThirdDistrictLocations.map((loc) => DropdownMenuItem(value: loc.name, child: Text(loc.name))).toList(),
              onChanged: (v) => setState(() => selectedMunicipality = v!),
            ),
            const SizedBox(height: 25),
            const Text("Vehicle Type", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedVehicle,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "Gas", child: Text("Gas")),
                DropdownMenuItem(value: "Diesel", child: Text("Diesel")),
              ],
              onChanged: (v) => setState(() {
                selectedVehicle = v!;
                if (selectedDate != null) selectedQueueCode = getFirstAvailableQueueCode();
              }),
            ),
            const SizedBox(height: 25),
            const Text("Available Queue Codes", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: codes.map((code) {
                bool taken = isQueueTaken(code);
                bool selected = selectedQueueCode == code;
                return GestureDetector(
                  onTap: taken ? null : () => setState(() => selectedQueueCode = code),
                  child: Container(
                    width: 80,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: taken ? Colors.grey.shade400 : selected ? Colors.black : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(taken ? "Taken" : code, style: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),
            TextField(controller: plateController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Plate Number", border: OutlineInputBorder())),
            const SizedBox(height: 25),
            uploadCard(title: "Upload Valid ID", fileName: idFileName, onPick: () => pickDocument("ID"), onCamera: () => captureDocument("ID")),
            const SizedBox(height: 20),
            uploadCard(title: "Upload OR", fileName: orFileName, onPick: () => pickDocument("OR"), onCamera: () => captureDocument("OR")),
            const SizedBox(height: 20),
            uploadCard(title: "Upload CR", fileName: crFileName, onPick: () => pickDocument("CR"), onCamera: () => captureDocument("CR")),
            const SizedBox(height: 30),
            SizedBox(height: 55, child: ElevatedButton(onPressed: submitBooking, child: const Text("SUBMIT APPOINTMENT"))),
          ],
        ),
      ),
    );
  }
}