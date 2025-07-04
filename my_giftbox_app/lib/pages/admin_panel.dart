import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';

import 'package:provider/provider.dart'; // обязательно импорт Provider
import 'user_order_details.dart';
import 'user_provider.dart'; // импорт твоего UserProvider

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> orders = [];

  @override
  void initState() {
    super.initState();
    loadAllOrders();
  }

  Future<void> loadAllOrders() async {
    final response = await supabase
        .from('orders')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      orders = response;
    });
  }

  Future<void> markAsCollected(int orderId, String userId) async {
    await supabase
        .from('orders')
        .update({'status': 'Собран'})
        .eq('id', orderId);

    // можно тут отправить уведомление или пуш
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Статус обновлён')));
    await loadAllOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Админ: Заказы')),
      body: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return ListTile(
            title: Text('${order['full_name']} — ${order['status']}'),
            subtitle: Text(
              'Дата: ${order['created_at']}, Сумма: ${order['total_price']} руб',
            ),
            trailing: ElevatedButton(
              onPressed: order['status'] == 'Собран'
                  ? null
                  : () => markAsCollected(order['id'], order['user_id']),
              child: const Text('Собрать'),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserOrderDetailsPage(order: order),
              ),
            ),
          );
        },
      ),
    );
  }
}
