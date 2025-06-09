import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'package:provider/provider.dart';
//import 'user_provider.dart';
//import 'dart:convert';

import 'user_orders.dart';
import 'user_order_details.dart';

class PokypkiPage extends StatefulWidget {
  final List<Map<String, dynamic>> boxes;
  final Map<int, int> cart;
  final Map<int, String> colorMap;
  final Future<void> Function(int boxId) addToCart;
  final Future<void> Function(int boxId) removeFromCart;

  const PokypkiPage({
    super.key,
    required this.boxes,
    required this.cart,
    required this.colorMap,
    required this.addToCart,
    required this.removeFromCart,
  });

  @override
  State<PokypkiPage> createState() => _PokypkiPageState();
}

class _PokypkiPageState extends State<PokypkiPage> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final selectedBoxes = widget.boxes
        .where((box) => widget.cart.containsKey(box['box_id'] as int))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'list') {
                // Просто перейти в "Мои заказы"
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserOrdersPage(userId: '')),
                );
              } else if (value == 'details') {
                // Оформить заказ и перейти к деталям
                final order = await placeOrder(context);
                if (order == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ошибка оформления заказа')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserOrderDetailsPage(order: order),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'list',
                child: Text('Перейти в "Мои заказы"'),
              ),
              const PopupMenuItem(
                value: 'details',
                child: Text('К деталям нового заказа'),
              ),
            ],
            icon: const Icon(Icons.shopping_cart_checkout),
          ),
        ],
      ),
      body: selectedBoxes.isEmpty
          ? const Center(child: Text('Корзина пуста'))
          : ListView.builder(
              itemCount: selectedBoxes.length,
              itemBuilder: (context, index) {
                final box = selectedBoxes[index];
                final id = box['box_id'] as int;
                final photo = box['photo'] as String?;
                final colorId = box['color_id'] as int;
                final colorName =
                    widget.colorMap[colorId] ?? 'Неизвестный цвет';
                final quantity = widget.cart[id] ?? 0;

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        photo != null && photo.isNotEmpty
                            ? Image.network(
                                photo,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 150,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 100,
                                ),
                              ),
                        const SizedBox(height: 8),
                        Text('Название: ${box['name'] ?? 'Без названия'}'),
                        Text('Цвет: $colorName'),
                        Text('Размер: ${box['size'] ?? 'Неизвестно'}'),
                        const SizedBox(height: 4),
                        Text('В корзине: $quantity'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () async {
                                await widget.addToCart(id);
                                setState(() {});
                              },
                              icon: const Icon(Icons.add),
                            ),
                            IconButton(
                              onPressed: () async {
                                await widget.removeFromCart(id);
                                setState(() {});
                              },
                              icon: const Icon(Icons.remove),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<Map<String, dynamic>?> placeOrder(BuildContext context) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    if (widget.cart.isEmpty) {
      // Корзина пустая, нельзя оформить заказ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Корзина пуста, невозможно оформить заказ'),
        ),
      );
      return null;
    }

    final userId = user.id;
    final fullName =
        user.userMetadata?['full_name'] ?? 'Неизвестный пользователь';

    final orderItems = widget.cart.entries.map((entry) {
      final box = widget.boxes.firstWhere((b) => b['box_id'] == entry.key);
      return {
        'box_id': entry.key,
        'name': box['name'],
        'color': widget.colorMap[box['color_id']] ?? 'Неизвестно',
        'size': box['size'],
        'quantity': entry.value,
      };
    }).toList();

    final totalPrice = orderItems.fold<double>(
      0,
      (sum, item) => sum + (item['quantity'] as int) * 500,
    );

    final insertResponse = await supabase.from('orders').insert({
      'user_id': userId,
      'full_name': fullName,
      'status': 'Новый',
      'items': orderItems,
      'requested_photo': false,
      'total_price': totalPrice,
    }).select();

    if (insertResponse.isEmpty) {
      print('Ошибка вставки заказа');
      return null;
    }

    // Очистка корзины
    widget.cart.clear();

    // Обновление UI и сообщение
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ успешно оформлен!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final insertedOrder = insertResponse.first as Map<String, dynamic>;
    return insertedOrder;
  }
}
