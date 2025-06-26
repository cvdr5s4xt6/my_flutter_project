import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'pokypki_page.dart';

enum ItemType { box, candy, marmalade }

class BigBoxPage extends StatefulWidget {
  final ItemType itemType;
  final String? boxSize;

  const BigBoxPage({super.key, required this.itemType, this.boxSize});

  @override
  State<BigBoxPage> createState() => _BigBoxPageState();
}

class _BigBoxPageState extends State<BigBoxPage> {
  final supabase = Supabase.instance.client;

  late final Map<String, dynamic> conf;
  List<Map<String, dynamic>> items = [];
  Map<int, String> typeMap = {};
  int? selectedFilterId;
  bool isLoading = true;

  final Map<ItemType, Map<String, dynamic>> config = {
    ItemType.box: {
      'typeTable': 'colors',
      'typeIdCol': 'color_id',
      'typeNameCol': 'color_name',
      'itemsTable': 'boxes',
      'itemIdCol': 'box_id',
      'itemQuantityCol': 'quantity_in_stock',
      'fields': 'box_id, photo, quantity_in_stock, color_id, description, size',
      'filterCol': 'color_id',
      'titleCol': 'description',
    },
    ItemType.candy: {
      'typeTable': 'candy_types',
      'typeIdCol': 'candy_type_id',
      'typeNameCol': 'name',
      'itemsTable': 'candies',
      'itemIdCol': 'candy_id',
      'itemQuantityCol': 'quantity',
      'fields': 'candy_id, name, quantity, candy_type_id, photo',
      'filterCol': 'candy_type_id',
      'titleCol': 'name',
    },
    ItemType.marmalade: {
      'typeTable': 'marmalade_types',
      'typeIdCol': 'marmalade_type_id',
      'typeNameCol': 'name',
      'itemsTable': 'marmalades',
      'itemIdCol': 'marmalade_id',
      'itemQuantityCol': 'quantity',
      'fields': 'marmalade_id, name, quantity, marmalade_type_id, photo',
      'filterCol': 'marmalade_type_id',
      'titleCol': 'name',
    },
  };

  @override
  void initState() {
    super.initState();
    conf = config[widget.itemType]!;
    loadData();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    final typeResponse = await supabase.from(conf['typeTable']).select();
    typeMap = {
      for (final t in typeResponse)
        t[conf['typeIdCol']] as int: t[conf['typeNameCol']] as String,
    };

    var query = supabase.from(conf['itemsTable']).select(conf['fields']);
    if (widget.itemType == ItemType.box && widget.boxSize != null) {
      query = query.eq('size', widget.boxSize!);
    }
    if (selectedFilterId != null) {
      query = query.eq(conf['filterCol'], selectedFilterId!);
    }

    final data = await query;
    items = (data as List).cast<Map<String, dynamic>>();

    setState(() => isLoading = false);
  }

  Future<void> updateQuantity(int id, int newQuantity) async {
    await supabase
        .from(conf['itemsTable'])
        .update({conf['itemQuantityCol']: newQuantity})
        .eq(conf['itemIdCol'], id);

    await loadData();
  }

  void navigateToCartPage() {
    final cart = context.read<UserProvider>().cart;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PokypkiPage(
          boxes: items,
          cart: cart,
          colorMap: typeMap,
          addToCart: (int boxId) async {
            final box = items.firstWhere((b) => b[conf['itemIdCol']] == boxId);
            final currentQuantity = box[conf['itemQuantityCol']] as int;
            if (currentQuantity > 0) {
              setState(() {
                cart[boxId] = (cart[boxId] ?? 0) + 1;
              });
              await updateQuantity(boxId, currentQuantity - 1);
            }
          },
          removeFromCart: (int boxId) async {
            if (cart.containsKey(boxId) && cart[boxId]! > 0) {
              final box = items.firstWhere(
                (b) => b[conf['itemIdCol']] == boxId,
              );
              final currentQuantity = box[conf['itemQuantityCol']] as int;
              setState(() {
                cart[boxId] = cart[boxId]! - 1;
                if (cart[boxId]! <= 0) {
                  cart.remove(boxId);
                }
              });
              await updateQuantity(boxId, currentQuantity + 1);
            }
          },
          typeMap: {},
          itemType: widget.itemType,
          items: items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = {
      ItemType.box: 'Коробки',
      ItemType.candy: 'Конфеты',
      ItemType.marmalade: 'Мармелад',
    }[widget.itemType]!;

    final cart = context.watch<UserProvider>().cart;

    final typeIdKey = conf['filterCol'];
    final titleCol = conf['titleCol'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () {
                  print('Корзина нажата');
                },
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButton<int?>(
              hint: Text(
                widget.itemType == ItemType.box
                    ? 'Фильтр по цвету'
                    : 'Фильтр по типу',
              ),
              value: selectedFilterId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Все')),
                ...typeMap.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
              ],
              onChanged: (val) async {
                setState(() => selectedFilterId = val);
                await loadData();
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(child: Text('Нет доступных ${title.toLowerCase()}'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final id = item[conf['itemIdCol']] as int;
                      final photo = item['photo'] as String?;
                      final quantity = item[conf['itemQuantityCol']] as int;
                      final typeName = typeMap[item[typeIdKey]] ?? 'Неизвестно';
                      final name = item[titleCol] ?? 'Без названия';

                      return Card(
                        margin: const EdgeInsets.all(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (photo != null && photo.isNotEmpty)
                                Image.network(
                                  photo,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image, size: 100),
                                )
                              else
                                Container(
                                  height: 150,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    widget.itemType == ItemType.box
                                        ? Icons.broken_image
                                        : Icons.cake,
                                    size: 100,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.itemType == ItemType.box
                                    ? 'Цвет: $typeName'
                                    : 'Тип: $typeName',
                              ),
                              Text('В наличии: $quantity'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: quantity > 0
                                        ? () async {
                                            context
                                                .read<UserProvider>()
                                                .addToCart(id);
                                            await updateQuantity(
                                              id,
                                              quantity - 1,
                                            );
                                          }
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: (cart[id] ?? 0) > 0
                                        ? () async {
                                            context
                                                .read<UserProvider>()
                                                .removeFromCart(id);
                                            await updateQuantity(
                                              id,
                                              quantity + 1,
                                            );
                                          }
                                        : null,
                                  ),
                                ],
                              ),

                              if ((cart[id] ?? 0) > 0)
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
