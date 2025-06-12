import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Import the data file for categories and other data
import 'package:pabtugasuas/data.dart';

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

  // Initialize selected category, subcategory, and other selections
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedSize;
  String? _selectedBrand;
  String? _selectedStyle;
  String? _selectedCondition;
  String? _selectedColor;
  String? _selectedMaterial;

  List<String> subcategories = [];
  List<String> sizes = [];
  List<String> brands = [];
  List<String> styles = [];
  List<String> conditions = [];
  List<String> colors = [];
  List<String> materials = [];

  double? _latitude;
  double? _longitude;
  String? selectedAddress;
  String locationInfo = "";

  // Open the category modal with radio buttons
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
                  // Set subcategories and other options based on the selected category
                  _setSubcategories(_selectedCategory);
                });
                Navigator.pop(context); // Close the modal after selection
              },
            );
          },
        );
      },
    );
  }

  // Set subcategories, sizes, and other options based on the selected category
  void _setSubcategories(String? category) {
    switch (category) {
      case 'Pakaian':
        setState(() {
          subcategories = brands['Pakaian']!;
          sizes = sizes['Pakaian']!;
          styles = styles['Pakaian']!;
          conditions = conditions['Pakaian']!;
          colors = colors['Pakaian']!;
          materials = materials['Pakaian']!;
        });
        break;
      case 'Sepatu':
        setState(() {
          subcategories = brands['Sepatu']!;
          sizes = sizes['Sepatu']!;
          styles = styles['Sepatu']!;
          conditions = conditions['Sepatu']!;
          colors = colors['Sepatu']!;
          materials = materials['Sepatu']!;
        });
        break;
      case 'Tas dan Aksesori':
        setState(() {
          subcategories = brands['Tas dan Aksesori']!;
          styles = styles['Tas dan Aksesori']!;
          conditions = conditions['Tas dan Aksesori']!;
          colors = colors['Tas dan Aksesori']!;
          materials = materials['Tas dan Aksesori']!;
        });
        break;
      case 'Buku Bekas':
        setState(() {
          subcategories = ['Fiksi', 'Non-Fiksi'];
        });
        break;
      case 'Elektronik Bekas':
        setState(() {
          subcategories = brands['Elektronik Bekas']!;
        });
        break;
      default:
        setState(() {
          subcategories = [];
          sizes = [];
          brands = [];
          styles = [];
          conditions = [];
          colors = [];
          materials = [];
        });
    }
  }

  // Open the subcategory modal with radio buttons (brands or types)
  void _openSubcategoryModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: subcategories.length,
          itemBuilder: (context, index) {
            return RadioListTile<String>(
              title: Text(subcategories[index]),
              value: subcategories[index],
              groupValue: _selectedSubcategory,
              onChanged: (value) {
                setState(() {
                  _selectedSubcategory = value;
                  // Show additional options (sizes, brands, etc.) after subcategory selection
                  _showAdditionalOptions();
                });
                Navigator.pop(context); // Close the modal after selection
              },
            );
          },
        );
      },
    );
  }

  // Show dropdowns for sizes, styles, conditions, colors, materials after selecting subcategory
  void _showAdditionalOptions() {
    if (_selectedCategory == 'Pakaian' || _selectedCategory == 'Sepatu') {
      setState(() {
        styles = styles['Pakaian']!;
        conditions = conditions['Pakaian']!;
        colors = colors['Pakaian']!;
        materials = materials['Pakaian']!;
      });
    } else {
      setState(() {
        styles = ['Casual', 'Formal', 'Streetwear'];
        conditions = ['Baru', 'Bekas'];
        colors = ['Merah', 'Biru', 'Putih'];
        materials = ['Kapas', 'Polyester'];
      });
    }
  }

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

  Future<void> _addItem() async {
    final String itemName = _itemNameController.text.trim();
    final String description = _descriptionController.text.trim();
    final String price = _priceController.text.trim();

    if (itemName.isEmpty || description.isEmpty || price.isEmpty || _selectedCategory == null || _selectedSubcategory == null) {
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
        'subcategory': _selectedSubcategory,
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
        _selectedSubcategory = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _imageFiles?.addAll(pickedFiles);
      });
    }
  }

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
                Text("categories: ${_selectedCategory!.toLowerCase()}"),

              const SizedBox(height: 20),

              // Subcategory (Radio Buttons)
              if (_selectedCategory != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Subcategory", style: TextStyle(fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => _openSubcategoryModal(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Text(_selectedSubcategory ?? 'Select Subcategory'),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // Display the selected subcategory
              if (_selectedSubcategory != null)
                Text("subcategory: ${_selectedSubcategory!.toLowerCase()}"),

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
