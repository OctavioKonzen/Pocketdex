// lib/services/daily_widget.dart
//
// Widget da tela inicial do Android com o Pokémon do dia
// (android/app/src/main/kotlin/.../DailyPokemonWidget.kt). Ao abrir o app,
// guardamos o nome e o sprite dos próximos 7 dias; o widget mostra o de hoje
// sozinho, mesmo sem abrir o app de novo.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:home_widget/home_widget.dart';

import '../i18n/i18n.dart';
import '../utils/app_images.dart';
import '../utils/string_extensions.dart';
import 'daily_pokemon.dart';
import 'league.dart';
import 'local_database.dart';

class DailyWidget {
  DailyWidget._();

  static const _android = 'com.octaviokonzen.pocketdex.DailyPokemonWidget';

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> update() async {
    if (!supported) return;
    try {
      await HomeWidget.saveWidgetData<String>('label', tr('Pokémon do dia'));
      final now = DateTime.now().toUtc();
      for (var i = 0; i < 7; i++) {
        final day = League.dayKey(now.add(Duration(days: i)));
        final id = DailyPokemon.idFor(day);
        final row = await LocalDatabase.instance.pokemonRow(id);
        final name = I18n.pokemonName(((row?['name'] as String?) ?? '#$id').split('-').first.capitalise());
        await HomeWidget.saveWidgetData<String>('d_${day}_name', '$name  #${id.toString().padLeft(3, '0')}');
        final sprite = await rootBundle.load(AppImages.pokemonSprite(id));
        await HomeWidget.saveFile('d_${day}_img', sprite.buffer.asUint8List(), extension: 'png');
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _android);
    } catch (e) {
      debugPrint('Widget do Pokémon do dia: $e');
    }
  }
}
