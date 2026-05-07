import 'package:flutter/material.dart';

// ================= GLOBAL BOOKING STORAGE =================

ValueNotifier<List<Map<String, dynamic>>> pendingBookings =
    ValueNotifier([]);

ValueNotifier<List<Map<String, dynamic>>> approvedBookings =
    ValueNotifier([]);

ValueNotifier<List<Map<String, dynamic>>> rejectedBookings =
    ValueNotifier([]);

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

  String selectedSlot = "8:00 AM";
  String selectedVehicle = "Gas";

  // ================= SLOT LIST =================

  final List<String> slots = [
    "8:00 AM",
    "9:00 AM",
    "10:00 AM",
    "11:00 AM",
    "1:00 PM",
    "2:00 PM",
    "3:00 PM",
    "4:00 PM",
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

  // ================= SUBMIT BOOKING =================

  void submitBooking() {
    if (selectedDate == null ||
        plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complete all fields"),
        ),
      );

      return;
    }

    pendingBookings.value = [
      ...pendingBookings.value,

      {
        "plate": plateController.text,
        "vehicle": selectedVehicle,
        "slot": selectedSlot,
        "date":
            "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}",
        "status": "Pending",
      }
    ];

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Appointment Submitted Successfully",
        ),
      ),
    );

    Navigator.pop(context);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
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
              "Select Slot",
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

            // ================= UPLOAD ID =================

            Container(
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey,
                ),

                borderRadius:
                    BorderRadius.circular(15),
              ),

              child: Column(
                children: [
                  const Icon(Icons.upload_file),

                  const SizedBox(height: 10),

                  const Text("Upload Valid ID"),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: () {},
                    child: const Text(
                      "Choose File",
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ================= UPLOAD OR/CR =================

            Container(
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey,
                ),

                borderRadius:
                    BorderRadius.circular(15),
              ),

              child: Column(
                children: [
                  const Icon(Icons.upload_file),

                  const SizedBox(height: 10),

                  const Text("Upload OR/CR"),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: () {},
                    child: const Text(
                      "Choose File",
                    ),
                  ),
                ],
              ),
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