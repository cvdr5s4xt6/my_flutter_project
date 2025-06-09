import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  final _supabase = Supabase.instance.client;

  String? _generatedCode;
  bool _codeSent = false;
  bool _codeVerified = false;
  bool _obscurePassword = true;

  void _sendRecoveryCode() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Введите email');
      return;
    }

    _generatedCode = (Random().nextInt(9000) + 1000).toString();
    setState(() {
      _codeSent = true;
      _codeVerified = false;
      _codeController.clear();
      _newPasswordController.clear();
    });

    // В реальном приложении здесь нужно отправлять код на email пользователя
    _showMessage(
      'Код восстановления отправлен на $email\n(код для теста: $_generatedCode)',
    );
  }

  void _verifyCode() {
    if (_codeController.text.trim() == _generatedCode) {
      setState(() {
        _codeVerified = true;
      });
      _showMessage('Код подтверждён! Введите новый пароль.');
    } else {
      _showMessage('Неверный код. Попробуйте ещё раз.');
    }
  }

  Future<void> _saveNewPassword() async {
    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text;

    if (newPassword.isEmpty || newPassword.length < 6) {
      _showMessage('Пароль должен быть минимум 6 символов');
      return;
    }

    try {
      final response = await _supabase
          .from('profiles')
          .update({'password': newPassword})
          .eq('email', email)
          .select();

      if (response.isEmpty) {
        _showMessage('Пользователь с таким email не найден');
        return;
      }

      _showMessage('Пароль успешно изменён!');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Ошибка: ${e.toString()}');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // Получаем userId из провайдера (если понадобится)
    final userId = context.watch<UserProvider>().userId;

    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление пароля')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _sendRecoveryCode,
                child: const Text('Восстановить пароль'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Введите код из письма',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _verifyCode,
                  child: const Text('Подтвердить код'),
                ),
              ],
              if (_codeVerified) ...[
                const SizedBox(height: 24),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Новый пароль',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saveNewPassword,
                  child: const Text('Сохранить новый пароль'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
