import 'package:flutter/material.dart';

import '../widgets/emergency_footer.dart';
import '../widgets/orange_buttons.dart';
import '../widgets/rescue_header.dart';

/// Главная как `MainPage.vue` (без PWA-кнопки — в нативном приложении не нужна).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const RescueHeader(mode: HeaderMode.main),
          Expanded(
            child: Container(
              color: Colors.white,
              width: double.infinity,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OrangeFilledButton(
                          label: 'Что делать при ЧС?',
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/chat'),
                        ),
                        const SizedBox(height: 12),
                        OrangeFilledButton(
                          label: 'Сообщить о проблеме',
                          onPressed: () {},
                        ),
                        const SizedBox(height: 12),
                        OrangeOutlineButton(
                          label: 'Проверить свои знания',
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/quiz'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нажмите "Что делать при ЧС?" для получения помощи от ИИ-агента',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Для экстренной связи нажмите "Сообщить о проблеме"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const EmergencyFooter(),
        ],
      ),
    );
  }
}
