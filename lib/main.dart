import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart'; // Pastikan Anda sudah membuat widget login atau register

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Inisialisasi Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          AuthScreen(), // Ganti AuthService dengan widget yang menampilkan halaman login
    );
  }
}
