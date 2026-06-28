import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/landing_page.dart';

void main() {
  runApp(const CryptostratApp());
}

class CryptostratApp extends StatelessWidget {
  const CryptostratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cryptostrat',
      debugShowCheckedModeBanner: false,
      theme: buildCryptostratTheme(),
      home: const LandingPage(),
    );
  }
}
