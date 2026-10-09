// Confere a distribuição das telas no celular: abre cada tela em tamanhos de
// celular pequenos (e com letra maior) e falha se algo transbordar (os avisos
// "RenderFlex overflowed" do Flutter) ou se um texto for cortado com "…".
// Usa a fonte de verdade (Roboto) para medir igual ao celular.
// SHOTS=pasta: também salva uma imagem de cada tela (360x640) para conferir.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/main.dart' show siteTheme;
import 'package:pocket_dex/models/team.dart';
import 'package:pocket_dex/providers/favorites_provider.dart';
import 'package:pocket_dex/providers/theme_provider.dart';
import 'package:pocket_dex/screens/collection_screen.dart';
import 'package:pocket_dex/screens/battle_tools_screen.dart';
import 'package:pocket_dex/screens/breeding_help_screen.dart';
import 'package:pocket_dex/screens/damage_calc_screen.dart';
import 'package:pocket_dex/screens/encyclopedia_screen.dart';
import 'package:pocket_dex/screens/ev_counter_screen.dart';
import 'package:pocket_dex/screens/favorites_screen.dart';
import 'package:pocket_dex/screens/friends_screen.dart';
import 'package:pocket_dex/screens/game_screen.dart';
import 'package:pocket_dex/screens/home_screen.dart';
import 'package:pocket_dex/screens/login_screen.dart';
import 'package:pocket_dex/screens/moves_encyclopedia_screen.dart';
import 'package:pocket_dex/screens/items_encyclopedia_screen.dart';
import 'package:pocket_dex/screens/abilities_encyclopedia_screen.dart';
import 'package:pocket_dex/screens/nature_guide_screen.dart';
import 'package:pocket_dex/screens/pokedex_screen.dart';
import 'package:pocket_dex/screens/tools/counters_screen.dart';
import 'package:pocket_dex/screens/tools/speed_tiers_screen.dart';
import 'package:pocket_dex/screens/tools/tera_raid_screen.dart';
import 'package:pocket_dex/screens/egg_chain_screen.dart';
import 'package:pocket_dex/screens/battle_center_screen.dart';
import 'package:pocket_dex/widgets/team_image.dart';
import 'package:pocket_dex/screens/pokemon_detail_screen.dart';
import 'package:pocket_dex/screens/quiz_screen.dart';
import 'package:pocket_dex/screens/settings_screen.dart';
import 'package:pocket_dex/screens/team_builder_screen.dart';
import 'package:pocket_dex/screens/teams_screen.dart';
import 'package:pocket_dex/screens/tools/iv_calc_screen.dart';
import 'package:pocket_dex/screens/tools/nuzlocke_screen.dart';
import 'package:pocket_dex/screens/tools/shiny_hunt_screen.dart';
import 'package:pocket_dex/screens/tools/type_chart_screen.dart';
import 'package:pocket_dex/screens/training_screen.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/screens/factory_panels.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/auth_service.dart';
import 'package:pocket_dex/services/user_data.dart';
import 'package:pocket_dex/utils/site_ui.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final screens = <String, Widget Function()>{
  'Início': () => const HomeScreen(),
  'Imagem do time': () => const Scaffold(
        body: FittedBox(
          child: TeamImageCard(
            name: 'Areia',
            color: '#C0712B',
            pokemon: [445, 6, 9, null, 25, 248],
            sets: [
              {
                'item': 'choice-scarf',
                'ability': 'rough-skin',
                'tera': 'ground',
                'moves': ['earthquake', 'dragon-claw', 'stone-edge', 'swords-dance']
              },
              {
                'nickname': 'Zard',
                'moves': ['flamethrower', 'air-slash', '', '']
              },
              null,
              null,
              {
                'shiny': true,
                'item': 'light-ball',
                'moves': ['thunderbolt']
              },
              null,
            ],
            names: {445: 'garchomp', 6: 'charizard', 9: 'blastoise', 25: 'pikachu', 248: 'tyranitar'},
          ),
        ),
      ),
  'Pokédex': () => const PokedexScreen(),
  'Faixas de velocidade': () => const SpeedTiersScreen(),
  'Tera Raids': () => const TeraRaidScreen(),
  'Golpes de ovo': () => const EggChainScreen(),
  'Centro de Batalha': () => const BattleCenterScreen(),
  'Quem vence': () => const CountersScreen(),
  'Filtros da Pokédex': () => const PokedexScreen(),
  'Favoritos': () => const FavoritesScreen(),
  'Coleção': () => const Scaffold(body: CollectionView()),
  'Times': () => const TeamsScreen(),
  'Montador de time': () => TeamBuilderScreen(
        team: Team(id: 't', name: 'Time com um nome bem comprido mesmo', pokemons: [
          {'id': '6', 'imageUrl': 'pokemon/other/official-artwork/6.png'},
          {'id': '9', 'imageUrl': 'pokemon/other/official-artwork/9.png'},
          {'id': '445', 'imageUrl': 'pokemon/other/official-artwork/445.png'},
        ]),
      ),
  'Jogo': () => const GameScreen(),
  'Partida': () => const QuizScreen(),
  'Enciclopédia': () => const EncyclopediaScreen(),
  'Golpes': () => const MovesEncyclopediaScreen(),
  'Itens': () => const ItemsEncyclopediaScreen(),
  'Habilidades': () => const AbilitiesEncyclopediaScreen(),
  'Treino': () => const TrainingScreen(),
  'Natures': () => const NatureGuideScreen(),
  'Breeding': () => const BreedingHelpScreen(),
  'EVs': () => const EvCounterScreen(),
  'Comparar': () => const CompareScreen(),
  'Dano': () => const DamageCalcScreen(),
  'IVs': () => const IvCalcScreen(),
  'Tipos': () => const TypeChartScreen(),
  'Shiny': () => const ShinyHuntScreen(),
  'Nuzlocke': () => const NuzlockeScreen(),
  'Configurações': () => const SettingsScreen(),
  'Conquistas': () => const AchievementsScreen(),
  'Amigos': () => const FriendsScreen(),
  'Batalha': () => const TurnBattleScreen(),
  'Batalha por turnos': () => const TurnBattleScreen(mine: [(6, null), (9, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  'Battle Factory (resultado)': () => _factory({'exp': 120, 'money': 80, 'levels': [{'index': 0, 'from': 11, 'to': 12, 'evolved': null}], 'joy': true, 'drop': 'firium-z',
        'reward': 'leftovers', 'capture': null, 'cards': null, 'shop': null}),
  'Battle Factory (captura)': () => _factory({'exp': 120, 'money': 80, 'seen': true, 'levels': [], 'joy': false, 'capture': {'id': 4, 'level': 12, 'iv': 0, 'ev': 0, 'shiny': true}, 'cards': null, 'shop': null}),
  'Battle Factory (loja)': () => _factory({'exp': 120, 'money': 80, 'seen': true, 'levels': [], 'joy': false, 'capture': null, 'cards': null,
        'shop': ['poke-ball', 'ultra-ball', 'max-potion', 'rare-candy', 'protein', 'choice-band', 'bottle-cap']}),
  'Battle Factory (mapa)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}, {'kind': 'center'}]}),
  'Battle Factory (chefe)': () => _factory(null, {'floor': 20, 'biome': 'cave', 'options': [{'kind': 'boss'}]}),
  'Login': () => const LoginScreen(),
  'Pokémon (Charizard)': () => const PokemonDetailScreen(initialPokemonId: 6),
  'Status do Pokémon': () => const PokemonDetailScreen(initialPokemonId: 6),
  'Pokémon (Mr. Mime)': () => const PokemonDetailScreen(initialPokemonId: 122),
};

/// A Factory com uma corrida no meio (time com HP, itens extras e a Bolsa), na tela cheia da corrida.
Widget _factory(Map<String, dynamic>? pending, [Map<String, dynamic>? route]) {
  Map<String, dynamic> mon(int id, double hp, [List<String> extras = const []]) => {
        'id': id, 'level': 12, 'exp': 1728, 'nature': 'Hardy', 'hp': hp, 'item': extras.isEmpty ? null : 'choice-band', 'extras': extras,
        'ivs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 20}, 'evs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 0},
      };
  saveFactory({
    'best': 12, 'coins': 340, 'owned': [], 'shinies': [1],
    'run': {
      'seed': 7, 'floor': route?['floor'] ?? 14, 'money': 2400, 'defeated': 20, 'bosses': 1,
      'bag': {'poke-ball': 3, 'great-ball': 2, 'potion': 2, 'super-potion': 1, 'hyper-potion': 0, 'max-potion': 1, 'revive': 1},
      'team': [mon(6, 0.4, ['leftovers', 'life-orb']), mon(25, 0), mon(130, 1)],
      'teamBoost': {'hp': 0, 'atk': 0.06, 'def': 0, 'spa': 0.06, 'spd': 0, 'spe': 0}, 'mult': {'money': 1, 'exp': 1, 'shop': 1}, 'cards': ['atk'],
      'boss': {'region': 0, 'step': 2}, 'route': route, 'encounter': null, 'pending': pending,
    },
  });
  return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [FactoryScreen(onBattle: (_) async {}, onExit: () {})]));
}

