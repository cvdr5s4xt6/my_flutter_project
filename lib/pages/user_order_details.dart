import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

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
  bool _showQrCode = false;

  // Для сканера
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;
  bool _isScanning = false;
  bool _isProcessingScan = false;

  late Map<String, dynamic> order;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
    _deliveryMethod = order['delivery_method'];
    _paymentMethod = order['payment_method'];
    _showQrCode = _paymentMethod == 'QR-код' && order['status'] != 'Оплачено';
  }

  @override
  void dispose() {
    _qrController?.dispose();
    super.dispose();
  }

  Future<void> _updateOrder({
    required String deliveryMethod,
    required String paymentMethod,
  }) async {
    await supabase
        .from('orders')
        .update({
          'delivery_method': deliveryMethod,
          'payment_method': paymentMethod,
        })
        .eq('id', order['id']);

    setState(() {
      _deliveryMethod = deliveryMethod;
      _paymentMethod = paymentMethod;
      _showQrCode = paymentMethod == 'QR-код' && order['status'] != 'Оплачено';
      order['delivery_method'] = deliveryMethod;
      order['payment_method'] = paymentMethod;
      _isScanning = false;
      _isProcessingScan = false;
    });
  }

  Future<void> _markAsPaid() async {
    await supabase
        .from('orders')
        .update({'status': 'Оплачено'})
        .eq('id', order['id']);

    setState(() {
      order['status'] = 'Оплачено';
      _showQrCode = false; // скрываем QR-код
      _isScanning = false; // скрываем сканер
      _isProcessingScan = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Оплата подтверждена')));
  }

  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;

    controller.scannedDataStream.listen((scanData) async {
      if (!_isScanning || _isProcessingScan) return;

      final scannedText = scanData.code;
      if (scannedText == null) return;

      final uri = Uri.tryParse(scannedText);
      final orderId = uri?.queryParameters['order_id'];

      if (orderId != null && orderId == order['id'].toString()) {
        _isProcessingScan = true;

        // Останавливаем камеру, чтобы не продолжать сканировать
        await controller.pauseCamera();

        // Меняем статус заказа и скрываем QR и сканер
        await _markAsPaid();

        if (mounted) {
          setState(() {
            _isScanning = false; // скрываем сканер
            _showQrCode = false; // скрываем QR-код
          });
        }

        // ВАЖНО: просто вызываем dispose без await
        _qrController?.dispose();
        _qrController = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text("Детали заказа")),
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
              Text('Дата: ${order['created_at']}'),
              const Divider(),
              const Text('Состав заказа:'),
              const SizedBox(height: 8),
              ...items.map(
                (item) => Text(
                  '${item['name']} — ${item['color'] ?? '-'}, ${item['size'] ?? '-'}, кол-во: ${item['quantity']}',
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

              if (order['status'] == 'Собран' && !_showQrCode)
                _buildDeliveryPaymentForm(),

              if (_showQrCode && order['status'] != 'Оплачено')
                _buildQrCodeWithScannerOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryPaymentForm() {
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
            'QR-код',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _paymentMethod = val),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: (_deliveryMethod != null && _paymentMethod != null)
              ? () => _updateOrder(
                  deliveryMethod: _deliveryMethod!,
                  paymentMethod: _paymentMethod!,
                )
              : null,
          child: const Text('Подтвердить'),
        ),
      ],
    );
  }

  Widget _buildQrCodeWithScannerOverlay() {
    final qrData = "https://your-payment-link.com/pay?order_id=${order['id']}";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: _isScanning ? 0.3 : 1.0,
              child: QrImageView(
                semanticsLabel: 'QR-код для оплаты',
                size: 300,
                data: qrData,
              ),
            ),

            if (_isScanning)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 300,
                  width: 300,
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                      borderColor: Colors.blue,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 250,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 20),

        if (!_isScanning)
          ElevatedButton(
            onPressed: () async {
              if (_qrController != null) {
                await _qrController!.resumeCamera();
              }
              setState(() {
                _isScanning = true;
                _isProcessingScan = false;
              });
            },
            child: const Text('Сканировать код оплаты'),
          ),
      ],
    );
  }
}
