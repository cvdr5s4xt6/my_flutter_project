import 'package:flutter/material.dart';
import 'package:my_giftbox_app/pages/user_order_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserOrdersPage extends StatefulWidget {
  final String userId;

  const UserOrdersPage({super.key, required this.userId});

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    final userId = widget.userId;

    // Проверка userId перед выполнением запроса
    if (userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Ошибка: ID пользователя не задан.";
      });
      return;
    }

    try {
      final response = await supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        orders = response;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки заказов: $e');
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Ошибка загрузки заказов. Пожалуйста, попробуйте позже.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Мои заказы"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PokypkiPage(userId: widget.userId),
              ),
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : orders.isEmpty
          ? const Center(child: Text('У вас пока нет заказов'))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  title: Text('Заказ #${order['id']} — ${order['status']}'),
                  subtitle: Text('Дата: ${order['created_at']}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserOrderDetailsPage(order: order),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
