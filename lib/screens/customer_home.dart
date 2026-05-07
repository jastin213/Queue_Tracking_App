import 'package:flutter/material.dart';
import 'track_page.dart';
import 'book_appointment.dart';

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Home"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text(
                  "TRACK MY QUEUE",
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrackPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: const Text(
                  "BOOK APPOINTMENT",
                ),
               
               onPressed: () {
   Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const BookAppointment(),
    ),
  );
},


              ),
            ),
          ],
        ),
      ),
    );
  }
}