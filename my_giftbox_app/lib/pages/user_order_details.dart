import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';

class UserOrderDetailsPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const UserOrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(order['items']);
    return Scaffold(
      appBar: AppBar(title: const Text("Детали заказа")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Заказ #${order['id']}', style: const TextStyle(fontSize: 18)),
            Text('Статус: ${order['status']}'),
            Text('Дата: ${order['created_at']}'),
            const Divider(),
            const Text('Состав заказа:'),
            ...items.map(
              (item) => Text(
                '${item['name']} — ${item['color']}, ${item['size']}, кол-во: ${item['quantity']}',
              ),
            ),
            const SizedBox(height: 20),
            Text('Итого: ${order['total_price']} руб'),
          ],
        ),
      ),
    );
  }
}
