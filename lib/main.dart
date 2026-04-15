import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/quiz_screen.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const RescueApp());
}

class RescueApp extends StatelessWidget {
  const RescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ИИ-агент Спасатель',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange,
          primary: AppColors.orange,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      initialRoute: '/main',
      routes: {
        '/': (_) => const HomeScreen(),
        '/main': (_) => const HomeScreen(),
        '/chat': (_) => const ChatScreen(),
        '/quiz': (_) => const QuizScreen(),
      },
    );
  }
}
