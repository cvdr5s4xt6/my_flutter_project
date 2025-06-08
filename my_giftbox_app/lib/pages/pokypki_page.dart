import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'package:provider/provider.dart';
//import 'user_provider.dart';

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
          TextButton(
            onPressed: () async => await placeOrder(context),
            child: const Text(
              'Заказать',
              style: TextStyle(color: Colors.white),
            ),
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

  Future<void> placeOrder(BuildContext context) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    //final userIdFromProvider = context.read<UserProvider>().userId;
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

    final insertResponse = await supabase.from('orders').insert({
      'user_id': userId,
      'full_name': fullName,
      'status': 'Новый',
      'items': orderItems,
      'requested_photo': false,
    }).select();

    if (insertResponse.isEmpty) {
      print('Ошибка вставки заказа');
      return;
    }

    final insertedOrder = insertResponse.first;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserOrderPage(
          orderId: insertedOrder['id'],
          fullName: fullName,
          orderItems: orderItems,
        ),
      ),
    );
  }
}

class UserOrderPage extends StatelessWidget {
  final int orderId;
  final String fullName;
  final List<Map<String, dynamic>> orderItems;

  const UserOrderPage({
    super.key,
    required this.orderId,
    required this.fullName,
    required this.orderItems,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ваш заказ')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ФИО: $fullName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Ваш заказ:'),
            ...orderItems.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${item['name']} | Цвет: ${item['color']} | Размер: ${item['size']} | Кол-во: ${item['quantity']}',
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Supabase.instance.client
                    .from('orders')
                    .update({'requested_photo': true})
                    .eq('id', orderId);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Запрос на фото отправлен')),
                );
              },
              child: const Text('Запросить фото подарка'),
            ),
          ],
        ),
      ),
    );
  }
}
