import 'package:flutter/material.dart' hide Text;
import 'customer_login.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomerLogin();
  }
}
