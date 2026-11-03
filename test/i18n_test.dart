import 'package:flutter/material.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/i18n/text.dart';
import 'package:pocket_dex/services/local_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language': 'pt'});

  setUpAll(I18n.load);
  tearDown(() => I18n.setLanguage('pt'));

  test('português: textos originais (com os ajustes do dicionário)', () {
    expect(I18n.language, 'pt');
    expect(tr('Configurações'), 'Configurações');
    expect(tr('Base Stats'), 'Status base');
    expect(tr('Bulbasaur'), 'Bulbasaur');
  });

  test('francês: textos, modelos e nomes dos Pokémon', () async {
    await I18n.setLanguage('fr');
    expect(tr('Configurações'), 'Paramètres');
    expect(tr('(Level 16)'), '(Niveau 16)');
    expect(tr('Bulbasaur'), 'Bulbizarre');
    expect(tr('  Configurações '), ' Paramètres ');
    // Texto com quebra de linha também é encontrado no dicionário.
    expect(tr('Você ainda não favoritou nenhum Pokémon.\nToque duas vezes em um card na Pokédex para adicioná-lo!'), isNot(contains('favoritou')));
    expect(I18n.nameMatches('bulbasaur', 'bulbiz'), isTrue);
    expect(I18n.nameMatches('bulbasaur', 'bulba'), isTrue);
    expect(I18n.nameMatches('bulbasaur', 'salamè'), isFalse);
  });

  test('descrições no idioma escolhido', () async {
    await I18n.setLanguage('es');
    final species = await LocalDatabase.instance.speciesJson('1');
    expect(species!['flavor_text_entries'][0]['flavor_text'], contains('semilla'));
    final move = await LocalDatabase.instance.moveJson('pound');
    expect(move!['effect_entries'][0]['short_effect'], 'Golpea con las patas o la cola.');
  });

  testWidgets('Text mostra a tradução e muda com o idioma', (tester) async {
    await tester.runAsync(() => I18n.setLanguage('en'));
    await tester.pumpWidget(const MaterialApp(home: Text('Configurações')));
    expect(find.text('Settings'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: Text.rich(TextSpan(text: 'Configurações'))));
    expect(find.text('Settings', findRichText: true), findsOneWidget);
  });
}
