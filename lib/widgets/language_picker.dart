// lib/widgets/language_picker.dart
//
// Escolha do idioma do app (português, inglês, francês e espanhol).

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../services/daily_reminder.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: I18n.current,
      builder: (context, current, _) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final lang in appLanguages)
            // Os nomes dos idiomas ficam sempre na própria língua.
            ChoiceChip(
              label: Text('${lang.flag} ${lang.label}'),
              selected: lang.code == current,
              onSelected: (_) async {
                if (lang.code == current) return;
                await I18n.setLanguage(lang.code);
                // O lembrete do desafio também passa a vir no idioma novo.
                DailyReminder.instance.reschedule();
              },
            ),
        ],
      ),
    );
  }
}
