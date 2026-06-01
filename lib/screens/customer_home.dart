import 'package:flutter/material.dart';
import 'track_page.dart';
import 'book_appointment.dart';
import 'booking_status_page.dart';
import 'customer_register.dart';

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        foregroundColor: _primaryColor,
        title: const Text(
          "Customer Home",
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: loggedInCustomerNameNotifier,
                builder: (context, name, _) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.08),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 58,
                          width: 58,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name.isEmpty
                              ? "NPJN Emission Testing Center"
                              : "Welcome, $name",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Book your emission test appointment, track your queue number, and check your Appointment confirmation.",
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.5,
                            color: _mutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              const Text(
                "What would you like to do?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 14),

              _ActionCard(
                icon: Icons.search_rounded,
                title: "Track My Queue",
                subtitle:
                    "Check your queue position and estimated waiting time.",
                isFilled: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrackPage()),
                  );
                },
              ),

              const SizedBox(height: 16),

              _ActionCard(
                icon: Icons.calendar_month_rounded,
                title: "Book Appointment",
                subtitle:
                    "Schedule your emission test before visiting the center.",
                isFilled: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookAppointment()),
                  );
                },
              ),

              const SizedBox(height: 16),

              _ActionCard(
                icon: Icons.notifications_active_rounded,
                title: "My Appointment Status",
                subtitle:
                    "Check if your appointment is pending, approved, or rejected.",
                isFilled: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookingStatusPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.05),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Services Offered",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.directions_car_rounded,
                      text: "Gasoline Vehicle Emission Test",
                    ),
                    SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.local_shipping_rounded,
                      text: "Diesel Vehicle Emission Test",
                    ),
                    SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.confirmation_number_rounded,
                      text: "Queue and Appointment Assistance",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _primaryColor.withOpacity(0.12)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Center Information",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      text: "Ligao City, Albay",
                    ),
                    SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      text: "Monday to Saturday",
                    ),
                    SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.groups_rounded,
                      text: "Daily queue limit: 80 customers",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFilled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isFilled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isFilled ? _primaryColor : _cardColor;
    final Color titleColor = isFilled ? Colors.white : _primaryColor;
    final Color subtitleColor = isFilled ? Colors.white70 : _mutedTextColor;
    final Color iconBackgroundColor = isFilled
        ? Colors.white.withOpacity(0.14)
        : _primaryColor.withOpacity(0.08);
    final Color iconColor = isFilled ? Colors.white : _primaryColor;
    final Color arrowColor = isFilled
        ? Colors.white70
        : _primaryColor.withOpacity(0.45);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(24),
      elevation: isFilled ? 4 : 2,
      shadowColor: _primaryColor.withOpacity(0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFilled ? _primaryColor : _primaryColor,
              width: isFilled ? 0 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: _primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              color: _mutedTextColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}