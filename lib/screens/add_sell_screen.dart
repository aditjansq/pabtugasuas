import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // Image package for compression
import 'package:geolocator/geolocator.dart'; // Geolocator untuk mendapatkan lokasi
import 'package:geocoding/geocoding.dart'; // Untuk reverse geocoding

// Mengimpor data pilihan dari file data.dart
import 'package:pabtugasuas/data.dart'; // Sesuaikan path dengan struktur folder Anda

class AddSellScreen extends StatefulWidget {
  const AddSellScreen({super.key});

  @override
  _AddSellScreenState createState() => _AddSellScreenState();
}

class _AddSellScreenState extends State<AddSellScreen> {
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  bool _isLoading = false;
  List<XFile>? _imageFiles = []; // List untuk menyimpan banyak gambar

  String? _selectedCategory;
  String? _selectedSize;
  String? _selectedBrand;
  String? _selectedStyle;
  String? _selectedCondition;
  String? _selectedColor;
  String? _selectedMaterial;

  double? _latitude; // Latitude dari lokasi pengguna
  double? _longitude; // Longitude dari lokasi pengguna
  String? selectedAddress; // Alamat pengguna berdasarkan koordinat

  // Fungsi untuk mendapatkan lokasi pengguna
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        selectedAddress = null;
      });
      await _updateAddress(_latitude!, _longitude!);
    } catch (e) {
      print("Gagal mendapatkan lokasi: $e");
    }
  }

  // Fungsi untuk mengecek izin lokasi dan mendapatkan lokasi
  Future<void> _checkLocationPermissionAndGetLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Izin lokasi ditolak');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print('Izin lokasi ditolak permanen');
      return;
    }
    _getCurrentLocation();
  }

  // Fungsi untuk mendapatkan alamat berdasarkan koordinat
  Future<void> _updateAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        setState(() {
          selectedAddress = address;
        });
      } else {
        setState(() {
          selectedAddress = 'Alamat tidak ditemukan';
        });
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
      setState(() {
        selectedAddress = 'Gagal mendapatkan alamat';
      });
    }
  }

  // Fungsi untuk menambahkan item ke Firestore
  Future<void> _addItem() async {
    final String itemName = _itemNameController.text.trim();
    final String description = _descriptionController.text.trim();
    final String price = _priceController.text.trim();

    if (itemName.isEmpty || description.isEmpty || price.isEmpty || _selectedCategory == null || _selectedSize == null || _selectedBrand == null || _selectedStyle == null || _selectedCondition == null || _selectedColor == null || _selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String?> encodedImages = [];
      if (_imageFiles != null && _imageFiles!.isNotEmpty) {
        // Compress and encode images to base64
        for (var imageFile in _imageFiles!) {
          String? encodedImage = await compressAndEncodeImage(imageFile);
          if (encodedImage != null) {
            encodedImages.add(encodedImage);
          }
        }
      }

      // Menambahkan produk ke Firestore dengan ID otomatis
      await FirebaseFirestore.instance.collection('products').add({
        'itemName': itemName,
        'description': description,
        'price': double.tryParse(price) ?? 0.0,
        'category': _selectedCategory,
        'size': _selectedSize,
        'brand': _selectedBrand,
        'style': _selectedStyle,
        'condition': _selectedCondition,
        'colors': _selectedColor,
        'material': _selectedMaterial,
        'createdAt': Timestamp.now(),
        'images': encodedImages, // Array image base64 data
        'location': {
          'latitude': _latitude,
          'longitude': _longitude,
          'address': selectedAddress,
        }, // Lokasi item
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully!')),
      );

      // Reset field setelah item ditambahkan
      _itemNameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _imageFiles = []; // Reset the images
        _selectedCategory = null;
        _selectedSize = null;
        _selectedBrand = null;
        _selectedStyle = null;
        _selectedCondition = null;
        _selectedColor = null;
        _selectedMaterial = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk memilih gambar dari galeri (multiple images)
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage(); // Mendukung memilih banyak gambar

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        // Menambahkan gambar yang dipilih ke dalam list gambar yang ada
        _imageFiles?.addAll(pickedFiles);
      });
    }
  }

  // Fungsi untuk mengkompres dan mengubah gambar menjadi base64
  Future<String?> compressAndEncodeImage(
    XFile imageFile, {
    int maxWidth = 400,
    int quality = 70,
  }) async {
    final bytes = await File(imageFile.path).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    img.Image resized = img.copyResize(image, width: maxWidth);
    List<int> jpg = img.encodeJpg(resized, quality: quality);

    // Pastikan ukuran di bawah 900KB (batas aman Firestore)
    if (jpg.length > 900 * 1024) {
      return null;
    }

    return base64Encode(jpg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Sell')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _itemNameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              // Dropdown for Category
              DropdownButton<String>(
                value: _selectedCategory,
                hint: const Text('Select Category'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                items: categories.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Dropdown for Size
              DropdownButton<String>(
                value: _selectedSize,
                hint: const Text('Select Size'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedSize = newValue;
                  });
                },
                items: sizes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Dropdown for Brand
              DropdownButton<String>(
                value: _selectedBrand,
                hint: const Text('Select Brand'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedBrand = newValue;
                  });
                },
                items: brands.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Dropdown for Style
              DropdownButton<String>(
                value: _selectedStyle,
                hint: const Text('Select Style'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedStyle = newValue;
                  });
                },
                items: styles.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Dropdown for Condition
              DropdownButton<String>(
                value: _selectedCondition,
                hint: const Text('Select Condition'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCondition = newValue;
                  });
                },
                items: conditions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Dropdown for Color
              DropdownButton<String>(
                value: _selectedColor,
                hint: const Text('Select Color'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedColor = newValue;
                  });
                },
                items: colors.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              // Dropdown for Material
              DropdownButton<String>(
                value: _selectedMaterial,
                hint: const Text('Select Material'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedMaterial = newValue;
                  });
                },
                items: materials.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // Image Picker Section
              ElevatedButton(
                onPressed: _pickImages,
                child: const Text('Pick Images'),
              ),
              if (_imageFiles != null && _imageFiles!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  children: _imageFiles!.map((file) {
                    return Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.file(File(file.path), height: 100, width: 100),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _addItem, // Menambahkan produk
                      child: const Text('Add Item'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
