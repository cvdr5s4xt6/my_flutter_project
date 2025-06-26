import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // для FilteringTextInputFormatter
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class RegisterPage extends StatefulWidget {
  final String? userId; // Передаём userId для проверки роли

  const RegisterPage({Key? key, this.userId}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _roleFieldEnabled = false; // Можно ли менять роль (нельзя)

  @override
  void initState() {
    super.initState();
    _loadRoleByUserId();
  }

  Future<void> _loadRoleByUserId() async {
    if (widget.userId == null) {
      setState(() {
        _roleController.text = 'user';
        _roleFieldEnabled = false;
      });
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', widget.userId!)
          .maybeSingle();

      if (profile != null) {
        final role = profile['role'] as String? ?? 'user';

        setState(() {
          _roleController.text = role == 'admin' ? 'courier' : 'user';
          _roleFieldEnabled = false;
        });
      } else {
        setState(() {
          _roleController.text = 'user';
          _roleFieldEnabled = false;
        });
      }
    } catch (e) {
      setState(() {
        _roleController.text = 'user';
        _roleFieldEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки роли: ${e.toString()}')),
      );
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final passwordConfirm = _passwordConfirmController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final role = _roleController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        passwordConfirm.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty ||
        role.isEmpty) {
      _showMessage('Пожалуйста, заполните все поля');
      return;
    }

    if (password != passwordConfirm) {
      _showMessage('Пароли не совпадают');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Некорректный email');
      return;
    }

    try {
      var uuid = const Uuid();
      String id = uuid.v4();

      final response = await _supabase.from('profiles').insert({
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'role': role,
        'password': password,
      });

      _showMessage('Регистрация успешна!');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Произошла ошибка: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLabeledField(
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 16),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[300],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(color: enabled ? Colors.black : Colors.grey[700]),
    );
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
                  'Регистрация',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B0082),
                  ),
                ),
                const SizedBox(height: 32),

                // Имя - разрешены только буквы a-zA-Z и кириллица
                _buildLabeledField(
                  'Имя',
                  _firstNameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[а-яА-Яa-zA-ZёЁ]'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Фамилия - тоже только буквы
                _buildLabeledField(
                  'Фамилия',
                  _lastNameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[а-яА-Яa-zA-ZёЁ]'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildLabeledField(
                  'Введите user',
                  _roleController,
                  enabled: _roleFieldEnabled,
                ),
                const SizedBox(height: 16),

                // Почта - запрет русских букв, разрешены английские и спецсимволы для email
                _buildLabeledField(
                  'Почта',
                  _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[а-яА-ЯёЁ]')),
                  ],
                ),
                const SizedBox(height: 16),

                // Пароль
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Пароль',
                    hintStyle: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 16,
                    ),
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
                const SizedBox(height: 16),

                // Подтверждение пароля
                TextField(
                  controller: _passwordConfirmController,
                  obscureText: _obscurePasswordConfirm,
                  decoration: InputDecoration(
                    hintText: 'Подтвердите пароль',
                    hintStyle: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePasswordConfirm = !_obscurePasswordConfirm;
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
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
                  onPressed: _signUp,
                  child: const Text(
                    'Зарегистрироваться',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Уже есть аккаунт? Войти',
                    style: TextStyle(color: Colors.red),
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
