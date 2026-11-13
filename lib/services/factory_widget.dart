// lib/services/factory_widget.dart
//
// Widget da tela inicial do Android com as missões do dia do Pokelike
// (android/app/src/main/kotlin/.../FactoryMissionsWidget.kt). Guardamos o
// texto das missões dos próximos 7 dias (são as mesmas para todos, sorteadas
// pela data) e o progresso de hoje; o widget mostra as do dia sozinho, mesmo
// sem abrir o app de novo (as de um dia novo começam do zero).

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../i18n/i18n.dart';
import 'factory_daily.dart';
import 'league.dart';

class FactoryWidget {
  FactoryWidget._();

  static const _android = 'com.octaviokonzen.pocketdex.FactoryMissionsWidget';

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String? _last;

  /// Atualiza o widget com o progresso da Factory [factory] (a meta da conta).
  static Future<void> update(Map? factory) async {
    if (!supported) return;
    try {
      final now = DateTime.now().toUtc();
      final today = League.dayKey(now);
      final state = FactoryDaily.stateOf(factory, today);
      final data = <String, String>{'title': '🎲 ${tr('Missões de hoje')}', 'empty': tr('Abra o PocketDex')};
      for (var i = 0; i < 7; i++) {
        final day = League.dayKey(now.add(Duration(days: i)));
        for (final (k, m) in FactoryDaily.of(day).indexed) {
          final value = day == today ? ((state['p'] as Map)[m.kind] as num?)?.toInt() ?? 0 : 0;
          final done = day == today && (state['done'] as List).contains(m.kind);
          data['m_${day}_$k'] = tr(m.label).replaceAll('{0}', '${m.count}');
          data['m_${day}_${k}_p'] = '${value.clamp(0, m.count)}';
          data['m_${day}_${k}_n'] = '${m.count}';
          data['m_${day}_${k}_c'] = '🪙${m.coins}';
          data['m_${day}_${k}_d'] = done ? '1' : '0';
        }
      }
      final key = data.toString();
      if (key == _last) return;
      _last = key;
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _android);
    } catch (e) {
      debugPrint('Widget do Pokelike: $e');
    }
  }
}
