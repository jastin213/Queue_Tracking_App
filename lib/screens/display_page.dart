import 'package:flutter/material.dart';
import 'admin_page.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 50),

            const Text(
              "NPJN EMISSION CENTER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 50),

            const Text(
              "NOW SERVING",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 24,
              ),
            ),

            const SizedBox(height: 20),

            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: nowServingNotifier,
              builder: (context, customer, _) {
                return Text(
                  customer == null ? "-" : customer['queue'],
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 90,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),

            const SizedBox(height: 50),

            const Text(
              "NEXT IN LINE",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ValueListenableBuilder<
                  List<Map<String, dynamic>>>(
                valueListenable: waitingQueueNotifier,
                builder: (context, queueList, _) {
                  return ListView.builder(
                    itemCount: queueList.length,
                    itemBuilder: (context, index) {
                      final customer = queueList[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          customer['queue'],
                          style: const TextStyle(fontSize: 24),
                        ),
                      );
                    },
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