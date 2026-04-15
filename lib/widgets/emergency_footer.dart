import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Нижняя панель как `AppFooter.vue` (ссылка на 112).
class EmergencyFooter extends StatelessWidget {
  const EmergencyFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE9ECEF))),
        ),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              height: 1.35,
            ),
            children: [
              const TextSpan(text: 'В критической ситуации всегда звоните '),
              TextSpan(
                text: '112',
                style: const TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dashed,
                  decorationColor: AppColors.orange,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    // final uri = Uri(scheme: 'tel', path: '112');
                    // if (await canLaunchUrl(uri)) {
                    //   await launchUrl(
                    //     uri,
                    //     mode: LaunchMode.externalApplication,
                    //   );
                    // }
                  },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
