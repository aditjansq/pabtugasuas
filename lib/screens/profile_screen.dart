import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pabtugasuas/screens/sign_in_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  bool _isEditingName = false;
  bool _isLoading = false;

  final User? _user = FirebaseAuth.instance.currentUser; // Jangan deklarasikan ulang

  @override
  void initState() {
    super.initState();
    fetchUserData(); // Memanggil fungsi untuk mengambil data pengguna
  }

  @override
  void dispose() {
    // Pastikan controller dibersihkan saat widget di-unmount
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil data pengguna dari Firestore
  Future<void> fetchUserData() async {
    if (_user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid) // Menggunakan _user yang sudah ada
            .get();

        if (doc.exists) {
          setState(() {
            _nameController.text = doc['fullname']; // Ambil fullname dari Firestore
          });
        } else {
          print('No user data found');
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
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

  // Fungsi untuk mengganti password
  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      _showErrorMessage('New passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Dapatkan password lama
      final String currentPassword = _currentPasswordController.text;
      final String newPassword = _newPasswordController.text;

      // Verifikasi password lama
      AuthCredential credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: currentPassword,
      );

      await _user!.reauthenticateWithCredential(credential);

      // Ubah password
      await _user!.updatePassword(newPassword);
      await _user!.reload();

      // Membersihkan text field setelah password berhasil diubah
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();

      _showErrorMessage('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      _showErrorMessage('Error: ${e.message}');
    } catch (e) {
      _showErrorMessage('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Menampilkan pesan kesalahan kepada pengguna
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView( // Membungkus seluruh tampilan dengan SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: _user == null
            ? const Center(child: Text('No user found.'))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${_user!.email}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),

            // Tampilkan Full Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Full Name:', style: TextStyle(fontSize: 18)),
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
                        // Update fullname di Firestore
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(_user!.uid)
                            .update({
                          'fullname': _nameController.text
                        });
                      },
                    ),
                  ],
                )
                    : Text(
                    _nameController.text.isEmpty
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

            // Input untuk Ganti Password
            const Text('Change Password:', style: TextStyle(fontSize: 18)),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmNewPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
            const SizedBox(height: 20),

            // Tombol untuk mengganti password
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _changePassword,
              child: const Text('Change Password'),
            ),
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
