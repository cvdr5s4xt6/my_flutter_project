import 'package:flutter/material.dart';
import 'auth_page.dart';
import 'big_box_page.dart';

import 'package:provider/provider.dart';
import 'user_provider.dart';

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
    Navigator.pop(context); // Закрыть меню
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;
    print('Текущий userId: $userId');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // скрываем стрелку назад
        title: Text(_appBarTitle),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.yellow),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
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
                // Переход на страницу авторизации
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
          const SizedBox(width: 12), // отступ справа
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
                  onTap: () =>
                      _selectPage(const BigBoxPage(), 'Большая коробка'),
                ),
                ListTile(
                  title: const Text(
                    'Средняя коробка',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () =>
                      _selectPage(const BigBoxPage(), 'Средняя коробка'),
                ),
                ListTile(
                  title: const Text(
                    'Маленькая коробка',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () =>
                      _selectPage(const BigBoxPage(), 'Маленькая коробка'),
                ),
              ],
            ),
            ExpansionTile(
              collapsedIconColor: Colors.white,
              iconColor: Colors.white,
              textColor: Colors.white,
              collapsedTextColor: Colors.white,
              title: const Text('2 Раздел Сладости'),
              children: [
                ExpansionTile(
                  collapsedIconColor: Colors.white70,
                  iconColor: Colors.white70,
                  textColor: Colors.white70,
                  collapsedTextColor: Colors.white70,
                  title: const Text('Конфеты'),
                  children: [
                    ListTile(
                      title: const Text(
                        'Чёрный',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () => _selectPage(const BigBoxPage(), 'Черный'),
                    ),
                    ListTile(
                      title: const Text(
                        'Молочный',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () => _selectPage(const BigBoxPage(), 'Молочный'),
                    ),
                    ListTile(
                      title: const Text(
                        'Белый',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () => _selectPage(const BigBoxPage(), 'Белый'),
                    ),
                  ],
                ),
                ExpansionTile(
                  collapsedIconColor: Colors.white70,
                  iconColor: Colors.white70,
                  textColor: Colors.white70,
                  collapsedTextColor: Colors.white70,
                  title: const Text('Мармелад'),
                  children: [
                    ListTile(
                      title: const Text(
                        'Сладкий',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () => _selectPage(const BigBoxPage(), 'Сладкий'),
                    ),
                    ListTile(
                      title: const Text(
                        'Кислый',
                        style: TextStyle(color: Colors.white54),
                      ),
                      onTap: () => _selectPage(const BigBoxPage(), 'Кислый'),
                    ),
                  ],
                ),
              ],
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
