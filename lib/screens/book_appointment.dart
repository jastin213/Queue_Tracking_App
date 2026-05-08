import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

// ================= GLOBAL BOOKING STORAGE =================

ValueNotifier<List<Map<String, dynamic>>> pendingBookings = ValueNotifier([]);

ValueNotifier<List<Map<String, dynamic>>> approvedBookings = ValueNotifier([]);

ValueNotifier<List<Map<String, dynamic>>> rejectedBookings = ValueNotifier([]);

// ================= BOOK APPOINTMENT PAGE =================

class BookAppointment extends StatefulWidget {
  const BookAppointment({super.key});

  @override
  State<BookAppointment> createState() => _BookAppointmentState();
}

class _BookAppointmentState extends State<BookAppointment> {
  // ================= CONTROLLERS =================

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController plateController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  DateTime? selectedDate;

  String selectedVehicle = "Gas";
  String selectedQueueCode = "G001";

  // ================= FILE DATA =================

  String? idFileName;
  String? orFileName;
  String? crFileName;

  String? idFilePath;
  String? orFilePath;
  String? crFilePath;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showBookingPolicy();
    });
  }

  // ================= FORMAT DATE =================

  String get formattedDate {
    if (selectedDate == null) return "";
    return "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}";
  }

  // ================= BOOKING POLICY POPUP =================

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
              Text("Before booking an appointment, please follow these policies:"),
              SizedBox(height: 15),
              Text("1. Provide your full name."),
              Text("2. Provide your OR and CR."),
              Text("3. Provide your valid ID."),
              Text("4. Make sure you are at the center when your queue number is called."),
              Text("5. If you fail to appear on time, you will be skipped and moved to the bottom of the queue."),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("I AGREE"),
          ),
        ],
      ),
    );
  }

  // ================= GENERATE QUEUE CODES =================

  List<String> getQueueCodes() {
    String prefix = selectedVehicle == "Gas" ? "G" : "D";

    return List.generate(10, (index) {
      return "$prefix${(index + 1).toString().padLeft(3, '0')}";
    });
  }

  // ================= CHECK IF QUEUE CODE IS TAKEN =================

  bool isQueueTaken(String code) {
    if (selectedDate == null) return false;

    bool inPending = pendingBookings.value.any(
      (booking) =>
          booking["date"] == formattedDate &&
          booking["queue"] == code,
    );

    bool inApproved = approvedBookings.value.any(
      (booking) =>
          booking["date"] == formattedDate &&
          booking["queue"] == code,
    );

    return inPending || inApproved;
  }

  // ================= PICK DATE =================

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
      });
    }
  }

  // ================= PICK FILE FROM DEVICE =================

  Future<void> pickDocument(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      String fileName = result.files.single.name;
      String filePath = result.files.single.path!;

      setState(() {
        if (type == "ID") {
          idFileName = fileName;
          idFilePath = filePath;
        } else if (type == "OR") {
          orFileName = fileName;
          orFilePath = filePath;
        } else if (type == "CR") {
          crFileName = fileName;
          crFilePath = filePath;
        }
      });
    }
  }

  // ================= TAKE PHOTO USING CAMERA =================

  Future<void> captureDocument(String type) async {
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (photo != null) {
      setState(() {
        if (type == "ID") {
          idFileName = photo.name;
          idFilePath = photo.path;
        } else if (type == "OR") {
          orFileName = photo.name;
          orFilePath = photo.path;
        } else if (type == "CR") {
          crFileName = photo.name;
          crFilePath = photo.path;
        }
      });
    }
  }

  // ================= SUBMIT BOOKING =================

  void submitBooking() {
    if (selectedDate == null ||
        fullNameController.text.trim().isEmpty ||
        plateController.text.trim().isEmpty ||
        idFilePath == null ||
        orFilePath == null ||
        crFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete all fields and upload all documents."),
        ),
      );

      return;
    }

    if (isQueueTaken(selectedQueueCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selected queue code is already taken."),
        ),
      );

      return;
    }

    pendingBookings.value = [
      ...pendingBookings.value,
      {
        "fullName": fullNameController.text.trim(),
        "plate": plateController.text.trim().toUpperCase(),
        "vehicle": selectedVehicle,
        "queue": selectedQueueCode,
        "date": formattedDate,
        "status": "Pending",

        // File names
        "idFile": idFileName,
        "orFile": orFileName,
        "crFile": crFileName,

        // File paths for admin preview
        "idPath": idFilePath,
        "orPath": orFilePath,
        "crPath": crFilePath,
      }
    ];

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Appointment submitted successfully. Please wait for admin confirmation."),
      ),
    );

    Navigator.pop(context);
  }

  // ================= UPLOAD CARD =================

  Widget uploadCard({
    required String title,
    required String? fileName,
    required VoidCallback onPick,
    required VoidCallback onCamera,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.upload_file,
            size: 40,
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            fileName ?? "No file selected",
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.attach_file),
                  label: const Text("Choose File"),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Take Photo"),
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
    List<String> queueCodes = getQueueCodes();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // ================= DATE =================

            const Text(
              "Select Appointment Date",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickDate,
              child: Text(
                selectedDate == null ? "Choose Date" : formattedDate,
              ),
            ),

            const SizedBox(height: 25),

            // ================= FULL NAME =================

            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // ================= VEHICLE TYPE =================

            const Text(
              "Vehicle Type",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedVehicle,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Gas",
                  child: Text("Gas"),
                ),
                DropdownMenuItem(
                  value: "Diesel",
                  child: Text("Diesel"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedVehicle = value!;

                  if (selectedVehicle == "Gas") {
                    selectedQueueCode = "G001";
                  } else {
                    selectedQueueCode = "D001";
                  }
                });
              },
            ),

            const SizedBox(height: 25),

            // ================= AVAILABLE QUEUE CODES =================

            const Text(
              "Available Queue Codes",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (selectedDate == null)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey),
                ),
                child: const Text(
                  "Please choose an appointment date first.",
                  textAlign: TextAlign.center,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: queueCodes.map((code) {
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
                        width: 80,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: taken
                              ? Colors.grey.shade400
                              : selected
                                  ? Colors.black
                                  : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          taken ? "Taken" : code,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 25),

            // ================= PLATE NUMBER =================

            TextField(
              controller: plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Plate Number",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            // ================= VALID ID =================

            uploadCard(
              title: "Upload Valid ID",
              fileName: idFileName,
              onPick: () {
                pickDocument("ID");
              },
              onCamera: () {
                captureDocument("ID");
              },
            ),

            const SizedBox(height: 20),

            // ================= OR =================

            uploadCard(
              title: "Upload OR",
              fileName: orFileName,
              onPick: () {
                pickDocument("OR");
              },
              onCamera: () {
                captureDocument("OR");
              },
            ),

            const SizedBox(height: 20),

            // ================= CR =================

            uploadCard(
              title: "Upload CR",
              fileName: crFileName,
              onPick: () {
                pickDocument("CR");
              },
              onCamera: () {
                captureDocument("CR");
              },
            ),

            const SizedBox(height: 30),

            // ================= SUBMIT =================

            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: submitBooking,
                child: const Text("SUBMIT APPOINTMENT"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}