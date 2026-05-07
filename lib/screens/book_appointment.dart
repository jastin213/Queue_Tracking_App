import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

// ================= GLOBAL BOOKING STORAGE =================

ValueNotifier<List<Map<String, dynamic>>> pendingBookings =
    ValueNotifier([]);

ValueNotifier<List<Map<String, dynamic>>> approvedBookings =
    ValueNotifier([]);

ValueNotifier<List<Map<String, dynamic>>> rejectedBookings =
    ValueNotifier([]);

// ================= BOOK APPOINTMENT =================

class BookAppointment extends StatefulWidget {
  const BookAppointment({super.key});

  @override
  State<BookAppointment> createState() =>
      _BookAppointmentState();
}

class _BookAppointmentState
    extends State<BookAppointment> {
  // ================= CONTROLLERS =================

  final TextEditingController plateController =
      TextEditingController();

  DateTime? selectedDate;

  String selectedSlot = "Slot 1";

  String selectedVehicle = "Gas";

  // ================= FILES =================

  File? validIdFile;

  File? orFile;

  File? crFile;

  // ================= IMAGE PICKER =================

  final ImagePicker picker = ImagePicker();

  // ================= SLOT LIST =================

  final List<String> slots = [
    "Slot 1",
    "Slot 2",
    "Slot 3",
    "Slot 4",
    "Slot 5",
    "Slot 6",
    "Slot 7",
    "Slot 8",
    "Slot 9",
    "Slot 10",
  ];

  // ================= PICK DATE =================

  Future pickDate() async {
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

  // ================= PICK VALID ID =================

  Future pickValidId() async {
    final XFile? image =
        await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      setState(() {
        validIdFile = File(image.path);
      });
    }
  }

  // ================= PICK DOCUMENT =================

  Future pickDocument(String type) async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(
        result.files.single.path!,
      );

      setState(() {
        if (type == "OR") {
          orFile = file;
        } else {
          crFile = file;
        }
      });
    }
  }

  // ================= SUBMIT BOOKING =================

  void submitBooking() {
    // ================= VALIDATION =================

    if (selectedDate == null ||
        plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Complete all fields",
          ),
        ),
      );

      return;
    }

    // ================= FILE VALIDATION =================

    if (validIdFile == null ||
        orFile == null ||
        crFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please upload all required documents.",
          ),
        ),
      );

      return;
    }

    // ================= DUPLICATE SLOT CHECK =================

    bool slotTaken = pendingBookings.value.any(
      (booking) =>
          booking['date'] ==
              "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}" &&
          booking['slot'] == selectedSlot,
    );

    if (slotTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Selected queue slot is already taken.",
          ),
        ),
      );

      return;
    }

    // ================= SAVE BOOKING =================

    pendingBookings.value = [
      ...pendingBookings.value,

      {
        "plate": plateController.text,
        "vehicle": selectedVehicle,
        "slot": selectedSlot,

        "date":
            "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}",

        "status": "Pending",

        "validId": validIdFile,
        "orFile": orFile,
        "crFile": crFile,
      }
    ];

    // ================= SUCCESS =================

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Appointment Submitted Successfully",
        ),
      ),
    );

    Navigator.pop(context);
  }

  // ================= UPLOAD CARD =================

  Widget uploadCard({
    required String title,
    required File? file,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(15),

        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  file == null
                      ? "No file selected"
                      : file.path
                          .split('/')
                          .last,

                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),

              ElevatedButton(
                onPressed: onPressed,

                child: const Text(
                  "Choose File",
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Book Appointment",
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: ListView(
          children: [
            // ================= DATE =================

            const Text(
              "Select Date",

              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickDate,

              child: Text(
                selectedDate == null
                    ? "Choose Date"
                    : "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}",
              ),
            ),

            const SizedBox(height: 20),

            // ================= SLOT =================

            const Text(
              "Available Queue Slot",

              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField(
              value: selectedSlot,

              items: slots.map((slot) {
                return DropdownMenuItem(
                  value: slot,
                  child: Text(slot),
                );
              }).toList(),

              onChanged: (value) {
                setState(() {
                  selectedSlot = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            // ================= VEHICLE =================

            const Text(
              "Vehicle Type",

              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField(
              value: selectedVehicle,

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
                });
              },
            ),

            const SizedBox(height: 20),

            // ================= PLATE NUMBER =================

            TextField(
              controller: plateController,

              decoration: const InputDecoration(
                labelText: "Plate Number",

                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // ================= VALID ID =================

            uploadCard(
              title: "Upload Valid ID",

              file: validIdFile,

              onPressed: pickValidId,
            ),

            const SizedBox(height: 15),

            // ================= OR =================

            uploadCard(
              title: "Upload OR",

              file: orFile,

              onPressed: () {
                pickDocument("OR");
              },
            ),

            const SizedBox(height: 15),

            // ================= CR =================

            uploadCard(
              title: "Upload CR",

              file: crFile,

              onPressed: () {
                pickDocument("CR");
              },
            ),

            const SizedBox(height: 30),

            // ================= SUBMIT =================

            SizedBox(
              height: 55,

              child: ElevatedButton(
                onPressed: submitBooking,

                child: const Text(
                  "SUBMIT APPOINTMENT",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}