import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_order_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserOrdersPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> boxes;
  final Map<int, int> cart;
  final Map<int, String> colorMap;
  final bool isAdmin;

  const UserOrdersPage({
    super.key,
    required this.userId,
    required this.boxes,
    required this.cart,
    required this.colorMap,
    this.isAdmin = false,
  });

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  final supabase = Supabase.instance.client;
  late Map<int, int> cart;
  List<dynamic> orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Для двойного подтверждения отмены заказа
  final Map<int, bool> _cancelPressed = {};

  // Для двойного подтверждения удаления заказа
  final Map<int, bool> _deletePressed = {};

  @override
  void initState() {
    super.initState();
    cart = Map<int, int>.from(widget.cart);
    loadOrders();
  }

  Future<void> loadOrders() async {
    try {
      final response = widget.isAdmin
          ? await supabase
                .from('orders')
                .select()
                .order('created_at', ascending: false)
          : await supabase
                .from('orders')
                .select()
                .eq('user_id', widget.userId)
                .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        orders = response;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки заказов: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Ошибка загрузки заказов. Пожалуйста, попробуйте позже.";
      });
    }
  }

  Future<void> deleteOrder(int orderId, int index) async {
    try {
      await supabase.from('orders').delete().eq('id', orderId);
      if (!mounted) return;
      setState(() {
        orders.removeAt(index);
        _deletePressed.remove(orderId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заказ удалён')));
    } catch (e) {
      debugPrint('Ошибка удаления заказа: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось удалить заказ')));
    }
  }

  Future<void> cancelOrder(int orderId, int index) async {
    try {
      final orderResponse = await supabase
          .from('orders')
          .select('items')
          .eq('id', orderId)
          .single();

      if (orderResponse == null) {
        throw Exception('Заказ не найден');
      }

      final List<dynamic> items = orderResponse['items'] ?? [];

      for (final item in items) {
        final Map<String, dynamic> boxItem = Map<String, dynamic>.from(item);

        final int boxId = boxItem['box_id'];
        final int quantity = boxItem['quantity'];

        await supabase.rpc(
          'increment_box_stock',
          params: {'box': boxId, 'inc_amount': quantity},
        );
      }

      await supabase
          .from('orders')
          .update({'status': 'Отменён'})
          .eq('id', orderId);

      if (!mounted) return;
      setState(() {
        orders[index]['status'] = 'Отменён';
        _cancelPressed.remove(orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ отменён, количество возвращено на склад'),
        ),
      );
    } catch (e) {
      debugPrint('Ошибка отмены заказа: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отменить заказ')),
      );
    }
  }

  Future<void> deleteAllPaidAndCancelledOrders() async {
    final filteredOrders = orders
        .where(
          (order) =>
              order['status'] == 'Оплачено' || order['status'] == 'Отменён',
        )
        .toList();

    if (filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет заказов со статусом "Оплачено" или "Отменён"'),
        ),
      );
      return;
    }

    try {
      final idsToDelete = filteredOrders.map((e) => e['id']).toList();
      await supabase
          .from('orders')
          .delete()
          .filter('id', 'in', '(${idsToDelete.join(',')})');

      if (!mounted) return;
      setState(() {
        orders.removeWhere(
          (order) =>
              order['status'] == 'Оплачено' || order['status'] == 'Отменён',
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Все оплаченные и отменённые заказы удалены'),
        ),
      );
    } catch (e) {
      debugPrint('Ошибка массового удаления: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при удалении заказов')),
      );
    }
  }

  String formatDate(String isoDateString) {
    try {
      final dateTime = DateTime.parse(isoDateString).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
    } catch (e) {
      return isoDateString;
    }
  }

  void _handleCancelPressed(int orderId, int index) {
    if (_cancelPressed[orderId] == true) {
      cancelOrder(orderId, index);
    } else {
      setState(() {
        _cancelPressed[orderId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нажмите ещё раз, чтобы подтвердить отмену заказа'),
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _cancelPressed.remove(orderId);
          });
        }
      });
    }
  }

  void _handleDeletePressed(int orderId, int index) {
    if (_deletePressed[orderId] == true) {
      deleteOrder(orderId, index);
    } else {
      setState(() {
        _deletePressed[orderId] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нажмите ещё раз, чтобы подтвердить удаление заказа'),
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _deletePressed.remove(orderId);
          });
        }
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
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Удалить оплаченные и отменённые заказы',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text(
                    'Удалить все оплаченные и отменённые заказы?',
                  ),
                  content: const Text(
                    'Вы уверены, что хотите удалить ВСЕ заказы со статусом "Оплачено" и "Отменён"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        deleteAllPaidAndCancelledOrders();
                      },
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
                final createdAt = order['created_at'] ?? '';
                final status = order['status'] ?? '';

                final displayOrderNumber = widget.isAdmin
                    ? order['id'].toString()
                    : (orders.length - index).toString();

                List<Widget> trailingButtons = [];

                // Если заказ Оплачено или Отменён — показываем красную кнопку удаления
                if (status == "Оплачено" || status == "Отменён") {
                  trailingButtons.add(
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _handleDeletePressed(order['id'], index),
                    ),
                  );
                }

                // Если заказ Новый — показываем кнопку отмены
                if (status == "Новый") {
                  trailingButtons.add(
                    IconButton(
                      icon: const Icon(Icons.undo, color: Colors.green),
                      onPressed: () => _handleCancelPressed(order['id'], index),
                    ),
                  );
                }

                return ListTile(
                  title: Text('Заказ #$displayOrderNumber — $status'),
                  subtitle: Text('Дата: ${formatDate(createdAt)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: trailingButtons,
                  ),
                  onTap: () async {
                    final updatedOrder = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserOrderDetailsPage(order: order),
                      ),
                    );

                    if (updatedOrder != null &&
                        updatedOrder is Map<String, dynamic>) {
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
