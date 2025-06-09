import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/sign_in_screen.dart'; // Mengarah ke SignInScreen sebagai halaman pertama

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Pastikan ini dijalankan sebelum aplikasi memulai
  await Firebase.initializeApp(); // Inisialisasi Firebase
  runApp(const PrelovedApp());
}

class PrelovedApp extends StatelessWidget {
  const PrelovedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Preloved App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SignInScreen(), // Halaman pertama SignInScreen
    );
  }
}