// (largura, altura, escala do texto)
// Telas que abrem algo antes de conferir (ex.: a folha de filtros).
final actions = <String, Future<void> Function(WidgetTester)>{
  // Espera o Pokémon sair da Pokébola (para a foto mostrar ele no lugar).
  'Pokémon (Charizard)': (tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  'Batalha por turnos': (tester) async {
    for (var i = 0; i < 30 && find.text('LUTAR').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.text('LUTAR').evaluate().isEmpty) return;
    await tester.tap(find.text('LUTAR'));
    await tester.pump(const Duration(milliseconds: 300));
    // Um turno inteiro, com as animações dos golpes; depois o menu de golpes de novo.
    await tester.tap(find.textContaining('PP ').first);
    for (var i = 0; i < 40 && find.text('LUTAR').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    // Deixa carregar o sprite de quem entrou.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 600));
    if (find.text('LUTAR').evaluate().isNotEmpty) {
      await tester.tap(find.text('LUTAR'));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  'Filtros da Pokédex': (tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  },
};

const sizes = [(360.0, 640.0, 1.0), (320.0, 568.0, 1.0), (360.0, 740.0, 1.3)];

var hasFonts = false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'pocketdex-language': Platform.environment['LANG_APP'] ?? 'pt'});

  setUpAll(() async {
    // A Roboto e os ícones vêm do próprio Flutter instalado (sem elas o teste
    // usa uma fonte de blocos e acusa textos cortados que não existem).
    final exe = Platform.resolvedExecutable;
    final root = Platform.environment['FLUTTER_ROOT'] ?? (exe.contains('/bin/cache/') ? exe.substring(0, exe.indexOf('/bin/cache/')) : '');
    final fonts = '$root/bin/cache/dart-sdk/bin/resources/devtools/assets';
    hasFonts = File('$fonts/packages/devtools_app_shared/fonts/Roboto/Roboto-Regular.ttf').existsSync();
    Future<void> font(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        final file = File('$fonts/$f');
        if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
      await loader.load();
    }

    await font('Roboto', [
      'packages/devtools_app_shared/fonts/Roboto/Roboto-Regular.ttf',
      'packages/devtools_app_shared/fonts/Roboto/Roboto-Bold.ttf',
    ]);
    await font('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
    await I18n.load();
    await UserData.instance.load();
    await SpriteBoxes.load();
    await AppSettings.instance.load();
  });

  final problems = <String>[];
  tearDownAll(() {
    if (problems.isNotEmpty) fail('Telas cortadas no celular:\n${problems.join('\n')}');
  });

  for (final entry in screens.entries) {
    for (final (w, h, scale) in sizes) {
      testWidgets('${entry.key} em ${w.toInt()}x${h.toInt()} (texto ×$scale)', (tester) async {
        if (!hasFonts) return markTestSkipped('Sem a fonte Roboto do Flutter: não dá para medir os textos.');
        tester.view.physicalSize = Size(w * 3, h * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final errors = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed') || text.contains('RenderFlex')) {
            errors.add(text.split('\n').first);
          }
        };
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: AuthService.instance),
            ChangeNotifierProvider.value(value: AppSettings.instance),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: RepaintBoundary(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _theme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: entry.value(),
            ),
          ),
        ));
        // Dados do banco carregam em segundo plano.
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
          await tester.pump(const Duration(milliseconds: 300));
        }
        try {
          await actions[entry.key]?.call(tester);
        } catch (e) {
          errors.add('não deu para abrir: ${e.toString().split('\n').first}');
        }
        FlutterError.onError = original;
        // Textos cortados com "…" (ou que não cabem numa linha só).
        for (final r in tester.allRenderObjects.whereType<RenderParagraph>()) {
          final text = r.text.toPlainText().trim();
          if (text.isEmpty || !r.hasSize) continue;
          final single = r.maxLines == 1 || !r.softWrap;
          final cut = r.didExceedMaxLines || (single && r.getMaxIntrinsicWidth(double.infinity) > r.size.width + 1);
          if (cut) errors.add('texto cortado: "${text.length > 50 ? '${text.substring(0, 50)}…' : text}"');
        }
        final dir = Platform.environment['SHOTS'];
        if (dir != null && w == 360 && scale == 1.0) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File('$dir/${entry.key.replaceAll(RegExp(r'[^\w]+'), '_')}.png').writeAsBytesSync(png!.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(const SizedBox());
        for (final e in errors.toSet()) {
          problems.add('${entry.key} ${w.toInt()}x${h.toInt()} ×$scale: $e');
        }
      });
    }
  }
}

/// Tema do app com a fonte Roboto em tudo (no teste a fonte padrão é outra).
ThemeData _theme() {
  final t = siteTheme(SiteColors.dark, Brightness.dark);
  return t.copyWith(
    textTheme: t.textTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: t.appBarTheme.copyWith(titleTextStyle: t.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto')),
  );
}
