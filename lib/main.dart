import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/auth_page.dart';
import 'pages/user_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ocekthkqeiklcruzywmz.supabase.co', // твой URL Supabase
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9jZWt0aGtxZWlrbGNydXp5d216Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgxNzQ0NjQsImV4cCI6MjA2Mzc1MDQ2NH0.bE3K9J2UZTc7QUnn7CzS06UXXxyOFdvkj3t0frd_ogM', // твой anonKey из Supabase
  );

  runApp(
    ChangeNotifierProvider(create: (_) => UserProvider(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Подарочные коробки',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4B0082),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4B0082),
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthPage(),
    );
  }
}
