import 'package:flutter/material.dart';
import 'items_page.dart'; // <-- Импортируем новый универсальный ItemsPage
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'reviews.dart';
import 'auth_page.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Widget? _selectedPage;
  String _appBarTitle = 'Наполнение';

  void _selectPage(Widget page, String title) {
    setState(() {
      _selectedPage = page;
      _appBarTitle = title;
    });
    Navigator.of(context).pop(); // закрыть drawer
  }

  @override
  void initState() {
    super.initState();
    final userId = context.read<UserProvider>().userId;
    print('Текущий userId: $userId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_appBarTitle),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.yellow),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_selectedPage != null) {
                setState(() {
                  _selectedPage = null;
                  _appBarTitle = 'Наполнение';
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthPage()),
                );
              }
            },
            child: const Text(
              'Назад',
              style: TextStyle(color: Colors.yellow, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.black.withOpacity(0.8),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Center(
                child: Text(
                  'Меню',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            ExpansionTile(
              collapsedIconColor: Colors.white,
              iconColor: Colors.white,
              textColor: Colors.white,
              collapsedTextColor: Colors.white,
              title: const Text('1 Раздел Коробки'),
              children: [
                ListTile(
                  title: const Text(
                    'Большая коробка',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () => _selectPage(
                    const ItemsPage(itemType: ItemType.box, boxSize: 'Большая'),
                    'Большая коробка',
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Средняя коробка',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () => _selectPage(
                    const ItemsPage(itemType: ItemType.box, boxSize: 'Средняя'),
                    'Средняя коробка',
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Маленькая коробка',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () => _selectPage(
                    const ItemsPage(
                      itemType: ItemType.box,
                      boxSize: 'Маленькая',
                    ),
                    'Маленькая коробка',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              collapsedIconColor: Colors.white,
              iconColor: Colors.white,
              textColor: Colors.white,
              collapsedTextColor: Colors.white,
              title: const Text('2 Раздел Конфеты'),
              children: [
                ListTile(
                  title: const Text(
                    'Все конфеты',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () => _selectPage(
                    const ItemsPage(itemType: ItemType.candy),
                    'Конфеты',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              collapsedIconColor: Colors.white,
              iconColor: Colors.white,
              textColor: Colors.white,
              collapsedTextColor: Colors.white,
              title: const Text('3 Раздел Мармелад'),
              children: [
                ListTile(
                  title: const Text(
                    'Весь мармелад',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () => _selectPage(
                    const ItemsPage(itemType: ItemType.marmalade),
                    'Мармелад',
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white54, thickness: 1),
            ListTile(
              leading: const Icon(Icons.rate_review, color: Colors.yellow),
              title: const Text(
                'Отзывы',
                style: TextStyle(color: Colors.yellow, fontSize: 18),
              ),
              onTap: () {
                Navigator.pop(context); // Закрыть drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReviewsPage()),
                );
              },
            ),
          ],
        ),
      ),
      body:
          _selectedPage ??
          const Center(
            child: Text(
              'Добро пожаловать в меню!',
              style: TextStyle(fontSize: 24),
            ),
          ),
    );
  }
}
