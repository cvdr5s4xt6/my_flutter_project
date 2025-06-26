import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'courier_panel.dart';
import 'menu.dart';
import 'admin_panel.dart';
import 'recover_password.dart';
import 'register.dart';
import 'user_provider.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Введите email и пароль');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, password, role')
          .eq('email', email)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        _showMessage('Пользователь не найден');
        return;
      }

      final storedPassword = response['password'] as String?;
      final userId = response['id'] as String?;
      final role = response['role'] as String?;

      if (storedPassword == null) {
        _showMessage('Пароль не установлен для пользователя');
        return;
      }

      if (storedPassword != password) {
        _showMessage('Неверный пароль');
        return;
      }

      if (userId == null || role == null) {
        _showMessage('Ошибка данных пользователя');
        return;
      }

      Provider.of<UserProvider>(context, listen: false).setUserId(userId);
      Provider.of<UserProvider>(context, listen: false).setUserEmail(email);
      _showMessage('Успешный вход!');

      if (role.toLowerCase() == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminOrdersPage()),
        );
      } else if (role.toLowerCase() == 'courier') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CourierPanelPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuPage()),
        );
      }
    } catch (e) {
      _showMessage('Ошибка входа: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('email, role, password')
          .order('role');

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Пользователи системы'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: response.length,
              itemBuilder: (_, index) {
                final user = response[index];
                final email = user['email'] ?? '';
                final role = user['role'] ?? '';
                final password = user['password'] ?? '';
                return ListTile(
                  title: Text(email),
                  subtitle: Text('Роль: $role | Пароль: $password'),
                  onTap: () {
                    Navigator.pop(context); // Закрыть диалог
                    setState(() {
                      _emailController.text = email;
                      _passwordController.text = password;
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Закрыть'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage('Ошибка загрузки пользователей: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F0FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4B0082).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Подарок',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B0082),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    // Разрешаем только латинские буквы, цифры и базовые символы email
                    FilteringTextInputFormatter.allow(
                      RegExp(r"[a-zA-Z0-9@._\-+]+"),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Введите почту',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Введите пароль',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.flash_on,
                        color: Color(0xFF4B0082),
                      ),
                      tooltip: 'Показать всех пользователей',
                      onPressed: _showAllUsers,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PasswordRecoveryPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Забыли пароль?',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B0082),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 40,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Войти', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  child: const Text(
                    'Создать аккаунт',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 40,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  child: const Text(
                    'Выйти из приложения',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
