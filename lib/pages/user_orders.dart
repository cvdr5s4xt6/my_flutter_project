import 'package:flutter/material.dart';
import 'pokypki_page.dart';
import 'user_order_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserOrdersPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> boxes;
  final Map<int, int> cart;
  final Map<int, String> colorMap;

  const UserOrdersPage({
    super.key,
    required this.userId,
    required this.boxes,
    required this.cart,
    required this.colorMap,
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

  @override
  void initState() {
    super.initState();
    cart = Map<int, int>.from(widget.cart);
    loadOrders();
  }

  Future<void> loadOrders() async {
    final userId = widget.userId;

    if (userId.isEmpty) {
      if (!mounted) return;
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

  Future<void> addToCart(int boxId) async {
    if (!mounted) return;
    setState(() {
      if (cart.containsKey(boxId)) {
        cart[boxId] = cart[boxId]! + 1;
      } else {
        cart[boxId] = 1;
      }
    });
    debugPrint("Добавлен в корзину: $boxId, теперь в корзине: ${cart[boxId]}");
  }

  Future<void> removeFromCart(int boxId) async {
    if (!mounted) return;
    setState(() {
      if (cart.containsKey(boxId)) {
        if (cart[boxId]! > 1) {
          cart[boxId] = cart[boxId]! - 1;
        } else {
          cart.remove(boxId);
        }
      }
    });
    debugPrint(
      "Удалён из корзины: $boxId, теперь в корзине: ${cart[boxId] ?? 0}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Мои заказы"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Просто возвращаемся назад, если была обычная навигация push
            Navigator.pop(context);

            // Если нужна замена страницы, можно использовать pushReplacement,
            // но обычно для возврата удобнее pop
            /*
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PokypkiPage(
                  boxes: widget.boxes,
                  cart: cart,
                  colorMap: widget.colorMap,
                  addToCart: addToCart,
                  removeFromCart: removeFromCart,
                ),
              ),
            );
            */
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
