import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum HeaderMode { main, chat }

/// Верхняя панель как `AppHeader.vue` (режимы MAIN и CHAT; админ в мобильной веб-версии скрыт).
class RescueHeader extends StatelessWidget {
  const RescueHeader({super.key, required this.mode, this.onBack});

  final HeaderMode mode;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: mode == HeaderMode.main ? _buildMain(context) : _buildChat(),
          ),
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(40, 40),
          painter: _RescueIconPainter(),
        ),
        const SizedBox(height: 4),
        Text(
          'ИИ-агент Спасатель',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          'Помощь в экстренных ситуациях 24/7',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChat() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.orange, size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Что делать при ЧС?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                'ИИ-агент на связи',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RescueIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.4;
    final fill = Paint()..color = AppColors.orange;
    canvas.drawCircle(center, r, fill);

    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, r * 0.5, ring);

    final sym = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(center.dx, center.dy - 5), 1.5, sym);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 4), width: 2, height: 8),
      sym,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
