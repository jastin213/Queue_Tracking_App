import 'package:flutter/material.dart';
import 'track_page.dart';
import 'customer_login.dart';

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

class CustomerPortal extends StatelessWidget {
  const CustomerPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _primaryColor,
          onPrimary: Colors.white,
          surface: _cardColor,
          onSurface: _primaryColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                // TOP BAR
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Customer Portal",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 45),

                // HEADER ICON
                Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.16),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  "Welcome",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Choose an option below.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, color: _mutedTextColor),
                ),

                const SizedBox(height: 32),

                // MAIN CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.08),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _PortalButton(
                        icon: Icons.search_rounded,
                        label: "Track My Queue",
                        isFilled: true,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrackPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      _PortalButton(
                        icon: Icons.person_add_alt_1_rounded,
                        label: "Login / Create Account",
                        isFilled: false,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerLogin(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  "NPJN Emission Testing Center",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isFilled;
  final VoidCallback onPressed;

  const _PortalButton({
    required this.icon,
    required this.label,
    required this.isFilled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isFilled ? _primaryColor : _cardColor;
    final Color textColor = isFilled ? Colors.white : _primaryColor;
    final Color iconBackgroundColor = isFilled
        ? Colors.white.withOpacity(0.14)
        : _softPrimaryColor;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(22),
      elevation: isFilled ? 4 : 1,
      shadowColor: _primaryColor.withOpacity(0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _primaryColor, width: isFilled ? 0 : 1.5),
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: textColor, size: 26),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: isFilled ? Colors.white70 : _primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}