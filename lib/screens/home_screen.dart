import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pabtugasuas/widgets/item_card.dart'; // Pastikan path sesuai dengan struktur foldermu
import 'package:pabtugasuas/screens/search_screen.dart';
import 'package:pabtugasuas/screens/add_sell_screen.dart';
import 'package:pabtugasuas/screens/chat_screen.dart';
import 'package:pabtugasuas/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  // Fungsi untuk mengubah halaman berdasarkan pilihan BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Daftar halaman yang akan ditampilkan berdasarkan pilihan BottomNavigationBar
  final List<Widget> _screens = [
    HomeContent(), // Home Content page
    SearchScreen(), // Search Screen
    AddSellScreen(), // Add Sell Screen
    ChatScreen(), // Chat Screen
    ProfileScreen(), // Profile Screen
  ];

  @override
  void initState() {
    super.initState();
    // Simulasikan penundaan pengambilan data (misalnya, untuk testing)
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isLoading = false; // Setelah data selesai, set _isLoading ke false
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preloved - Home'),
      ),
      body: _screens[
          _selectedIndex], // Tampilkan halaman berdasarkan tab yang dipilih
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.blue, // Latar belakang BottomNavigationBar
        selectedItemColor: Colors.white, // Warna item yang terpilih
        unselectedItemColor: Colors.grey, // Warna item yang tidak terpilih
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Sell',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Halaman konten untuk Home, menggunakan StreamBuilder untuk mendapatkan data produk
class HomeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No items available.'));
        }
        final items = snapshot.data!.docs;
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index].data();
            return ItemCard(
              itemName: item['itemName'],
              description: item['description'],
              price: double.tryParse(item['price'].toString()) ??
                  0.0, // Mengonversi String ke Double
            );
          },
        );
      },
    );
  }
}
