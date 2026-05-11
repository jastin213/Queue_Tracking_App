import 'package:flutter/material.dart';
import 'admin_page.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 900;
            final bool isShort = constraints.maxHeight < 700;

            final double pagePadding = isWide ? 32 : 16;
            final double headerHeight = isShort ? 80 : 105;
            final double nowServingHeight = isShort ? 250 : 330;
            final double nextLineHeight = isShort ? 190 : 260;

            final double titleSize = isWide ? 30 : 22;
            final double queueFontSize = isWide ? 110 : 76;

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  children: [
                    // ================= HEADER =================

                    Container(
                      width: double.infinity,
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 227, 242, 248),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              size: 32,
                              color: Colors.black,
                            ),
                          ),

                          const SizedBox(width: 18),

                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "NPJN EMISSION CENTER",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isShort ? 18 : 28),

                    // ================= NOW SERVING =================

                    Container(
                      width: double.infinity,
                      height: nowServingHeight,
                      padding: EdgeInsets.all(isShort ? 18 : 26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.25),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "NOW SERVING",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),

                          SizedBox(height: isShort ? 14 : 22),

                          Expanded(
                            child: ValueListenableBuilder<Map<String, dynamic>?>(
                              valueListenable: nowServingNotifier,
                              builder: (context, customer, _) {
                                return Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                            255,
                                            255,
                                            238,
                                            238,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(26),
                                          border: Border.all(
                                            color: Colors.red,
                                            width: 3,
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            customer == null
                                                ? "-"
                                                : customer['queue'],
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: queueFontSize,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    SizedBox(
                                      height: isShort ? 26 : 36,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          customer == null
                                              ? "Please wait for your queue number"
                                              : customer['name'] ?? "",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isShort ? 18 : 28),

                    // ================= NEXT IN LINE =================

                    Container(
                      width: double.infinity,
                      height: nextLineHeight,
                      padding: EdgeInsets.all(isShort ? 16 : 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.groups,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "NEXT IN LINE",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Expanded(
                            child: ValueListenableBuilder<
                                List<Map<String, dynamic>>>(
                              valueListenable: waitingQueueNotifier,
                              builder: (context, queueList, _) {
                                if (queueList.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      "No waiting queue",
                                      style: TextStyle(
                                        color: Colors.black45,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }

                                final visibleList = queueList.take(8).toList();

                                return GridView.builder(
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: visibleList.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isWide ? 4 : 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: isWide ? 3.3 : 2.5,
                                  ),
                                  itemBuilder: (context, index) {
                                    final customer = visibleList[index];

                                    return Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                          255,
                                          245,
                                          250,
                                          252,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          customer['queue'],
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
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

                    SizedBox(height: isShort ? 14 : 20),

                    const Text(
                      "Please stay alert and proceed when your queue number is called.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}