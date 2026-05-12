import 'package:flutter/material.dart';

import 'admin_page.dart';
import 'ors_service.dart';
import 'location_data.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController queueController = TextEditingController();

  String statusText = "";
  String queueNumberText = "";
  String positionText = "";

  int? queuePosition;
  int? estimatedQueueTime;
  int? travelMinutes;
  int bufferMinutes = 5;
  int? leaveInMinutes;

  String municipalityText = "";
  String orsStatusText = "";
  String leaveAdviceText = "";
  String calculationText = "";

  bool isLoadingEta = false;

  final int averageServiceTime = 9;

  @override
  void dispose() {
    queueController.dispose();
    super.dispose();
  }

  // ================= CHECK QUEUE =================

  Future<void> checkQueue() async {
    String input = queueController.text.trim().toUpperCase();

    bool found = false;

    final regex = RegExp(r'^[GD]\d+$');

    if (!regex.hasMatch(input)) {
      setState(() {
        statusText = "Invalid Queue Format";
        queueNumberText = input;
        positionText = "Use format like G001 or D001";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });

      return;
    }

    // ================= WAITING QUEUE =================

    for (var customer in waitingQueueNotifier.value) {
      if (customer['queue'] == input) {
        found = true;

        int position = waitingQueueNotifier.value.indexOf(customer) + 1;

        int estimatedTime = position * averageServiceTime;

        setState(() {
          statusText = "Waiting";
          queueNumberText = input;
          positionText = "Position $position in line";
          queuePosition = position;
          estimatedQueueTime = estimatedTime;
          travelMinutes = null;
          leaveInMinutes = null;
          municipalityText = customer["municipality"] ?? "";
          orsStatusText = "";
          leaveAdviceText = "";
          calculationText = "";
        });

        if (customer["source"] == "Appointment" &&
            customer["municipality"] != null) {
          await calculateSmartEta(
            municipality: customer["municipality"],
            estimatedQueueTime: estimatedTime,
          );
        }

        if (position <= 5) {
          showNearTurnDialog();
        }

        break;
      }
    }

    // ================= NOW SERVING =================

    if (!found) {
      if (nowServingNotifier.value != null &&
          nowServingNotifier.value!['queue'] == input) {
        setState(() {
          statusText = "NOW SERVING";
          queueNumberText = input;
          positionText = "Please proceed to the testing area";
          queuePosition = null;
          estimatedQueueTime = null;
          travelMinutes = null;
          leaveInMinutes = null;
          municipalityText = "";
          orsStatusText = "";
          leaveAdviceText = "";
          calculationText = "";
        });

        found = true;
      }
    }

    // ================= MISSED QUEUE =================

    if (!found && nowServingNotifier.value != null) {
      String currentQueue = nowServingNotifier.value!['queue'];

      String currentPrefix = currentQueue.substring(0, 1);
      String userPrefix = input.substring(0, 1);

      if (currentPrefix == userPrefix) {
        int currentNumber = int.parse(currentQueue.substring(1));
        int userNumber = int.parse(input.substring(1));

        if (userNumber < currentNumber) {
          setState(() {
            statusText = "Sorry, you missed your queue.";
            queueNumberText = input;
            positionText = "Please coordinate with staff.";
            queuePosition = null;
            estimatedQueueTime = null;
            travelMinutes = null;
            leaveInMinutes = null;
            municipalityText = "";
            orsStatusText = "";
            leaveAdviceText = "";
            calculationText = "";
          });

          found = true;
        }
      }
    }

    // ================= NOT FOUND =================

    if (!found) {
      setState(() {
        statusText = "Queue not found";
        queueNumberText = input;
        positionText = "Please check your queue number.";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });
    }
  }

  // ================= SMART ETA =================

  Future<void> calculateSmartEta({
    required String municipality,
    required int estimatedQueueTime,
  }) async {
    setState(() {
      isLoadingEta = true;
      travelMinutes = null;
      leaveInMinutes = null;
      municipalityText = municipality;
      orsStatusText = "";
      leaveAdviceText = "";
      calculationText = "";
    });

    final location = getMunicipalityLocation(municipality);

    final result = await OrsService.getTravelTimeWithFallback(
      municipality: municipality,
      originLon: location.lon,
      originLat: location.lat,
    );

    int computedLeaveIn =
        estimatedQueueTime - (result.minutes + bufferMinutes);

    setState(() {
      isLoadingEta = false;

      travelMinutes = result.minutes;
      leaveInMinutes = computedLeaveIn;
      orsStatusText = result.message;

      if (computedLeaveIn <= 0) {
        leaveAdviceText =
            "Leave your house now. Your turn is estimated in $estimatedQueueTime mins.";
      } else {
        leaveAdviceText =
            "Leave your house in $computedLeaveIn mins. Your turn is estimated in $estimatedQueueTime mins.";
      }

      calculationText =
          "$estimatedQueueTime mins queue time - ${result.minutes} mins travel time - $bufferMinutes mins buffer = ${computedLeaveIn <= 0 ? 0 : computedLeaveIn} mins before leaving";
    });
  }

  // ================= ALERT =================

  void showNearTurnDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Queue Alert"),
        content: const Text(
          "Please prepare. Your turn is near.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ================= COLOR HELPERS =================

  Color getAdviceColor() {
    if (leaveInMinutes == null) return Colors.teal;

    if (leaveInMinutes! <= 0) {
      return Colors.red;
    }

    if (leaveInMinutes! <= 10) {
      return Colors.orange;
    }

    return Colors.teal;
  }

  IconData getAdviceIcon() {
    if (leaveInMinutes == null) return Icons.notifications_active;

    if (leaveInMinutes! <= 0) {
      return Icons.warning_amber_rounded;
    }

    if (leaveInMinutes! <= 10) {
      return Icons.directions_walk;
    }

    return Icons.notifications_active;
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),
      appBar: AppBar(
        title: const Text("Track Queue"),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = constraints.maxWidth >= 700;

            return ListView(
              padding: EdgeInsets.all(wide ? 24 : 16),
              children: [
                buildNowServingCard(),

                const SizedBox(height: 18),

                buildSearchCard(),

                const SizedBox(height: 18),

                if (statusText.isNotEmpty) buildQueueStatusCard(),

                if (estimatedQueueTime != null) ...[
                  const SizedBox(height: 14),
                  buildTimeSummaryCard(),
                ],

                if (isLoadingEta)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),

                if (orsStatusText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  buildInfoNote(orsStatusText),
                ],

                if (leaveAdviceText.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  buildLeaveAdviceCard(),
                ],

                if (calculationText.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  buildCalculationCard(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ================= NOW SERVING =================

  Widget buildNowServingCard() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: nowServingNotifier,
      builder: (context, customer, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: cardDecoration(),
          child: Column(
            children: [
              const Text(
                "NOW SERVING",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black54,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  customer == null ? "-" : customer['queue'],
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= SEARCH CARD =================

  Widget buildSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Enter your queue number",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: queueController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: "Queue Number",
              hintText: "Example: G001 or D001",
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.confirmation_number),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isLoadingEta ? null : checkQueue,
              icon: const Icon(Icons.search),
              label: const Text("CHECK STATUS"),
            ),
          ),
        ],
      ),
    );
  }

  // ================= QUEUE STATUS CARD =================

  Widget buildQueueStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.format_list_numbered,
            title: "Queue Status",
          ),
          const SizedBox(height: 14),
          infoRow(
            label: "Queue Number",
            value: queueNumberText.isEmpty ? "-" : queueNumberText,
          ),
          infoRow(
            label: "Status",
            value: statusText,
          ),
          infoRow(
            label: "Position",
            value: positionText,
          ),
        ],
      ),
    );
  }

  // ================= TIME SUMMARY CARD =================

  Widget buildTimeSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.timer,
            title: "Time Summary",
          ),
          const SizedBox(height: 14),

          timeItem(
            icon: Icons.schedule,
            title: "Estimated Queue Time",
            value: "${estimatedQueueTime ?? 0} mins",
            subtitle:
                "Based on position ${queuePosition ?? '-'} × $averageServiceTime mins per customer",
            color: Colors.green,
          ),

          if (municipalityText.isNotEmpty && travelMinutes != null) ...[
            const SizedBox(height: 10),
            timeItem(
              icon: Icons.directions_car,
              title: "Travel Time",
              value: "$travelMinutes mins",
              subtitle: "From $municipalityText to NPJN",
              color: Colors.purple,
            ),
            const SizedBox(height: 10),
            timeItem(
              icon: Icons.add_alarm,
              title: "Safety Buffer",
              value: "$bufferMinutes mins",
              subtitle: "Allowance for parking, traffic, and preparation",
              color: Colors.blueGrey,
            ),
          ],
        ],
      ),
    );
  }

  // ================= LEAVE ADVICE CARD =================

  Widget buildLeaveAdviceCard() {
    final color = getAdviceColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            getAdviceIcon(),
            color: color,
            size: 38,
          ),
          const SizedBox(height: 10),
          const Text(
            "SMART LEAVE ADVICE",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black54,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            leaveAdviceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ================= CALCULATION CARD =================

  Widget buildCalculationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.calculate,
            title: "How This Was Calculated",
          ),
          const SizedBox(height: 14),
          calculationLine(
            label: "Queue waiting time",
            value: "${estimatedQueueTime ?? 0} mins",
            icon: Icons.schedule,
          ),
          calculationLine(
            label: "Minus travel time",
            value: "- ${travelMinutes ?? 0} mins",
            icon: Icons.directions_car,
          ),
          calculationLine(
            label: "Minus safety buffer",
            value: "- $bufferMinutes mins",
            icon: Icons.add_alarm,
          ),
          const Divider(height: 22),
          calculationLine(
            label: "Recommended leave time",
            value:
                "${(leaveInMinutes ?? 0) <= 0 ? 0 : leaveInMinutes} mins",
            icon: Icons.notifications_active,
            bold: true,
          ),
          const SizedBox(height: 8),
          Text(
            calculationText,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ================= SMALL WIDGETS =================

  Widget sectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ],
    );
  }

  Widget infoRow({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget timeItem({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(
              icon,
              color: color,
              size: 20,
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
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget calculationLine({
    required String label,
    required String value,
    required IconData icon,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.black54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
              color: bold ? getAdviceColor() : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoNote(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.blueGrey.withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.black54,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.black.withOpacity(0.04),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 10,
        ),
      ],
    );
  }
}