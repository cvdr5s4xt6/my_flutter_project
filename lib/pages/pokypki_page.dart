import 'package:flutter/material.dart';
import 'package:my_giftbox_app/pages/big_box_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'user_provider.dart';
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
    required Map<int, String> typeMap,

    required List<Map<String, dynamic>> items,
    required ItemType itemType,
  });

  @override
  State<PokypkiPage> createState() => _PokypkiPageState();
}

class _PokypkiPageState extends State<PokypkiPage> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;

    final selectedBoxes = widget.boxes
        .where((box) => widget.cart.containsKey(box['box_id'] as int))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ошибка: пользователь не авторизован'),
                  ),
                );
                return;
              }

              if (value == 'list') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserOrdersPage(
                      userId: userId,
                      boxes: widget.boxes,
                      cart: widget.cart,
                      colorMap: widget.colorMap,
                    ),
                  ),
                );
              } else if (value == 'details') {
                final order = await placeOrder(context);
                if (order != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserOrderDetailsPage(order: order),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'list',
                child: Text('Перейти в "Мои заказы"'),
              ),
              PopupMenuItem(
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
                final colorId = box['color_id'] as int? ?? 0;
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
    final userId = context.read<UserProvider>().userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: пользователь не авторизован')),
      );
      return null;
    }

    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Корзина пуста, невозможно оформить заказ'),
        ),
      );
      return null;
    }

    final user = supabase.auth.currentUser;
    final fullName =
        user?.userMetadata?['full_name']?.toString() ?? 'Без имени';

    final orderItems = widget.cart.entries.map((entry) {
      final box = widget.boxes.firstWhere(
        (b) => b['box_id'] == entry.key,
        orElse: () => {'name': 'Не найдено', 'color_id': 0, 'size': 'N/A'},
      );

      return {
        'box_id': entry.key,
        'name': box['name'] ?? '',
        'color': widget.colorMap[box['color_id']] ?? 'Неизвестно',
        'size': box['size'] ?? '',
        'quantity': entry.value,
      };
    }).toList();

    final totalPrice = orderItems.fold<double>(
      0,
      (sum, item) => sum + (item['quantity'] as int) * 500,
    );

    try {
      final response = await supabase.from('orders').insert({
        'user_id': userId,
        'full_name': fullName,
        'status': 'Новый',
        'items': orderItems,
        'requested_photo': false,
        'photo_url': null,
        'total_price': totalPrice,
      }).select();

      if (response.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать заказ')),
        );
        return null;
      }

      widget.cart.clear();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ успешно оформлен!'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      return response.first as Map<String, dynamic>;
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отправке заказа: $error')),
      );
      return null;
    }
  }
}
