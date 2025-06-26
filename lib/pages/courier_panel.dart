import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_provider.dart';
import 'auth_page.dart'; // Импортируем страницу авторизации

class CourierPanelPage extends StatefulWidget {
  const CourierPanelPage({super.key});

  @override
  State<CourierPanelPage> createState() => _CourierPanelPageState();
}

class _CourierPanelPageState extends State<CourierPanelPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> courierOrders = [];
  bool _isLoading = true;
  bool _hasAccess = false;
  String? _errorMessage;

  // Хранит id курьера для фильтрации заказов
  String? _courierId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCourierAccess();
    });
  }

  Future<void> _checkCourierAccess() async {
    setState(() {
      _isLoading = true;
      _hasAccess = false;
      _errorMessage = null;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = userProvider.userEmail;

    if (email == null) {
      setState(() {
        _errorMessage = 'Пользователь не авторизован';
        _isLoading = false;
      });
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('id, role')
          .eq('email', email)
          .maybeSingle();

      if (profile == null) {
        setState(() {
          _errorMessage = 'Пользователь не найден в системе';
          _isLoading = false;
        });
        return;
      }

      if (profile['role'] != 'courier') {
        setState(() {
          _errorMessage = 'Доступ разрешён только курьерам';
          _isLoading = false;
        });
        return;
      }

      _courierId = profile['id'] as String?;
      debugPrint('Получен id курьера: $_courierId');

      setState(() {
        _hasAccess = true;
      });

      await _loadCourierOrders();
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка доступа: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCourierOrders() async {
    if (_courierId == null) {
      setState(() {
        _errorMessage = 'Неизвестный ID курьера';
        courierOrders = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase
          .from('orders')
          .select()
          .eq('delivery_method', 'Курьер')
          .eq('status', 'Собран')
          .eq('assigned_courier_id', _courierId!);

      if (response is List) {
        courierOrders = List<Map<String, dynamic>>.from(response);

        final orderIds = courierOrders.map((order) => order['id']).toList();
        debugPrint('Получены заказы с id: $orderIds');

        setState(() {});
      } else {
        setState(() {
          courierOrders = [];
          _errorMessage = 'Неверный формат данных с сервера';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки заказов: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsDelivered(int orderId) async {
    debugPrint('Нажата кнопка "Доставить" для заказа с id: $orderId');
    try {
      final updates = await supabase
          .from('orders')
          .update({'status': 'Едет'})
          .eq('id', orderId);

      if (updates.error != null) {
        throw updates.error!;
      }

      _showMessage('Статус заказа обновлён: Едет');
      await _loadCourierOrders();
    } catch (e) {
      _showMessage('Ошибка обновления: $e');
    }
  }

  Future<void> _reassignOrder(int orderId) async {
    debugPrint('Нажата кнопка "Передать" для заказа с id: $orderId');
    try {
      final updates = await supabase
          .from('orders')
          .update({'assigned_courier_id': null})
          .eq('id', orderId);

      if (updates.error != null) {
        throw updates.error!;
      }

      _showMessage('Заказ передан другому курьеру');
      await _loadCourierOrders();
    } catch (e) {
      _showMessage('Ошибка передачи заказа: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBackToAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Панель курьера'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _goBackToAuth,
              child: const Text(
                'Назад',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 18, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            : !_hasAccess
            ? const Center(
                child: Text(
                  'Доступ запрещён',
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              )
            : courierOrders.isEmpty
            ? const Center(
                child: Text(
                  'Нет заказов для доставки',
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
              )
            : ListView.builder(
                itemCount: courierOrders.length,
                itemBuilder: (context, index) {
                  final order = courierOrders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text('Заказ #${order['id']}'),
                      subtitle: Text('Адрес: ${order['delivery_address']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () =>
                                _markAsDelivered(order['id'] as int),
                            child: const Text('Доставить'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => _reassignOrder(order['id'] as int),
                            child: const Text('Передать'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
