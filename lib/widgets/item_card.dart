import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String itemName;
  final String description;
  final double price;

  const ItemCard({
    super.key,
    required this.itemName,
    required this.description,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(10),
      child: ListTile(
        title: Text(itemName),
        subtitle: Text(description),
        trailing: Text('\$${price.toString()}'),
        onTap: () {
          // Arahkan ke halaman detail produk jika diperlukan
        },
      ),
    );
  }
}
