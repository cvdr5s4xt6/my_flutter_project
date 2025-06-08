import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';

import 'package:provider/provider.dart'; // обязательно импорт Provider
import 'user_provider.dart'; // импорт твоего UserProvider

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final response = await supabase
        .from('orders')
        .select('*')
        .order('id', ascending: false);
    setState(() {
      orders = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Получаем userId из UserProvider
    final userId = context.read<UserProvider>().userId;

    // Теперь можно использовать userId, например, для фильтрации или отображения
    print('Текущий userId: $userId');

    return Scaffold(
      appBar: AppBar(title: const Text('Админ Панель')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text('Нет заказов'))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final items = List<Map<String, dynamic>>.from(order['items']);
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Заказ #${order['id']}'),
                        Text('ФИО: ${order['full_name']}'),
                        Text('Статус: ${order['status']}'),
                        const SizedBox(height: 8),
                        const Text('Товары:'),
                        ...items.map(
                          (item) => Text(
                            '${item['name']} | Цвет: ${item['color']} | Размер: ${item['size']} | Кол-во: ${item['quantity']}',
                          ),
                        ),
                        if (order['requested_photo'] == true)
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              const Text('Запрошено фото подарка'),
                              order['photo_url'] != null
                                  ? Image.network(
                                      order['photo_url'],
                                      height: 150,
                                    )
                                  : const Text('Фото пока не загружено'),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthPage()),
          );
        },
        child: const Icon(Icons.logout),
      ),
    );
  }
}
