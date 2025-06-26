import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'reviews.dart';

class UserOrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const UserOrderDetailsPage({super.key, required this.order});

  @override
  State<UserOrderDetailsPage> createState() => _UserOrderDetailsPageState();
}

class _UserOrderDetailsPageState extends State<UserOrderDetailsPage> {
  final supabase = Supabase.instance.client;

  String? _deliveryMethod;
  String? _paymentMethod;
  String? _deliveryTime;
  DateTime? _deliveryDate;
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();

  File? _reviewPhoto;
  bool _reviewSubmitted = false;
  bool _showQrCode = false;

  late Map<String, dynamic> order;
  String? _qrToken;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
    _deliveryMethod = order['delivery_method'];
    _paymentMethod = order['payment_method'];
    _deliveryTime = order['delivery_time'];
    _addressController.text = order['delivery_address'] ?? '';
    _qrToken = order['qr_token'];
    if (order['delivery_date'] != null) {
      _deliveryDate = DateTime.tryParse(order['delivery_date']);
    }
    _timeController.text = _deliveryTime ?? '';
    _updateQrCodeVisibility();
  }

  void _updateQrCodeVisibility() {
    _showQrCode = _paymentMethod == 'QR‑код' && order['status'] != 'Оплачено';
  }

  @override
  void dispose() {
    _timeController.dispose();
    _addressController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  String formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  String formatTimeFromDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt);
  }

  String formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '';
    final parts = timeString.split('-').map((e) => e.trim()).toList();
    if (parts.length == 2) {
      return '${parts[0]} - ${parts[1]}';
    }
    return timeString;
  }

  Future<void> _submitReview() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: пользователь не авторизован')),
      );
      return;
    }

    String? photoUrl;
    if (_reviewPhoto != null) {
      try {
        final filePath = 'reviews/${order['id']}/${const Uuid().v4()}.jpg';
        await supabase.storage
            .from('order-reviews')
            .upload(filePath, _reviewPhoto!);
        photoUrl = supabase.storage
            .from('order-reviews')
            .getPublicUrl(filePath);
        if (photoUrl.isEmpty)
          throw Exception('Не удалось получить публичный URL фото');
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки фото: $e')));
        return;
      }
    }

    final comment = _reviewController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Напишите отзыв')));
      return;
    }

    try {
      await supabase.from('reviews').insert({
        'order_id': order['id'],
        'user_id': userId,
        'photo_url': photoUrl,
        'comment': comment,
      });

      setState(() => _reviewSubmitted = true);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReviewsPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка отправки отзыва: $e')));
    }
  }

  Future<void> _pickReviewPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите источник фото'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Галерея'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Камера'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );

    if (source != null) {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked != null) setState(() => _reviewPhoto = File(picked.path));
    }
  }

  Widget _buildReviewForm() {
    if (_reviewSubmitted) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Спасибо за ваш отзыв!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('Оставьте отзыв', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        if (_reviewPhoto != null) Image.file(_reviewPhoto!, height: 200),
        ElevatedButton(
          onPressed: _pickReviewPhoto,
          child: const Text('Загрузить фото'),
        ),
        TextField(
          controller: _reviewController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Ваш отзыв'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _submitReview,
          child: const Text('Отправить отзыв'),
        ),
      ],
    );
  }

  Future<void> _updateOrder({
    required String deliveryMethod,
    required String paymentMethod,
    required DateTime deliveryDate,
    required String deliveryTime,
    required String address,
    String? status,
  }) async {
    String? newQrToken;
    if (paymentMethod == 'QR‑код') newQrToken = const Uuid().v4();

    final updateData = {
      'delivery_method': deliveryMethod,
      'payment_method': paymentMethod,
      'delivery_date': deliveryDate.toIso8601String(),
      'delivery_time': deliveryTime,
      'delivery_address': address,
    };

    if (status != null) updateData['status'] = status;
    if (newQrToken != null) updateData['qr_token'] = newQrToken;

    await supabase.from('orders').update(updateData).eq('id', order['id']);

    setState(() {
      _deliveryMethod = deliveryMethod;
      _paymentMethod = paymentMethod;
      _deliveryDate = deliveryDate;
      _deliveryTime = deliveryTime;
      _addressController.text = address;
      order['delivery_method'] = deliveryMethod;
      order['payment_method'] = paymentMethod;
      order['delivery_date'] = deliveryDate.toIso8601String();
      order['delivery_time'] = deliveryTime;
      order['delivery_address'] = address;
      if (status != null) order['status'] = status;
      if (newQrToken != null) {
        _qrToken = newQrToken;
        order['qr_token'] = newQrToken;
      }
      _updateQrCodeVisibility();
    });

    if (status == 'Оплата при выдаче') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ оформлен: Оплата при выдаче')),
      );
      Navigator.pop(context, order);
    }
  }

  Future<void> _markAsPaid() async {
    await supabase
        .from('orders')
        .update({'status': 'Оплачено'})
        .eq('id', order['id']);
    setState(() {
      order['status'] = 'Оплачено';
      _showQrCode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Оплата подтверждена')));
    Navigator.pop(context, order);
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final orderDate = DateTime.tryParse(order['created_at'] ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Детали заказа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Заказ #${order['id']}',
                style: const TextStyle(fontSize: 18),
              ),
              Text('Статус: ${order['status']}'),
              Text('Дата заказа: ${formatDate(order['created_at'])}'),
              if (orderDate != null)
                Text(
                  'Время заказа: ${formatTimeFromDate(order['created_at'])}',
                ), // 👈 Добавлено
              const Divider(),
              const Text('Состав заказа:'),
              const SizedBox(height: 8),
              ...items.map(
                (item) => Text(
                  '${item['name']} — ${item['color'] ?? '-'}, ${item['size'] ?? '-'}, кол‑во: ${item['quantity']}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Итого: ${order['total_price']} руб',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 30),
              if (order['status'] == 'Оплачено') ...[
                const Text(
                  'Информация о доставке:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_deliveryDate != null)
                  Text(
                    'Дата доставки: ${DateFormat('dd.MM.yyyy').format(_deliveryDate!)}',
                  ),
                if (_deliveryTime != null && _deliveryTime!.isNotEmpty)
                  Text('Время доставки: ${formatTime(_deliveryTime)}'),
                if (_deliveryMethod != null && _deliveryMethod!.isNotEmpty)
                  Text('Способ доставки: $_deliveryMethod'),
                if (_paymentMethod != null && _paymentMethod!.isNotEmpty)
                  Text('Способ оплаты: $_paymentMethod'),
                if (_addressController.text.isNotEmpty)
                  Text('Адрес доставки: ${_addressController.text}'),
                if (!_reviewSubmitted) _buildReviewForm(),
              ],
              if (order['status'] == 'Собран' && !_showQrCode)
                _buildDeliveryPaymentForm(orderDate),
              if (_showQrCode && order['status'] != 'Оплачено') ...[
                _buildQrCode(),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _markAsPaid,
                  child: const Text('Отсканировать и подтвердить оплату'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryPaymentForm(DateTime? orderDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите способ доставки:', style: TextStyle(fontSize: 16)),
        DropdownButton<String>(
          value: _deliveryMethod,
          hint: const Text('Способ доставки'),
          items: [
            'Самовывоз',
            'Курьер',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _deliveryMethod = val),
        ),
        const SizedBox(height: 16),
        const Text('Выберите способ оплаты:', style: TextStyle(fontSize: 16)),
        DropdownButton<String>(
          value: _paymentMethod,
          hint: const Text('Способ оплаты'),
          items: [
            'Наличные',
            'QR‑код',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _paymentMethod = val),
        ),
        const SizedBox(height: 16),
        const Text('Дата доставки:', style: TextStyle(fontSize: 16)),
        Row(
          children: [
            Text(
              _deliveryDate != null
                  ? DateFormat('dd.MM.yyyy').format(_deliveryDate!)
                  : 'Не выбрано',
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: _deliveryDate ?? DateTime.now(),
                  firstDate: orderDate ?? DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (selectedDate != null)
                  setState(() => _deliveryDate = selectedDate);
              },
              child: const Text('Выбрать дату'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Время доставки:', style: TextStyle(fontSize: 16)),
        TextField(
          controller: _timeController,
          decoration: const InputDecoration(
            hintText: 'например, 14:00 - 15:00',
          ),
          onChanged: (val) => _deliveryTime = val,
        ),
        const SizedBox(height: 16),
        const Text('Адрес доставки:', style: TextStyle(fontSize: 16)),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(hintText: 'Введите адрес'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            if (_deliveryMethod != null &&
                _paymentMethod != null &&
                _deliveryDate != null &&
                _deliveryTime != null &&
                _addressController.text.isNotEmpty) {
              if (_paymentMethod == 'Наличные') {
                _updateOrder(
                  deliveryMethod: _deliveryMethod!,
                  paymentMethod: _paymentMethod!,
                  deliveryDate: _deliveryDate!,
                  deliveryTime: _deliveryTime!,
                  address: _addressController.text,
                  status: 'Оплата при выдаче',
                );
              } else if (_paymentMethod == 'QR‑код') {
                _updateOrder(
                  deliveryMethod: _deliveryMethod!,
                  paymentMethod: _paymentMethod!,
                  deliveryDate: _deliveryDate!,
                  deliveryTime: _deliveryTime!,
                  address: _addressController.text,
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Пожалуйста, заполните все поля')),
              );
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _buildQrCode() {
    final qrData = _qrToken ?? 'order_id:${order['id']}';
    return Center(
      child: QrImageView(data: qrData, version: QrVersions.auto, size: 200.0),
    );
  }
}
