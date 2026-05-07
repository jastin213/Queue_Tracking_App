import 'package:flutter/material.dart';
import 'book_appointment.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking History"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: ListView(
          children: [
            const Text(
              "Approved Bookings",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...approvedBookings.value.map((booking) {
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),

                  title: Text(
                    booking['plate'],
                  ),

                  subtitle: Text(
                    "${booking['vehicle']} • ${booking['date']} • ${booking['slot']}",
                  ),
                ),
              );
            }),

            const SizedBox(height: 25),

            const Text(
              "Rejected Bookings",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...rejectedBookings.value.map((booking) {
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.cancel,
                    color: Colors.red,
                  ),

                  title: Text(
                    booking['plate'],
                  ),

                  subtitle: Text(
                    "${booking['vehicle']} • ${booking['date']} • ${booking['slot']}",
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}