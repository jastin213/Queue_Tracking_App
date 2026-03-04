import 'package:flutter/material.dart';

List<String> globalQueue = [];
int currentServingIndex = -1;
int averageServiceTime = 6; // minutes per vehicle

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  void addQueue() {
    setState(() {
      String queueNumber = "A${globalQueue.length + 1}";
      globalQueue.add(queueNumber);
    });
  }

  void serveNext() {
    if (globalQueue.isNotEmpty) {
      setState(() {
        currentServingIndex++;
        globalQueue.removeAt(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Queue Control")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // NOW SERVING
            Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "NOW SERVING",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentServingIndex < 0
                          ? "No one yet"
                          : "A${currentServingIndex + 1}",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: addQueue,
              child: const Text("Add Customer"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: serveNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Serve Next"),
            ),

            const SizedBox(height: 20),
            const Text(
              "Waiting List",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: globalQueue.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(globalQueue[index]),
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