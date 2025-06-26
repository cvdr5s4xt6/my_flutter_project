import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ItemType { box, candy, marmalade }

class ItemsPage extends StatefulWidget {
  final ItemType itemType;
  final String? boxSize;

  const ItemsPage({super.key, required this.itemType, this.boxSize});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final supabase = Supabase.instance.client;

  late Map<String, dynamic> conf;
  List<Map<String, dynamic>> items = [];
  Map<int, String> typeMap = {};
  Map<int, int> cart = {};
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
      for (var t in typeResponse)
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
    Map<String, dynamic> updateData;

    if (widget.itemType == ItemType.box) {
      updateData = {'quantity_in_stock': newQuantity};
    } else {
      updateData = {'quantity': newQuantity};
    }

    await supabase
        .from(conf['itemsTable'])
        .update(updateData)
        .eq(conf['itemIdCol'], id);

    await loadData();
  }

  void addToCart(int id, int currentQuantity) {
    if (currentQuantity > 0) {
      setState(() {
        cart[id] = (cart[id] ?? 0) + 1;
      });
      updateQuantity(id, currentQuantity - 1);
    }
  }

  void removeFromCart(int id, int currentQuantity) {
    if (cart[id] != null && cart[id]! > 0) {
      setState(() {
        cart[id] = cart[id]! - 1;
        if (cart[id]! <= 0) cart.remove(id);
      });
      updateQuantity(id, currentQuantity + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = {
      ItemType.box: 'Коробки',
      ItemType.candy: 'Конфеты',
      ItemType.marmalade: 'Мармелад',
    }[widget.itemType]!;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                ...typeMap.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                ),
              ],
              onChanged: (val) {
                setState(() => selectedFilterId = val);
                loadData();
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(child: Text('Нет доступных $title'.toLowerCase()))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final id = item[conf['itemIdCol']] as int;
                      final photo = item['photo'] as String?;
                      final quantity = item[conf['itemQuantityCol']] as int;
                      final typeIdKey = widget.itemType == ItemType.box
                          ? 'color_id'
                          : widget.itemType == ItemType.candy
                          ? 'candy_type_id'
                          : 'marmalade_type_id';
                      final typeName = typeMap[item[typeIdKey]] ?? 'Неизвестно';

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
                                widget.itemType == ItemType.box
                                    ? 'Цвет: $typeName'
                                    : 'Тип: $typeName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.itemType == ItemType.box &&
                                  item['description'] != null)
                                Text('Описание: ${item['description']}'),
                              Text('В наличии: $quantity'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: quantity > 0
                                        ? () => addToCart(id, quantity)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: cart.containsKey(id)
                                        ? () => removeFromCart(id, quantity)
                                        : null,
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
