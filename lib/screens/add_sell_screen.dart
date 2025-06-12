import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:pabtugasuas/data.dart';  // Import the data.dart where categories and other data are stored

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
  List<XFile>? _imageFiles = [];

  String? _selectedCategory;
  String? _selectedStyle;
  String? _selectedCondition;
  String? _selectedColor;
  String? _selectedMaterial;

  List<String> styles = [];
  List<String> conditions = [];
  List<String> colors = [];
  List<String> materials = [];

  double? _latitude;
  double? _longitude;
  String? selectedAddress;

  // Initialize categories and the subcategory-based options for styles, conditions, colors, materials
  void _setOptions(String category) {
    // Reset the values to null every time category is changed
    _selectedStyle = null;
    _selectedCondition = null;
    _selectedColor = null;
    _selectedMaterial = null;

    // Clear the options for styles, conditions, etc.
    styles = [];
    conditions = [];
    colors = [];
    materials = [];

    if (category == 'Pakaian') {
      styles = ['Casual', 'Streetwear'];
      conditions = ['New', 'Used'];
      colors = ['Red', 'Blue', 'Black'];
      materials = ['Cotton', 'Leather'];
    } else if (category == 'Sepatu') {
      styles = ['Sporty', 'Casual'];
      conditions = ['New', 'Used'];
      colors = ['Black', 'White'];
      materials = ['Canvas', 'Leather'];
    } else if (category == 'Tas dan Aksesori') {
      styles = ['Casual', 'Formal'];
      conditions = ['New', 'Used'];
      colors = ['Black', 'Brown', 'White'];
      materials = ['Leather', 'Canvas'];
    } else if (category == 'Buku Bekas') {
      conditions = ['New', 'Used'];
      materials = ['Paper', 'Cardboard'];
    }
  }

  // Handle category selection
  void _openCategoryModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return RadioListTile<String>(
              title: Text(categories[index]),
              value: categories[index],
              groupValue: _selectedCategory,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                  _setOptions(value!); // Reset dropdowns when category changes
                });
                Navigator.pop(context); // Close the modal after selection
              },
            );
          },
        );
      },
    );
  }

  // Method for picking images from the gallery
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _imageFiles?.addAll(pickedFiles);
      });
    }
  }

  // The function to get current location
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        selectedAddress = null;
      });
      await _updateAddress(_latitude!, _longitude!);
    } catch (e) {
      setState(() {
        selectedAddress = 'Gagal mendapatkan alamat';
      });
    }
  }

  // Method to update the address from latitude and longitude
  Future<void> _updateAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        setState(() {
          selectedAddress = address;
        });
      } else {
        setState(() {
          selectedAddress = 'Alamat tidak ditemukan';
        });
      }
    } catch (e) {
      setState(() {
        selectedAddress = 'Gagal mendapatkan alamat';
      });
    }
  }

  // Method to add the item to Firestore
  Future<void> _addItem() async {
    final String itemName = _itemNameController.text.trim();
    final String description = _descriptionController.text.trim();
    final String price = _priceController.text.trim();

    if (itemName.isEmpty || description.isEmpty || price.isEmpty || _selectedCategory == null || _selectedStyle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String?> encodedImages = [];
      if (_imageFiles != null && _imageFiles!.isNotEmpty) {
        for (var imageFile in _imageFiles!) {
          String? encodedImage = await compressAndEncodeImage(imageFile);
          if (encodedImage != null) {
            encodedImages.add(encodedImage);
          }
        }
      }

      await FirebaseFirestore.instance.collection('products').add({
        'itemName': itemName,
        'description': description,
        'price': double.tryParse(price) ?? 0.0,
        'category': _selectedCategory,
        'style': _selectedStyle,
        'condition': _selectedCondition,
        'color': _selectedColor,
        'material': _selectedMaterial,
        'createdAt': Timestamp.now(),
        'images': encodedImages,
        'location': {
          'latitude': _latitude,
          'longitude': _longitude,
          'address': selectedAddress,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added successfully!')));

      _itemNameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _imageFiles = [];
        _selectedCategory = null;
        _selectedStyle = null;
        _selectedCondition = null;
        _selectedColor = null;
        _selectedMaterial = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to compress and encode image
  Future<String?> compressAndEncodeImage(XFile imageFile, {int maxWidth = 400, int quality = 70}) async {
    final bytes = await File(imageFile.path).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    img.Image resized = img.copyResize(image, width: maxWidth);
    List<int> jpg = img.encodeJpg(resized, quality: quality);

    if (jpg.length > 900 * 1024) {
      return null;
    }

    return base64Encode(jpg);
  }

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndGetLocation();
  }

  // Method to check location permission
  Future<void> _checkLocationPermissionAndGetLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jual Produk'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker section
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    onPressed: _pickImages,
                  ),
                  const Text("Tambah foto"),
                ],
              ),
              Wrap(
                children: _imageFiles!.map((file) {
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.file(File(file.path), height: 100, width: 100),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Item Name
              const Text("Judul", style: TextStyle(fontWeight: FontWeight.bold)),
              _buildTextField(_itemNameController, 'e.g. Levi\'s 578 baggy jeans hitam'),

              // Description
              const Text("Deskripsi", style: TextStyle(fontWeight: FontWeight.bold)),
              _buildTextField(_descriptionController, 'Tulis deskripsi produk'),

              // Price
              const Text("Price", style: TextStyle(fontWeight: FontWeight.bold)),
              _buildTextField(_priceController, 'Price', isNumber: true),

              const SizedBox(height: 20),

              // Category Button
              const Text("Category", style: TextStyle(fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _openCategoryModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Text(_selectedCategory ?? 'Select Category'),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              // Display the selected category
              if (_selectedCategory != null)
                Text("Category: ${_selectedCategory!.toLowerCase()}"),

              const SizedBox(height: 20),

              // Show options only after category is selected
              if (_selectedCategory != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Style (Dropdown)
                    const Text("Style", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedStyle,
                      items: styles.map((String style) {
                        return DropdownMenuItem<String>(
                          value: style,
                          child: Text(style),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStyle = value;
                        });
                      },
                      hint: const Text("Select Style"),
                    ),

                    // Condition (Dropdown)
                    const Text("Condition", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCondition,
                      items: conditions.map((String condition) {
                        return DropdownMenuItem<String>(
                          value: condition,
                          child: Text(condition),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCondition = value;
                        });
                      },
                      hint: const Text("Select Condition"),
                    ),

                    // Color (Dropdown)
                    const Text("Color", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedColor,
                      items: colors.map((String color) {
                        return DropdownMenuItem<String>(
                          value: color,
                          child: Text(color),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedColor = value;
                        });
                      },
                      hint: const Text("Select Color"),
                    ),

                    // Material (Dropdown)
                    const Text("Material", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedMaterial,
                      items: materials.map((String material) {
                        return DropdownMenuItem<String>(
                          value: material,
                          child: Text(material),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMaterial = value;
                        });
                      },
                      hint: const Text("Select Material"),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Save draft'),
                  ),
                  ElevatedButton(
                    onPressed: _addItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Upload'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }
}
