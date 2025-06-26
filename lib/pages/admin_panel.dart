import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_order_details.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'auth_page.dart';
import 'register.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> orders = [];
  Map<String, String> userNames = {}; // user_id -> "Имя Фамилия"

  String? firstName;
  String? lastName;
  bool _adminNameLoaded = false;

  @override
  void initState() {
    super.initState();
    loadAllOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_adminNameLoaded) {
      loadAdminName();
      _adminNameLoaded = true;
    }
  }

  Future<void> loadAdminName() async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('first_name, last_name')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        setState(() {
          firstName = profile['first_name'];
          lastName = profile['last_name'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки имени администратора: $e')),
      );
    }
  }

  Future<void> loadAllOrders() async {
    try {
      final response = await supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        orders = response;
      });

      // Получаем имена всех пользователей по user_id
      final userIds = orders
          .map((order) => order['user_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (userIds.isNotEmpty) {
        final usersResponse = await supabase
            .from('profiles')
            .select('id, first_name, last_name')
            .inFilter('id', userIds);

        final names = <String, String>{};
        for (var user in usersResponse) {
          names[user['id']] = '${user['first_name']} ${user['last_name']}';
        }

        setState(() {
          userNames = names;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки заказов: $e')));
    }
  }

  Future<void> markAsCollected(int orderId) async {
    try {
      await supabase
          .from('orders')
          .update({'status': 'Собран'})
          .eq('id', orderId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Статус обновлён')));

      await loadAllOrders();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e')));
    }
  }

  String formatDateTime(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (firstName != null && lastName != null)
        ? '$firstName $lastName'
        : '';

    final userId = Provider.of<UserProvider>(context).userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказы админа:'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                fullName,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Назад',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (userId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка: пользователь не найден')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RegisterPage(userId: userId)),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Зарегистрировать курьера'),
      ),
      body: orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final String status = order['status'] ?? '';
                final bool canShowButton =
                    status != 'Собран' && status != 'Оплачено';

                final userId = order['user_id'];
                final String customerName =
                    userId != null && userNames.containsKey(userId)
                    ? userNames[userId]!
                    : 'Без имени';

                final String formattedDate = formatDateTime(
                  order['created_at'] ?? '',
                );

                return ListTile(
                  title: Text('$customerName — ${order['status'] ?? ''}'),
                  subtitle: Text(
                    'Дата: $formattedDate, Сумма: ${order['total_price']} руб',
                  ),
                  trailing: canShowButton
                      ? ElevatedButton(
                          onPressed: () => markAsCollected(order['id']),
                          child: const Text('Собрать'),
                        )
                      : null,
                  onTap: () async {
                    final updatedOrder = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserOrderDetailsPage(order: order),
                      ),
                    );

                    if (updatedOrder != null) {
                      setState(() {
                        orders[index] = updatedOrder;
                      });
                    }
                  },
                );
              },
            ),
    );
  }
}
