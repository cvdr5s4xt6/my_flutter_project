import 'package:flutter/material.dart';
import 'pokypki_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:provider/provider.dart';
import 'user_provider.dart';

class BigBoxPage extends StatefulWidget {
  const BigBoxPage({super.key});

  @override
  State<BigBoxPage> createState() => _BigBoxPageState();
}

class _BigBoxPageState extends State<BigBoxPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> boxes = [];
  Map<int, int> cart = {}; // box_id -> количество
  bool isLoading = true;
  int? selectedColorId;
  Map<int, String> colorMap = {}; // color_id -> color_name

  @override
  void initState() {
    super.initState();
    loadColorsAndBoxes();
  }

  Future<void> loadColorsAndBoxes() async {
    setState(() => isLoading = true);
    await loadColors();
    await loadBigBoxes();
    setState(() => isLoading = false);
  }

  Future<void> loadColors() async {
    final response = await supabase.from('colors').select();
    colorMap = {
      for (var color in response)
        color['color_id'] as int: color['color_name'] as String,
    };
  }

  Future<void> loadBigBoxes() async {
    final query = supabase.from('boxes').select().eq('size', 'Большая');
    final response = selectedColorId != null
        ? await query.eq('color_id', selectedColorId!)
        : await query;

    setState(() {
      boxes = response.whereType<Map<String, dynamic>>().toList();
    });
  }

  Future<void> updateQuantityInDb(int boxId, int newQuantity) async {
    await supabase
        .from('boxes')
        .update({'quantity_in_stock': newQuantity})
        .eq('box_id', boxId);
    await loadBigBoxes();
  }

  void addToCart(int boxId, int currentQuantity) {
    if (currentQuantity > 0) {
      setState(() {
        cart[boxId] = (cart[boxId] ?? 0) + 1;
      });
      updateQuantityInDb(boxId, currentQuantity - 1);
    }
  }

  void removeFromCart(int boxId, int currentQuantity) {
    if (cart.containsKey(boxId) && cart[boxId]! > 0) {
      setState(() {
        cart[boxId] = cart[boxId]! - 1;
        if (cart[boxId]! <= 0) {
          cart.remove(boxId);
        }
      });
      updateQuantityInDb(boxId, currentQuantity + 1);
    }
  }

  void navigateToCartPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PokypkiPage(
          boxes: boxes,
          cart: cart,
          colorMap: colorMap,
          addToCart: (boxId) async {
            final box = boxes.firstWhere((b) => b['box_id'] == boxId);
            final currentQuantity = box['quantity_in_stock'] as int;
            if (currentQuantity > 0) {
              setState(() {
                cart[boxId] = (cart[boxId] ?? 0) + 1;
              });
              await updateQuantityInDb(boxId, currentQuantity - 1);
            }
          },
          removeFromCart: (boxId) async {
            if (cart.containsKey(boxId) && cart[boxId]! > 0) {
              final box = boxes.firstWhere((b) => b['box_id'] == boxId);
              final currentQuantity = box['quantity_in_stock'] as int;
              setState(() {
                cart[boxId] = cart[boxId]! - 1;
                if (cart[boxId]! <= 0) {
                  cart.remove(boxId);
                }
              });
              await updateQuantityInDb(boxId, currentQuantity + 1);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Получаем userId из UserProvider
    final userId = context.read<UserProvider>().userId;
    print(
      'Текущий userId: $userId',
    ); // здесь можно использовать userId как нужно

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: navigateToCartPage,
            icon: const Icon(Icons.shopping_cart),
          ),
        ],
      ),
      body: Column(
        children: [
          // Фильтр по цвету
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<int?>(
              hint: const Text('Фильтр по цвету'),
              value: selectedColorId,
              onChanged: (value) async {
                setState(() => selectedColorId = value);
                await loadBigBoxes();
              },
              isExpanded: true,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Все цвета'),
                ),
                ...colorMap.entries.map((entry) {
                  return DropdownMenuItem<int?>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }),
              ],
            ),
          ),

          // Список коробок
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: boxes.length,
                    itemBuilder: (context, index) {
                      final box = boxes[index];
                      final id = box['box_id'] as int;
                      final photo = box['photo'] as String?;
                      final quantity = box['quantity_in_stock'] as int;
                      final colorId = box['color_id'] as int;
                      final colorName = colorMap[colorId] ?? 'Неизвестный цвет';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              photo != null && photo.isNotEmpty
                                  ? Image.network(
                                      photo,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          const Icon(
                                            Icons.broken_image,
                                            size: 100,
                                          ),
                                    )
                                  : Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 100,
                                      ),
                                    ),
                              const SizedBox(height: 8),
                              Text('Цвет: $colorName'),
                              Text('В наличии: $quantity'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: quantity > 0
                                        ? () => addToCart(id, quantity)
                                        : null,
                                    icon: const Icon(Icons.add),
                                  ),
                                  IconButton(
                                    onPressed: cart.containsKey(id)
                                        ? () => removeFromCart(id, quantity)
                                        : null,
                                    icon: const Icon(Icons.remove),
                                  ),
                                ],
                              ),
                              if (cart.containsKey(id))
                                Center(
                                  child: Text(
                                    'В корзине: ${cart[id]}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
