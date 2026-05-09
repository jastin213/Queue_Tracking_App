import 'package:flutter/material.dart';
import 'admin_page.dart'; // Or wherever dailyHistoryNotifier is

class DailyReport extends StatelessWidget {
  const DailyReport({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daily Report")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<Map<String, List<String>>>(
          valueListenable: dailyHistoryNotifier,
          builder: (context, history, _) {
            if (history.isEmpty) return const Center(child: Text("No records yet."));
            final sortedDates = history.keys.toList()
              ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)))
              ..reversed;
            return ListView(
              children: sortedDates.map((date) {
                final servedList = history[date] ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$date: ${servedList.length} served",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: servedList.map((q) => Chip(label: Text(q))).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}