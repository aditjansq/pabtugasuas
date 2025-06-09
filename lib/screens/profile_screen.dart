import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pabtugasuas/screens/sign_in_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isLoading = false;

  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    fetchUserDataWithRetry(); // Memanggil fungsi fetch data dengan retry saat ProfileScreen pertama kali dimuat
  }

  @override
  void dispose() {
    // Pastikan controller dibersihkan saat widget di-unmount
    _nameController.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil data pengguna dari Firestore dengan retry
  Future<void> fetchUserDataWithRetry() async {
    const maxRetries = 3;
    int retries = 0;
    bool success = false;

    while (retries < maxRetries && !success) {
      try {
        if (_user != null) {
          // Mengambil data pengguna dari Firestore
          var doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_user!.uid)
              .get();

          if (doc.exists) {
            // Proses data jika berhasil
            if (mounted) {
              // Pastikan widget masih ada sebelum melakukan setState
              setState(() {
                _nameController.text = doc['fullName'];
                success = true;
              });
            }
          } else {
            throw 'User data not found in Firestore.';
          }
        } else {
          throw 'No user logged in.';
        }
      } catch (e) {
        retries++;
        if (retries < maxRetries) {
          print(
              'Attempt $retries failed. Retrying in ${retries * 2} seconds...');
          await Future.delayed(
              Duration(seconds: retries * 2)); // Retry setelah beberapa detik
        } else {
          print('Failed to fetch user data after $maxRetries attempts.');
          if (mounted) {
            showErrorMessage(
                'Failed to load user data. Please try again later.');
          }
        }
      }
    }
  }

  // Menampilkan pesan kesalahan kepada pengguna
  void showErrorMessage(String message) {
    // Pastikan widget masih ada sebelum menampilkan pesan error
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Fungsi untuk logout
  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (route) => false,
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile - Preloved')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _user == null
            ? const Center(child: Text('No user found.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${_user!.email}',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 20),

                  // Ganti Nama
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Name:', style: const TextStyle(fontSize: 18)),
                      _isEditingName
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 200,
                                  child: TextField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                        labelText: 'Enter new name'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingName = false;
                                    });
                                  },
                                ),
                              ],
                            )
                          : Text(_nameController.text.isEmpty
                              ? 'No name set'
                              : _nameController.text),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tombol untuk mengganti nama
                  !_isEditingName
                      ? ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isEditingName = true;
                            });
                          },
                          child: const Text('Edit Name'),
                        )
                      : const SizedBox.shrink(),

                  const SizedBox(height: 20),

                  // Tombol logout
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _logout,
                          child: const Text('Logout'),
                        ),
                ],
              ),
      ),
    );
  }
}
