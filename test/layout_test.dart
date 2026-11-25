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
import 'package:pocket_dex/widgets/tool_tabs.dart';
import 'package:pocket_dex/widgets/account_avatar.dart';
import 'package:pocket_dex/widgets/team_image.dart';
import 'package:pocket_dex/widgets/trainer_sprite.dart';
import 'package:pocket_dex/screens/pokemon_detail_screen.dart';
import 'package:pocket_dex/screens/quiz_screen.dart';
import 'package:pocket_dex/screens/settings_screen.dart';
import 'package:pocket_dex/screens/profile_screen.dart';
import 'package:pocket_dex/screens/team_builder_screen.dart';
import 'package:pocket_dex/screens/teams_screen.dart';
import 'package:pocket_dex/screens/tools/iv_calc_screen.dart';
import 'package:pocket_dex/screens/tools/nuzlocke_screen.dart';
import 'package:pocket_dex/screens/tools/shiny_hunt_screen.dart';
import 'package:pocket_dex/screens/tools/type_chart_screen.dart';
import 'package:pocket_dex/screens/training_screen.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/screens/raid_screen.dart';
import 'package:pocket_dex/screens/factory_panels.dart';
import 'package:pocket_dex/services/gym_leaders.dart';
import 'package:pocket_dex/services/trainers.dart';
import 'package:pocket_dex/services/battle_simulator.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/local_database.dart';
import 'package:pocket_dex/services/app_settings.dart';
import 'package:pocket_dex/services/auth_service.dart';
import 'package:pocket_dex/services/user_data.dart';
import 'package:pocket_dex/services/factory_run.dart';
import 'package:pocket_dex/utils/site_ui.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Telas abertas com uma cor de tema das Configurações.
const themed = {
  'Início (tema Charizard)': 6,
  'Treino (tema Metagross)': 376,
  'Configurações (tema Pikachu)': 25,
  'Pokédex (tema Gengar)': 94,
  // A moldura da batalha e do Pokelike no tema (e dourada no fundo de campeão).
  'Batalha (tema Charizard, campeão)': 6,
  'Battle Factory (mapa, tema Charizard, campeão)': 6,
};

final screens = <String, Widget Function()>{
  'Início': () => const HomeScreen(),
  // A Raid da semana: o chefe, a barra do grupo e a luta.
  'Raid da semana': () => const RaidScreen(),
  // O Início do seu jeito: Editar (a ordem e o que aparece).
  'Início: editar': () => const SettingsScreen(),
  // A escolha do treinador: o filtro de meninas (com os que só respiram, como a Dawn e a Lyra).
  'Escolher treinador (meninas)': () => const Scaffold(body: SingleChildScrollView(child: TrainerPicker())),
  'Início (tema Charizard)': () => const HomeScreen(),
  'Treino (tema Metagross)': () => const TrainingScreen(),
  'Configurações (tema Pikachu)': () => const SettingsScreen(),
  'Pokédex (tema Gengar)': () => const PokedexScreen(),
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
  'Dano e Quem vence?': () => const ToolTabs(title: 'Dano e Quem vence?', tabs: [('Dano', DamageCalcScreen()), ('Quem vence?', CountersScreen())]),
  'Breeding e Golpes de ovo': () => const ToolTabs(title: 'Breeding e Golpes de ovo', tabs: [('Breeding', BreedingHelpScreen()), ('Golpes de ovo', EggChainScreen())]),
  'Filtros da Pokédex': () => const PokedexScreen(),
  'Favoritos': () => const FavoritesScreen(),
  'Coleção': () => const Scaffold(body: CollectionView()),
  'Times': () => const TeamsScreen(),
  'Montador de time': () => TeamBuilderScreen(
        team: Team(id: 't', name: 'Time com um nome bem comprido mesmo', pokemons: [
          {'id': '6', 'imageUrl': 'pokemon/6.png'},
          {'id': '9', 'imageUrl': 'pokemon/9.png'},
          {'id': '445', 'imageUrl': 'pokemon/445.png'},
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
  // As seções começam fechadas; tocando no título, abre.
  'Configurações (Aparência aberta)': () => const SettingsScreen(),
  'Configurações (Batalha: volume da música)': () => const SettingsScreen(),
  'Conquistas': () => const AchievementsScreen(),
  'Perfil (meu)': () => const ProfileScreen(uid: 'me', mine: true),
  // Os selos da Pokédex (mais embaixo no perfil).
  'Perfil: selos da Pokédex': () => const ProfileScreen(uid: 'me', mine: true),
  'Perfil: editar': () => const ProfileScreen(uid: 'me', mine: true),
  'Perfil: trocar treinador': () => const ProfileScreen(uid: 'me', mine: true),
  'Perfil: time de defesa': () => const ProfileScreen(uid: 'me', mine: true),
  'Perfil (Mira)': () => const ProfileScreen(uid: 'me', mine: true),
  'Perfil (Hilda)': () => const ProfileScreen(uid: 'me', mine: true),
  'Amigos': () => const FriendsScreen(),
  // O menu da conta (tocando na foto no Início): só o essencial.
  'Menu da conta': () => const HomeScreen(),
  'Batalha': () => const TurnBattleScreen(),
  'Batalha por turnos': () => const TurnBattleScreen(mine: [(6, null), (9, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  'Registro da batalha': () => const TurnBattleScreen(mine: [(6, null), (9, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  // O celular deitado: a batalha e o registro lado a lado (o teste gira a tela).
  'Batalha (segurar golpe)': () => const TurnBattleScreen(mine: [(6, null), (9, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  'Batalha (tema Charizard, campeão)': () => const TurnBattleScreen(mine: [(6, null), (9, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  'Batalha (trocar)': () => const TurnBattleScreen(mine: [(6, null), (9, null), (25, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  'Batalha (trocar, deitada)': () => const TurnBattleScreen(mine: [(6, null), (9, null), (25, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  'Batalha deitada': () => const TurnBattleScreen(mine: [(6, null), (9, null)], theirs: [(3, null), (94, null)], foeName: 'Ash'),
  'Battle Factory (resultado)': () => _factory({'exp': 120, 'money': 80, 'levels': [{'index': 0, 'from': 11, 'to': 12, 'evolved': null}], 'joy': true, 'drop': 'firium-z',
        'reward': 'leftovers', 'capture': null, 'cards': null, 'shop': null}),
  'Battle Factory (captura)': () => _factory({'exp': 120, 'money': 80, 'seen': true, 'levels': [], 'joy': false, 'capture': {'id': 4, 'level': 12, 'iv': 0, 'ev': 0, 'shiny': true}, 'cards': null, 'shop': null}),
  'Battle Factory (loja)': () => _factory({'exp': 120, 'money': 80, 'seen': true, 'levels': [], 'joy': false, 'capture': null, 'cards': null,
        'shop': ['poke-ball', 'ultra-ball', 'max-potion', 'rare-candy', 'protein', 'choice-band', 'bottle-cap']}),
  // Fora da cidade: o vendedor ambulante (o mesmo que o Poké Mart) e quem cura no caminho (no lugar do Centro).
  'Battle Factory (vendedor na rota)': () => _factory({'mart': true, 'shop': ['poke-ball', 'great-ball', 'potion', 'super-potion', 'revive', 'escape-rope']}),
  'Battle Factory (vendedor na rota, comprando)': () => _factory({'mart': true, 'shop': ['poke-ball', 'great-ball', 'potion', 'super-potion', 'revive', 'escape-rope']}),
  'Battle Factory (cura na rota)': () => _factory({'center': true}),
  // O PC do Centro Pokémon da cidade: o time à esquerda e a caixa 6×6 à direita.
  'Battle Factory (PC do Centro)': () => _factory({'center': true, 'town': true}, null, {
        'scene': 'center',
        'pc': [
          for (final id in [133, 147, null, 7, 1, null, 92, 63])
            id == null ? null : {'id': id, 'level': 10, 'exp': 1000, 'nature': 'Hardy', 'hp': 1, 'item': null, 'extras': [], 'ivs': {}, 'evs': {}},
        ],
        'pcNames': ['Dragões'],
      }),
  'Battle Factory (mapa)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}, {'kind': 'center'}]}),
  'Battle Factory (bolsa)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  'Battle Factory (time)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  'Battle Factory (time, dados)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  // Deitado: o campo à esquerda e a tela de baixo à direita (DsLayout).
  'Battle Factory (mapa, tema Charizard, campeão)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}, {'kind': 'center'}]}),
  'Battle Factory deitada': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}, {'kind': 'center'}]}),
  'Battle Factory (time) deitada': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  // Subiu de nível com 4 golpes: a pergunta e a tela dos 5 golpes (como nos jogos).
  'Battle Factory (aprender golpe)': () => _factory({'exp': 120, 'money': 80, 'levels': [{'index': 0, 'from': 12, 'to': 40, 'evolved': null}], 'joy': false}),
  'Battle Factory (subiu de nível)': () => _factory({'exp': 120, 'money': 80, 'levels': [{'index': 0, 'from': 11, 'to': 12, 'evolved': null}], 'joy': false}),
  'Battle Factory (vitória direta)': () => _factory({'exp': 120, 'money': 80, 'levels': [{'index': 0, 'from': 11, 'to': 12, 'evolved': null}], 'joy': false}),
  'Battle Factory (esquecer golpe)': () => _factory({'exp': 120, 'money': 80, 'levels': [{'index': 0, 'from': 12, 'to': 40, 'evolved': null}], 'joy': false}),
  'Battle Factory (time, golpes)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  'Battle Factory (time, opções)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  'Battle Factory (time, itens)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  'Battle Factory (chefe)': () => _factory(null, {'floor': 20, 'biome': 'cave', 'options': [{'kind': 'boss'}]}),
  // A tela inicial com a árvore de melhorias em leque (algumas compradas).
  'Battle Factory (árvore)': () {
    saveFactory({'best': 30, 'coins': 5000, 'owned': [1, 4, 7, 25, 133, 152], 'shinies': [], 'run': null, 'upgrades': {'level': 5, 'ivs': 2, 'potions': 3, 'revive': 1, 'balls': 2, 'map': 1}});
    return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [FactoryHub(onContinue: () {}, busy: false)]));
  },
  // A tela inicial: o modo da corrida e as abas trocam arrastando para o lado.
  'Battle Factory (início, modos e abas)': () {
    saveFactory({'best': 30, 'coins': 5000, 'owned': [1, 4, 7, 25, 133, 152], 'shinies': [], 'run': null, 'upgrades': {'level': 5}});
    return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [FactoryHub(onContinue: () {}, busy: false)]));
  },
  // A caça shiny: o escolhido, os encontros e quantas vezes mais comum está o shiny.
  'Battle Factory (caça shiny)': () {
    saveFactory({'best': 30, 'coins': 500, 'owned': [1, 4, 7], 'shinies': [], 'run': null, 'hunt': {'id': 133, 'count': 47, 'found': 1}});
    return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [FactoryHub(onContinue: () {}, busy: false)]));
  },
  'Battle Factory (árvore em tela cheia)': () {
    saveFactory({'best': 30, 'coins': 5000, 'owned': [1, 4, 7, 25, 133, 152], 'shinies': [], 'run': null, 'upgrades': {'level': 5, 'ivs': 2, 'potions': 3, 'revive': 1, 'balls': 2, 'map': 1}});
    return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [FactoryHub(onContinue: () {}, busy: false)]));
  },
  // O fim da corrida: os números, o MVP e o time.
  'Battle Factory (fim, resumo)': () {
    saveFactory({
      'best': 31, 'coins': 900, 'owned': [6], 'shinies': [], 'run': null,
      'last': {'floor': 31, 'coins': 420, 'summary': {'captures': 5, 'defeated': 48, 'bosses': 3, 'badges': 2, 'fallen': 1, 'team': [[6, 41, 0], [25, 38, 1], [130, 40, 0], [94, 39, 0], [3, 37, 0], [9, 40, 0]], 'mvp': [6, 41, 0]}},
    });
    return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [FactoryScreen(onBattle: (_) async {}, onExit: () {})]));
  },
  // Visto × capturado: o Bulbasaur capturado e o Ivysaur só visto.
  'Pokédex (visto e capturado)': () {
    UserData.instance.update({'league': {...UserData.instance.league, 'factory': {...FactoryRun.of(UserData.instance.league), 'caught': [1], 'seen': [2]}}});
    return const PokedexScreen();
  },
  // Rodada 15: o HUD do mapa (hora, clima, efeito, estação, o lendário que foge e o plano vilão), os corações de
  // amizade, o ovo misterioso, o mapa da região e os avisos do plano atrapalhado e da Liga sem desmaios.
  'Battle Factory (HUD do mapa)': () => _factory(null, {'floor': 23, 'biome': 'forest', 'options': [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}, {'kind': 'wildboss', 'legend': 244, 'roam': true}]},
      {'leg': 21, 'townMap': true, 'boss': {'region': 0, 'step': 1}}),
  'Battle Factory (HUD na rota)': () => _factory(null, {'floor': 24, 'biome': 'grass', 'options': [{'kind': 'wild', 'biome': 'grass'}]}, {'leg': 21, 'boss': {'region': 0, 'step': 1}}),
  'Battle Factory (amizade e ovo misterioso)': () => _factory(null, {'floor': 24, 'biome': 'grass', 'options': [{'kind': 'wild', 'biome': 'grass'}]}, {
        'leg': 21,
        'eggs': [{'id': 175, 'left': 6, 'mystery': true}],
        'team': [
          for (final (id, f, extra) in [(6, 10, const <String, dynamic>{}), (447, 6, const <String, dynamic>{}), (122, 2, const <String, dynamic>{'traded': true, 'nick': 'Marcel', 'ot': 'Turner'})])
            {
              'id': id, 'level': 22, 'exp': 10648, 'nature': 'Hardy', 'hp': 1.0, 'item': null, 'extras': <String>[], 'friendship': f, ...extra,
              'ivs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 20}, 'evs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 0},
            },
        ],
      }),
  // O estojo de insígnias (como no Black & White): as ganhas girando, as que faltam em silhueta; tocar mostra o líder.
  'Battle Factory (estojo de insígnias)': () => _factory(null, {'floor': 30, 'biome': 'grass', 'options': [{'kind': 'trainer'}, {'kind': 'wild', 'biome': 'grass'}]}, {
        'boss': {'region': 0, 'step': 4},
        'badges': 3,
        'diary': [['b', 8, 'Brock'], ['b', 16, 'Misty'], ['b', 24, 'Lt. Surge']],
      }),
  'Battle Factory (mapa da região)': () => _factory(null, {'floor': 24, 'biome': 'grass', 'options': [{'kind': 'wild', 'biome': 'grass'}]}, {'leg': 21, 'boss': {'region': 0, 'step': 1}}),
  'Battle Factory (plano atrapalhado)': () => _factory({'exp': 0, 'money': 420, 'levels': [], 'joy': false, 'capture': null, 'cards': null, 'shop': null, 'plot': {'chapter': 1, 'team': 'rocket', 'item': 'ultra-ball'}, 'flawless': 'master-ball'}),
  // A história em cenas: ao chegar na cidade, antes da luta e depois de vencer (Kanto).
  'Battle Factory (cena ao chegar)': () => _factory(null, {'floor': 10, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}]}),
  'Battle Factory (cena antes da luta)': () => _factory(null, {'floor': 20, 'biome': 'grass', 'options': [{'kind': 'boss'}]}, {'boss': {'region': 0, 'step': 3}}),
  'Battle Factory (cena depois da luta)': () => _factory({'exp': 0, 'money': 420, 'levels': [], 'joy': false, 'capture': null, 'cards': null, 'shop': null,
        'beat': {'kind': 'gym', 'name': 'Misty', 'region': 'Kanto', 'city': 'Cerulean City'}}),
  'Battle Factory (cidade)': () => _factory(null, {'floor': 10, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}, {'kind': 'dungeon', 'place': 'sewer', 'scene': 'sewer'}]}),
  // A troca do morador (uma por cidade): o botão dela junto do Poké Mart, do Centro e da Creche.
  'Battle Factory (cidade, troca)': () => _factory(null, {'floor': 10, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}]}, {'town': {'leg': 1, 'shop': ['potion'], 'trade': {'want': 25, 'give': 93}}}),
  // A Safari Zone: o Pokémon, as chances e os botões (bola, isca, pedra, procurar outro, sair) numa página só.
  'Battle Factory (Safari)': () => _factory({'safari': {'balls': 7, 'left': 3, 'caught': 1, 'mon': {'id': 123, 'level': 12}, 'mood': 'angry', 'last': 'rock', 'lastId': 123}}),
  // O fóssil que o museu reviveu (a mesma tela da captura, com o Pokémon no campo).
  'Battle Factory (fóssil do museu)': () => _factory({'exp': 120, 'money': 80, 'seen': true, 'levels': [], 'joy': false, 'capture': {'id': 138, 'level': 14, 'fossil': true}, 'cards': null, 'shop': null}),
  // Celadon: a Department Store, o Game Corner, o Eevee de presente e a Pokémon Tower fechada (falta o Silph Scope).
  'Battle Factory (cidade, Celadon)': () => _factory(null, {'floor': 14, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}, {'kind': 'dungeon', 'place': 'rocket-hideout', 'scene': 'base-rocket'}, {'kind': 'dungeon', 'place': 'pok-mon-tower', 'scene': 'tower', 'needs': 'silph-scope'}]}, {'leg': 1, 'boss': {'region': 0, 'step': 7}, 'money': 5400, 'gcCoins': 120, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (Game Corner)': () => _factory(null, {'floor': 14, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}, {'kind': 'dungeon', 'place': 'rocket-hideout', 'scene': 'base-rocket'}, {'kind': 'dungeon', 'place': 'pok-mon-tower', 'scene': 'tower', 'needs': 'silph-scope'}]}, {'leg': 1, 'boss': {'region': 0, 'step': 7}, 'money': 5400, 'gcCoins': 120, 'town': {'leg': 1, 'shop': ['potion']}, 'slots': {'reels': ['🍒', '🍒', '🍒'], 'won': 6}}),
  // Fuchsia: o Move Deleter (quem esquece e qual golpe).
  'Battle Factory (Move Deleter)': () => _factory(null, {'floor': 14, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}]}, {'leg': 1, 'boss': {'region': 0, 'step': 10}, 'town': {'leg': 1, 'shop': ['potion']}}),
  // O Snorlax dormindo na rota até Fuchsia: sem a Poké Flute, só dando a volta.
  'Battle Factory (Snorlax no caminho)': () => _factory(null, {'floor': 4, 'biome': 'grass', 'options': [{'kind': 'wildboss', 'legend': 143, 'blocker': 'poke-flute'}, {'kind': 'trainer', 'around': true}]}, {'leg': 1, 'boss': {'region': 0, 'step': 10}, 'townMap': true}),
  // O item-chave do lugar (o Silph Scope do Rocket Hideout) e o prêmio da história na tela do resultado.
  'Battle Factory (item-chave)': () => _factory({'exp': 120, 'money': 80, 'levels': [], 'joy': false, 'capture': null, 'cards': null, 'shop': null, 'key': 'silph-scope', 'placeReward': 'master-ball'}),
  'Battle Factory (desafio electric)': () => _factory({'puzzle': {'kind': 'switches', 'type': 'electric', 'done': false, 'won': false, 'cols': 5, 'rows': 3, 'a': 13, 'b': 8, 'open': {}, 'found': 0, 'left': 6}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio ice)': () => _factory({'puzzle': {'kind': 'slide', 'type': 'ice', 'done': false, 'won': false, 'cols': 5, 'rows': 5, 'pos': 22, 'goal': 3, 'rocks': [0, 20, 21, 9, 11, 2], 'left': 5}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio ghost)': () => _factory({'puzzle': {'kind': 'maze', 'type': 'ghost', 'done': false, 'won': false, 'cols': 5, 'rows': 5, 'pos': 22, 'goal': 2, 'walls': [3, 4, 9], 'seen': [], 'hidden': true, 'left': 3}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio fighting)': () => _factory({'puzzle': {'kind': 'memory', 'type': 'fighting', 'done': false, 'won': false, 'seq': [3, 1, 2, 1, 2], 'shown': true, 'at': 0}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio fire)': () => _factory({'puzzle': {'kind': 'quiz', 'type': 'fire', 'done': false, 'won': false, 'qs': [{'q': 'hasType', 'type': 'ice', 'options': [740, 323, 1008, 543], 'answer': 0}, {'q': 'hasType', 'type': 'psychic', 'options': [28, 382, 102, 318], 'answer': 2}, {'q': 'strong', 'type': 'normal', 'options': ['steel', 'fighting', 'psychic', 'bug'], 'answer': 1}], 'at': 0, 'right': 0}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio normal)': () => _factory({'puzzle': {'kind': 'silhouette', 'type': 'normal', 'done': false, 'won': false, 'qs': [{'mon': 106, 'options': [180, 106, 469, 627], 'answer': 1}, {'mon': 909, 'options': [875, 579, 959, 909], 'answer': 3}, {'mon': 291, 'options': [942, 437, 291, 697], 'answer': 2}], 'at': 0, 'right': 0}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  // As ações da rota (pescar, sacudir a árvore, o mel, o vaso de frutas, a bicicleta e o álbum) e o álbum aberto.
  'Battle Factory (ações da rota)': () => _factory(null, {'floor': 3, 'biome': 'forest', 'options': [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}]}, {'leg': 1, 'keyItems': ['super-rod', 'bicycle'], 'berry': {'floor': 0, 'item': 'sitrus-berry', 'need': 3, 'count': 3}, 'photos': [{'floor': 2, 'scene': 'forest', 'kind': 'capture', 'id': 25, 'shiny': true}, {'floor': 9, 'scene': 'town-mountain', 'kind': 'gym', 'id': 4, 'name': 'Brock'}]}),
  'Battle Factory (cartão do treinador)': () => _factory(null, {'floor': 3, 'biome': 'forest', 'options': [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}]}, {'leg': 1, 'badges': 2, 'defeated': 31, 'bosses': 4}),
  'Battle Factory (Pokédex)': () => _factory(null, {'floor': 3, 'biome': 'forest', 'options': [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}]}, {'leg': 1, 'dex': [4, 16, 25]}),
  'Battle Factory (álbum)': () => _factory(null, {'floor': 3, 'biome': 'forest', 'options': [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}]}, {'leg': 1, 'photos': [{'floor': 2, 'scene': 'forest', 'kind': 'capture', 'id': 25, 'shiny': true}, {'floor': 9, 'scene': 'town-mountain', 'kind': 'gym', 'id': 4, 'name': 'Brock'}, {'floor': 6, 'scene': 'cave', 'kind': 'capture', 'id': 74}]}),
  // Os desafios dos líderes (cada um o seu): pedra, teleporte, barreiras, luzes, pares, setas, escuro, conta, memória de 6.
  'Battle Factory (desafio Brock)': () => _factory({'puzzle': {"kind": "boulder", "type": "rock", "gym": "Brock", "done": false, "won": false, "cols": 5, "rows": 4, "walls": [2, 14], "pos": 18, "box": 12, "goal": 6, "left": 9}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Sabrina)': () => _factory({'puzzle': {"kind": "teleport", "type": "rock", "gym": "Sabrina", "done": false, "won": false, "cols": 2, "rows": 2, "rooms": 9, "room": 6, "goal": 8, "warps": [3, 6, 3, 6, 5, 7, 5, 0, 8, 3, 8, 7, 4, 6, 1, 2, 6, 0, 0, 3, 7, 4, 6, 7, 4, 4, 0, 2, 4, 6, 3, 3, 3, 4, 6, 6], "known": [-1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1], "left": 5}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Wattson)': () => _factory({'puzzle': {"kind": "gates", "type": "rock", "gym": "Wattson", "done": false, "won": false, "cols": 7, "rows": 5, "goal": 3, "walls": [5, 12, 18, 20], "red": [2, 8, 13, 16, 23, 24, 26, 27, 29], "blue": [6], "switches": [34, 32], "pos": 31, "flag": 0, "left": 10}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Olympia)': () => _factory({'puzzle': {"kind": "lights", "type": "rock", "gym": "Olympia", "done": false, "won": false, "cols": 4, "rows": 4, "on": [false, true, true, false, false, true, false, true, false, true, false, false, true, true, false, false], "sol": [13, 12, 11, 1, 3], "left": 7}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Janine)': () => _factory({'puzzle': {"kind": "pairs", "type": "rock", "gym": "Janine", "done": false, "won": false, "cols": 4, "rows": 3, "cards": [278, 602, 690, 675, 650, 690, 166, 650, 675, 166, 278, 602], "found": [], "open": [0, 1], "left": 4}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Giovanni)': () => _factory({'puzzle': {"kind": "arrows", "type": "rock", "gym": "Giovanni", "done": false, "won": false, "cols": 7, "rows": 5, "goal": 3, "walls": [5, 12, 13, 20], "arrows": [2, 2, -1, -1, -1, -1, -1, 3, -1, 2, 1, -1, -1, -1, 3, -1, -1, -1, -1, -1, -1, 2, -1, 1, 2, -1, -1, -1, 2, -1, 3, -1, -1, -1, -1], "pos": 31, "left": 8}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Brawly)': () => _factory({'puzzle': {"kind": "maze", "type": "rock", "gym": "Brawly", "done": false, "won": false, "cols": 7, "rows": 5, "pos": 31, "goal": 3, "walls": [0, 1, 4, 5, 6, 11, 12, 13, 15, 19, 24, 34], "seen": [], "hidden": false, "dark": true, "trail": [31], "left": 10}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Fantina)': () => _factory({'puzzle': {"kind": "quiz", "type": "rock", "gym": "Fantina", "done": false, "won": false, "qs": [{"q": "math", "a": 4, "b": 7, "op": "×", "nums": true, "options": [28, 25, 26, 31], "answer": 0}, {"q": "math", "a": 3, "b": 4, "op": "×", "nums": true, "options": [12, 13, 10, 11], "answer": 0}, {"q": "math", "a": 12, "b": 5, "op": "-", "nums": true, "options": [7, 6, 10, 4], "answer": 0}, {"q": "math", "a": 37, "b": 26, "op": "-", "nums": true, "options": [8, 11, 9, 14], "answer": 1}, {"q": "math", "a": 44, "b": 16, "op": "-", "nums": true, "options": [31, 28, 27, 25], "answer": 1}], "at": 0, "right": 0, "need": 4}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Chuck)': () => _factory({'puzzle': {"kind": "boulder", "type": "rock", "gym": "Chuck", "done": false, "won": false, "cols": 6, "rows": 5, "walls": [7, 14, 17, 18, 26], "pos": 2, "box": 22, "goal": 5, "left": 16}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Gardenia)': () => _factory({'puzzle': {"kind": "memory", "type": "rock", "gym": "Gardenia", "done": false, "won": false, "seq": [1, 4, 1, 4, 3, 4], "syms": 6, "shown": true, "at": 0}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  // Os mesmos com o celular deitado (o Pokelike é deitado).
  'Battle Factory (Pokédex, deitada)': () => _factory(null, {'floor': 3, 'biome': 'forest', 'options': [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}]}, {'leg': 1, 'dex': [4, 16, 25]}),
  'Battle Factory (desafio Brock, deitada)': () => _factory({'puzzle': {"kind": "boulder", "type": "rock", "gym": "Brock", "done": false, "won": false, "cols": 5, "rows": 4, "walls": [2, 14], "pos": 18, "box": 12, "goal": 6, "left": 9}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Wattson, deitada)': () => _factory({'puzzle': {"kind": "gates", "type": "rock", "gym": "Wattson", "done": false, "won": false, "cols": 7, "rows": 5, "goal": 3, "walls": [5, 12, 18, 20], "red": [2, 8, 13, 16, 23, 24, 26, 27, 29], "blue": [6], "switches": [34, 32], "pos": 31, "flag": 0, "left": 10}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Janine, deitada)': () => _factory({'puzzle': {"kind": "pairs", "type": "rock", "gym": "Janine", "done": false, "won": false, "cols": 4, "rows": 3, "cards": [278, 602, 690, 675, 650, 690, 166, 650, 675, 166, 278, 602], "found": [], "open": [0, 1], "left": 4}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (desafio Fantina, deitada)': () => _factory({'puzzle': {"kind": "quiz", "type": "rock", "gym": "Fantina", "done": false, "won": false, "qs": [{"q": "math", "a": 4, "b": 7, "op": "×", "nums": true, "options": [28, 25, 26, 31], "answer": 0}, {"q": "math", "a": 3, "b": 4, "op": "×", "nums": true, "options": [12, 13, 10, 11], "answer": 0}, {"q": "math", "a": 12, "b": 5, "op": "-", "nums": true, "options": [7, 6, 10, 4], "answer": 0}, {"q": "math", "a": 37, "b": 26, "op": "-", "nums": true, "options": [8, 11, 9, 14], "answer": 1}, {"q": "math", "a": 44, "b": 16, "op": "-", "nums": true, "options": [31, 28, 27, 25], "answer": 1}], "at": 0, "right": 0, "need": 4}}, null, {'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (cartão do treinador, deitada)': () => _factory(null, {'floor': 3, 'biome': 'forest', 'options': [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}]}, {'leg': 1, 'badges': 2, 'defeated': 31, 'bosses': 4}),
  // A evolução (como nos jogos) e a insígnia com o TM do líder.
  'Battle Factory (evolução)': () => _factory({'exp': 300, 'money': 120, 'levels': [{'index': 0, 'from': 15, 'to': 16, 'evolved': 5}], 'joy': false, 'capture': null, 'cards': null, 'shop': null}),
  'Battle Factory (insígnia)': () => _factory({'exp': 300, 'money': 900, 'levels': [], 'joy': false, 'capture': null, 'cards': null, 'shop': null, 'beat': {'kind': 'gym', 'name': 'Brock'}, 'badge': {'name': 'Brock', 'type': 'rock', 'tm': 'rock-tomb'}, 'hm': 'cut'}),
  'Battle Factory (créditos)': () => _factory({'exp': 300, 'money': 900, 'levels': [], 'joy': false, 'capture': null, 'cards': null, 'shop': null, 'beat': {'kind': 'champion', 'name': 'Blue'}, 'champion': true}, null, {'playMs': 5400000, 'badges': 8}),
  'Battle Factory (concurso)': () => _factory({'contest': {'cat': 'cool', 'index': 0, 'round': 1, 'hearts': [6], 'used': ['ember'], 'rivals': [{'name': 'Pip', 'rounds': [3, 4, 5]}, {'name': 'Coco', 'rounds': [2, 6, 2]}, {'name': 'Rocky', 'rounds': [5, 5, 5]}], 'done': false, 'last': {'move': 'ember', 'hearts': 6, 'match': true, 'repeat': false, 'cheer': true}}}, null, {'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (concurso, fim)': () => _factory({'contest': {'cat': 'cool', 'index': 0, 'round': 3, 'hearts': [6, 3, 3], 'used': ['ember', 'ember', 'tackle'], 'rivals': [{'name': 'Pip', 'rounds': [3, 4, 5]}], 'done': true, 'place': 1, 'prize': 450, 'last': {'move': 'tackle', 'hearts': 3, 'match': false, 'repeat': false, 'cheer': true}}}, null, {'town': {'leg': 1, 'shop': ['potion']}}),
  // O desafio do ginásio na cidade (o botão junto do líder).
  'Battle Factory (cidade, desafio)': () => _factory(null, {'floor': 11, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}]}, {'leg': 1, 'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion'], 'got': ['old-rod']}, 'keyItems': ['old-rod']}),
  // A missão do lendário: a pista (silhueta) e o covil no mapa.
  'Battle Factory (pista do lendário)': () => _factory({'event': {'kind': 'clue', 'legend': 150, 'clues': 2, 'lair': 'Cerulean Cave'}}, null, {'quest': {'region': 'Kanto', 'id': 150, 'clues': 2}}),
  'Battle Factory (covil do lendário)': () => _factory(null, {'floor': 5, 'biome': 'cave', 'options': [{'kind': 'trainer'}, {'kind': 'wild', 'biome': 'cave'}, {'kind': 'wildboss', 'legend': 150, 'quest': true, 'biome': 'cave'}]}, {'floor': 5, 'quest': {'region': 'Kanto', 'id': 150, 'clues': 3}}),
  'Battle Factory (missão cumprida)': () => _factory({'exp': 300, 'money': 900, 'levels': [], 'joy': false, 'capture': null, 'cards': null, 'shop': null, 'quest': {'id': 150, 'prize': 500}}, null, {'legends': [150]}),
  // A Bolsa e as categorias do Concurso com o celular deitado: tamanho fixo, tudo dentro da tela.
  'Battle Factory (bolsa, deitada)': () => _factory(null, {'floor': 14, 'biome': 'water', 'options': [{'kind': 'wild', 'biome': 'water'}, {'kind': 'ace'}]}),
  'Battle Factory (concurso, categorias, deitada)': () => _factory(null, {'floor': 11, 'biome': 'city', 'town': true, 'options': [{'kind': 'boss'}]}, {'leg': 1, 'boss': {'region': 0, 'step': 1}, 'town': {'leg': 1, 'shop': ['potion']}}),
  'Battle Factory (Safari, fim)': () => _factory({'safari': {'balls': 0, 'left': 2, 'caught': 2, 'mon': null, 'mood': null, 'last': 'broke', 'lastId': 123}}),
  'Login': () => const LoginScreen(),
  'Pokémon (Charizard)': () => const PokemonDetailScreen(initialPokemonId: 6),
  'Status do Pokémon': () => const PokemonDetailScreen(initialPokemonId: 6),
  'Pokémon (Mr. Mime)': () => const PokemonDetailScreen(initialPokemonId: 122),
};

/// A Factory com uma corrida no meio (time com HP, itens extras e a Bolsa), na tela cheia da corrida.
Widget _factory(Map<String, dynamic>? pending, [Map<String, dynamic>? route, Map<String, dynamic> extra = const {}]) {
  Map<String, dynamic> mon(int id, double hp, [List<String> extras = const []]) => {
        'id': id, 'level': 12, 'exp': 1728, 'nature': 'Hardy', 'hp': hp, 'item': extras.isEmpty ? null : 'choice-band', 'extras': extras,
        'ivs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 20}, 'evs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 0},
      };
  saveFactory({
    'best': 12, 'coins': 340, 'owned': [], 'shinies': [1],
    'run': {
      'seed': 7, 'floor': route?['floor'] ?? 14, 'money': 2400, 'defeated': 20, 'bosses': 1,
      'stash': ['choice-specs', 'sitrus-berry'],
      // Um ovo da Creche indo junto (🥚 na faixa).
      'eggs': [{'id': 1, 'left': 2}],
      'bag': {'poke-ball': 3, 'great-ball': 2, 'potion': 2, 'super-potion': 1, 'hyper-potion': 0, 'max-potion': 1, 'revive': 1},
      'team': [mon(6, 0.4, ['leftovers', 'life-orb']), mon(25, 0), mon(130, 1)],
      'teamBoost': {'hp': 0, 'atk': 0.06, 'def': 0, 'spa': 0.06, 'spd': 0, 'spe': 0}, 'mult': {'money': 1, 'exp': 1, 'shop': 1}, 'cards': ['atk'],
      'boss': {'region': 0, 'step': 2}, 'route': route, 'encounter': null, 'pending': pending,
      ...extra,
    },
  });
  return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [FactoryScreen(onBattle: (_) async {}, onExit: () {})]));
}

/// A batalha não abriu: com o motor carregado é erro (antes o teste terminava sem conferir nada).
void _noBattle() {
  if (BattleSimulator.ready) fail('A batalha não abriu (o motor das batalhas está carregado).');
}

/// Abre o TIME no menu da corrida (virando a página do menu até ele aparecer).
Future<void> _openTeam(WidgetTester tester) async {
  final team = find.byKey(const ValueKey('factory-menu-team'));
  for (var i = 0; i < 3 && team.hitTestable().evaluate().isEmpty; i++) {
    await tester.tap(find.byKey(const ValueKey('factory-menu-next')));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.tap(team);
  // O painel aparece subindo (220 ms).
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Toca num botão da cidade (virando a página do menu até ele aparecer).
Future<void> _openTown(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  // Os lugares da cidade e as ações ficam no AÇÕES (uma lista pequena que rola).
  final actions = find.byKey(const ValueKey('factory-actions'));
  if (button.evaluate().isEmpty && actions.evaluate().isNotEmpty) {
    await tester.tap(actions);
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (button.evaluate().isNotEmpty && find.byKey(const ValueKey('actions-panel')).evaluate().isNotEmpty) {
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 300));
  }
  for (var i = 0; i < 20 && button.hitTestable().evaluate().isEmpty && find.byKey(const ValueKey('factory-menu-next')).evaluate().isNotEmpty; i++) {
    await tester.tap(find.byKey(const ValueKey('factory-menu-next')));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

// (largura, altura, escala do texto)
// Telas que abrem algo antes de conferir (ex.: a folha de filtros).
final Map<String, Future<void> Function(WidgetTester)> actions = {
  // O seu perfil: trocar a foto (Pokémon ou treinador) e o treinador.
  // O botão de editar o Início fica nas Configurações (Aparência).
  'Battle Factory (PC do Centro)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('factory-pc-open')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('pc-slot-pc-0')), findsOneWidget);
    expect(find.text('💻 Dragões ✏️'), findsOneWidget);
  },
  'Início: editar': (tester) async {
    await tester.tap(find.byKey(const ValueKey('settings-section-Aparência')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey('home-edit')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('home-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home-editor')), findsOneWidget);
    // Esconde o Pokémon do dia: some do Início (e fica salvo na conta).
    await tester.tap(find.byKey(const ValueKey('home-show-daily')));
    await tester.pump();
    expect(((UserData.instance['home'] as Map)['hidden'] as List), contains('daily'));
    await tester.tap(find.byKey(const ValueKey('home-show-daily')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(((UserData.instance['home'] as Map)['hidden'] as List), isEmpty);
  },
  'Perfil: selos da Pokédex': (tester) async {
    // O banco carrega em segundo plano; a lista só monta o que está perto da tela: rola até os selos.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('profile-seals')), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-seals')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('seal-kanto')), findsOneWidget);
  },
  'Perfil: editar': (tester) async {
    await tester.tap(find.byKey(const ValueKey('profile-photo')));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  'Perfil (Mira)': (tester) async {
    UserData.instance.update({'trainer': 'mira'});
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  'Perfil (Hilda)': (tester) async {
    UserData.instance.update({'trainer': 'hilda'});
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  'Perfil: time de defesa': (tester) async {
    UserData.instance.update({
      'teams': [
        {'id': 't1', 'name': 'Time da Liga', 'color': null, 'pokemon': [6, 9, 3, 25, 143, 149], 'sets': List.filled(6, null)},
        {'id': 't2', 'name': 'Chuva', 'color': null, 'pokemon': [186, 130, 593, null, null, null], 'sets': List.filled(6, null)},
      ],
      'defenseTeam': 't1',
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey('profile-defense')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('defense-change')));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  'Perfil: trocar treinador': (tester) async {
    await tester.tap(find.byKey(const ValueKey('profile-photo')));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.byKey(const ValueKey('edit-trainer')));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  // A árvore de melhorias (mais embaixo na tela).
  'Battle Factory (árvore)': (tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('factory-tab-⬆️')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('factory-tab-⬆️')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey('skill-tree')));
    await tester.pump(const Duration(milliseconds: 300));
  },
  'Battle Factory (início, modos e abas)': (tester) async {
    expect(find.byKey(const ValueKey('factory-mode-normal')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('factory-mode')));
    await tester.ensureVisible(find.byKey(const ValueKey('factory-mode-normal')));
    await tester.pump();
    await tester.fling(find.byKey(const ValueKey('factory-mode-normal')), const Offset(-200, 0), 800);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey('factory-mode-nuzlocke')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('factory-mode-nuzlocke')));
    await tester.pump();
    await tester.fling(find.byKey(const ValueKey('factory-mode-nuzlocke')), const Offset(200, 0), 800);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('factory-mode-normal')));
    await tester.pump();
    await tester.fling(find.byKey(const ValueKey('factory-mode-normal')), const Offset(200, 0), 800);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey('factory-mode-mono')), findsOneWidget);
    expect(find.byKey(const ValueKey('factory-daily')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('factory-daily')));
    await tester.ensureVisible(find.byKey(const ValueKey('factory-daily')));
    await tester.pump();
    await tester.fling(find.byKey(const ValueKey('factory-daily')), const Offset(-200, 0), 800);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey('factory-weekly')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('factory-tab-📜')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('factory-tab-📜')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey('factory-history')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('factory-mode')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  },
  'Escolher treinador (meninas)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('trainer-filter-girl')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('trainer-hilda')), findsOneWidget);
    expect(find.byKey(const ValueKey('trainer-hilbert')), findsNothing);
    // A Dawn não é animada de frente, mas lança a Poké Ball: agora aparece.
    await tester.enterText(find.byKey(const ValueKey('trainer-search')), 'Dawn');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('trainer-dawn')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('trainer-search')), '');
    await tester.pump(const Duration(milliseconds: 300));
    // Rola até o fim da grade: os que só respiram (Leaf, May, Lyra, Dawn) ficam depois dos animados.
    await tester.drag(find.byType(GridView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  },
  'Battle Factory (caça shiny)': (tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('factory-tab-✨')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('factory-tab-✨')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const ValueKey('factory-hunt')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('hunt-count')), findsOneWidget);
    expect(find.byKey(const ValueKey('factory-daily')), findsNothing);
  },
  // A árvore na tela toda (o botão de tela cheia).
  'Battle Factory (árvore em tela cheia)': (tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('factory-tab-⬆️')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('factory-tab-⬆️')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const ValueKey('skill-tree')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('tree-full')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('skill-tree-full')), findsOneWidget);
    expect(find.byKey(const ValueKey('tree-full-close')), findsOneWidget);
  },
  'Battle Factory (HUD do mapa)': (tester) async {
    expect(find.byKey(const ValueKey('map-hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('hud-time')), findsOneWidget);
    expect(find.byKey(const ValueKey('hud-weather')), findsOneWidget);
  },
  'Battle Factory (HUD na rota)': (tester) async {
    expect(find.byKey(const ValueKey('map-hud')), findsOneWidget);
  },
  'Battle Factory (amizade e ovo misterioso)': (tester) async {
    await _openTeam(tester);
    expect(find.byKey(const ValueKey('factory-team-hearts-0')), findsOneWidget);
  },
  'Battle Factory (mapa da região)': (tester) async {
    await _openTown(tester, 'factory-menu-region');
    expect(find.byKey(const ValueKey('region-hud')), findsOneWidget);
  },
  'Battle Factory (plano atrapalhado)': (tester) async {
    expect(find.byKey(const ValueKey('factory-plot'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('factory-flawless'), skipOffstage: false), findsOneWidget);
  },
  // As ações da rota: um botão só (AÇÕES) abre a lista por cima, com o ✕.
  'Battle Factory (ações da rota)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('factory-actions')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('actions-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-actions')), findsOneWidget);
  },
  // O cartão do treinador: na AJUDA, 🪪 CARTÃO.
  'Battle Factory (cartão do treinador)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('factory-menu-help')));
    await tester.pump(const Duration(milliseconds: 300));
    // Em pé a faixa de baixo da AJUDA fica estreita (o Pokelike é deitado): toca direto no botão.
    tester.widget<InkWell>(find.byKey(const ValueKey('help-card'))).onTap!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('trainer-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-floor')), findsOneWidget);
  },
  // A Pokédex: tocar no 📖 da faixa; capturados inteiros, o resto em silhueta; tocar num abre ele à esquerda.
  'Battle Factory (Pokédex)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('factory-dex')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('dex-panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dex-2')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nº 002'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dex-gen-4')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('dex-387')), findsOneWidget);
  },
  'Battle Factory (evolução)': (tester) async {
    expect(find.byKey(const ValueKey('evo-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('evo-stop')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.byKey(const ValueKey('evo-continue')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('evo-continue')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('factory-evolved')), findsOneWidget);
  },
  // Tocando no Pokémon que segue você: o balão com o que ele sente.
  'Battle Factory (covil do lendário)': (tester) async {
    // (Em pé, as cartas dos caminhos cobrem parte dele: toca direto.)
    tester.widget<GestureDetector>(find.byKey(const ValueKey('follower-pet'))).onTap!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('follower-emote-true')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('follower-emote-true')), findsNothing);
  },
  'Battle Factory (pista do lendário)': (tester) async {
    expect(find.byKey(const ValueKey('quest-silhouette')), findsOneWidget);
    expect(find.byKey(const ValueKey('factory-event')), findsOneWidget);
  },
  'Battle Factory (missão cumprida)': (tester) async {
    expect(find.byKey(const ValueKey('factory-quest')), findsOneWidget);
  },
  'Battle Factory (insígnia)': (tester) async {
    expect(find.byKey(const ValueKey('factory-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('factory-badge-tm')), findsOneWidget);
  },
  'Battle Factory (créditos)': (tester) async {
    expect(find.byKey(const ValueKey('factory-credits')), findsOneWidget);
    // Em pé o menu fica estreito (o Pokelike é deitado): toca direto no botão.
    tester.widget<InkWell>(find.descendant(of: find.byKey(const ValueKey('credits-skip')), matching: find.byType(InkWell)).first).onTap!();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    // A troca de tela tem um fade: o resultado já está lá.
    expect(find.byKey(const ValueKey('factory-result')), findsOneWidget);
  },
  'Battle Factory (álbum)': (tester) async {
    await _openTown(tester, 'factory-album');
    expect(find.byKey(const ValueKey('album')), findsOneWidget);
  },
  'Battle Factory (desafio fire)': (tester) async {
    expect(find.byKey(const ValueKey('puzzle-question')), findsOneWidget);
  },
  'Battle Factory (Game Corner)': (tester) async {
    await _openTown(tester, 'town-corner');
    expect(find.byKey(const ValueKey('corner-spin')), findsOneWidget);
  },
  'Battle Factory (Move Deleter)': (tester) async {
    await _openTown(tester, 'town-deleter');
    expect(find.byKey(const ValueKey('deleter')), findsOneWidget);
  },
  'Battle Factory (cidade, Celadon)': (tester) async {
    // Os lugares da cidade ficam no AÇÕES.
    await tester.tap(find.byKey(const ValueKey('factory-actions')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('town-store'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('town-gift-0-133'), skipOffstage: false), findsOneWidget);
  },
  'Battle Factory (vendedor na rota, comprando)': (tester) async {
    final buy = find.byKey(const ValueKey('factory-menu-buy'));
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  },
  // A loja aberta (a lista de compras por cima do campo).
  // O time como a tela de trocar: os 6; tocando num, os dados e os itens dele.
  'Battle Factory (time)': (tester) async {
    await _openTeam(tester);
  },
  'Battle Factory (bolsa, deitada)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('factory-menu-bag')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // O botão de voltar da Bolsa fica dentro da tela (sem arrastar).
    expect(tester.getRect(find.text('↩ ${tr('Voltar')}')).bottom, lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio));
  },
  'Battle Factory (concurso, categorias, deitada)': (tester) async {
    // Deitado, o Concurso fica dentro de AÇÕES.
    if (find.byKey(const ValueKey('factory-actions')).evaluate().isNotEmpty) {
      tester.widget<InkWell>(find.descendant(of: find.byKey(const ValueKey('factory-actions')), matching: find.byType(InkWell)).first).onTap!();
      await tester.pump(const Duration(milliseconds: 400));
    }
    tester.widget<InkWell>(find.descendant(of: find.byKey(const ValueKey('town-contest')), matching: find.byType(InkWell)).first).onTap!();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('contest-team-0')));
    await tester.pump(const Duration(milliseconds: 400));
    // As 5 categorias aparecem (antes ficavam sem altura e sumiam).
    for (final cat in const ['cool', 'beauty', 'cute', 'smart', 'tough']) {
      expect(tester.getSize(find.byKey(ValueKey('contest-cat-$cat'))).height, greaterThan(20));
    }
  },
  'Battle Factory (bolsa)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('factory-menu-bag')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  },
  'Battle Factory (time, dados)': (tester) async {
    await _openTeam(tester);
    await tester.tap(find.byKey(const ValueKey('factory-team-0')));
    for (var i = 0; i < 60 && find.byKey(const ValueKey('team-pages')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const ValueKey('team-pages')), findsOneWidget);
  },
  // As páginas trocam arrastando: GOLPES e ITENS.
  'Battle Factory (time, golpes)': (tester) async {
    await actions['Battle Factory (time, dados)']!(tester);
    await tester.drag(find.byKey(const ValueKey('team-pages')), const Offset(-300, 0));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  },
  // A fala da Misty depois da luta: a plaquinha com o nome dela aparece em cima da caixa (passando as páginas).
  'Battle Factory (cena depois da luta)': (tester) async {
    for (var k = 0; k < 10 && find.byKey(const ValueKey('speaker-plate')).evaluate().isEmpty; k++) {
      await tester.tap(find.byKey(const ValueKey('factory-text')), warnIfMissed: false);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }
    expect(find.byKey(const ValueKey('speaker-plate')), findsOneWidget);
  },
  'Battle Factory (estojo de insígnias)': (tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('factory-badges')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byKey(const ValueKey('factory-badges')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.byKey(const ValueKey('case-badge-1')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    // As imagens das insígnias carregam de verdade (fora do relógio do teste).
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('case-info')), findsOneWidget);
    expect(find.textContaining('16'), findsWidgets);
  },
  'Battle Factory (time, opções)': (tester) async {
    await actions['Battle Factory (time, dados)']!(tester);
    await tester.tap(find.byKey(const ValueKey('team-tab-3')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.byKey(const ValueKey('team-actions')), findsOneWidget);
  },
  'Battle Factory (time, itens)': (tester) async {
    await actions['Battle Factory (time, dados)']!(tester);
    await tester.tap(find.byKey(const ValueKey('team-tab-2')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.byKey(const ValueKey('team-options')), findsOneWidget);
    // Tocando no item: o que ele faz aparece embaixo do nome.
    await tester.tap(find.byKey(const ValueKey('team-item-extra-0')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('item-info-extra-0')), findsOneWidget);
  },
  'Battle Factory deitada': (tester) async => expect(find.byKey(const ValueKey('ds-single')), findsOneWidget),
  'Battle Factory (time) deitada': (tester) async => _openTeam(tester),
  'Battle Factory (aprender golpe)': (tester) async {
    // Só XP e nível: o resultado passa sozinho (sem CONTINUAR) e já pergunta o golpe.
    if (find.byKey(const ValueKey('factory-continue')).evaluate().isNotEmpty) await tester.tap(find.byKey(const ValueKey('factory-continue')));
    for (var i = 0; i < 20 && find.byKey(const ValueKey('learn-yes')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('learn-yes')), findsOneWidget);
  },
  // Subiu de nível: o quadro com os atributos novos (passa sozinho ou com CONTINUAR).
  'Battle Factory (subiu de nível)': (tester) async {
    for (var i = 0; i < 10 && find.byKey(const ValueKey('level-stats')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('level-stats')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-continue')), findsOneWidget);
  },
  // Vencer só com XP e nível: sem CONTINUAR, já vai para o próximo andar com o resumo na caixa de texto.
  'Battle Factory (vitória direta)': (tester) async {
    for (var i = 0; i < 20 && find.byKey(const ValueKey('factory-note')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const ValueKey('factory-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('factory-continue')), findsNothing);
  },
  'Battle Factory (esquecer golpe)': (tester) async {
    await actions['Battle Factory (aprender golpe)']!(tester);
    await tester.tap(find.byKey(const ValueKey('learn-yes')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('forget-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('forget-confirm')), findsOneWidget);
  },
  'Configurações (Aparência aberta)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('settings-section-Aparência')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  },
  'Configurações (Batalha: volume da música)': (tester) async {
    final section = find.byKey(const ValueKey('settings-section-Batalha'));
    await tester.ensureVisible(section);
    await tester.tap(section);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final volume = find.byKey(const ValueKey('music-volume'));
    await tester.ensureVisible(volume);
    await tester.pump(const Duration(milliseconds: 300));
    expect(volume, findsOneWidget);
  },
  'Configurações (tema Pikachu)': (tester) async {
    await tester.tap(find.byKey(const ValueKey('settings-section-Aparência')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  },
  'Menu da conta': (tester) async {
    ProfileSheet.show(tester.element(find.byType(HomeScreen)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  },
  'Battle Factory (loja)': (tester) async {
    final buy = find.byKey(const ValueKey('factory-menu-buy'));
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pump();
  },
  // Espera o Pokémon sair da Pokébola (para a foto mostrar ele no lugar).
  'Pokémon (Charizard)': (tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    // Favoritar de dentro do Pokémon: a ⭐ do lado do shiny liga e desliga (o toque duplo no Pokémon faz o mesmo).
    final star = find.byKey(const ValueKey('detail-favorite'));
    if (star.evaluate().isEmpty) return;
    final favorites = Provider.of<FavoritesProvider>(tester.element(star), listen: false);
    final before = favorites.isFavorite('6');
    await tester.tap(star);
    await tester.pump();
    expect(favorites.isFavorite('6'), !before);
    await tester.tap(star);
    await tester.pump();
    expect(favorites.isFavorite('6'), before);
  },
  'Batalha por turnos': (tester) async {
    for (var i = 0; i < 30 && find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty) return _noBattle();
    await tester.tap(find.byKey(const ValueKey('battle-fight')));
    await tester.pump(const Duration(milliseconds: 300));
    // Um turno inteiro, com as animações dos golpes; depois o menu de golpes de novo.
    await tester.tap(find.textContaining('PP ').first);
    for (var i = 0; i < 40 && find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    // Deixa carregar o sprite de quem entrou.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 600));
    if (find.byKey(const ValueKey('battle-fight')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('battle-fight')));
      await tester.pump(const Duration(milliseconds: 300));
    }
  },
  'Batalha (tema Charizard, campeão)': (tester) => actions['Batalha por turnos']!(tester),
  // Segurando o golpe: a janela dele (descrição, poder, precisão, dano).
  'Batalha (segurar golpe)': (tester) async {
    for (var i = 0; i < 60 && find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty) return _noBattle();
    await tester.tap(find.byKey(const ValueKey('battle-fight')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.longPress(find.byKey(const ValueKey('battle-single-move-0')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('move-info')), findsOneWidget);
  },
  // A tela de trocar (POKÉMON): a mesma do time do Pokelike.
  'Batalha (trocar)': (tester) async {
    for (var i = 0; i < 60 && find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty) return _noBattle();
    await tester.tap(find.text('POKÉMON').last);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byKey(const ValueKey('battle-single-switch')), findsOneWidget);
  },
  'Batalha (trocar, deitada)': (tester) => actions['Batalha (trocar)']!(tester),
  'Battle Factory (Pokédex, deitada)': (tester) => actions['Battle Factory (Pokédex)']!(tester),
  'Battle Factory (cartão do treinador, deitada)': (tester) => actions['Battle Factory (cartão do treinador)']!(tester),
  // O registro aberto depois de um turno (o botão 📜).
  'Registro da batalha': (tester) async {
    await actions['Batalha por turnos']!(tester);
    // Igual à batalha: se o motor não abriu a tempo, não tem o que conferir.
    if (find.byKey(const ValueKey('battle-log')).evaluate().isEmpty) return _noBattle();
    await tester.tap(find.byKey(const ValueKey('battle-log')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  },
  // Espera a batalha abrir e confere a tela única (como no port de Black & White: o menu dentro do campo).
  'Batalha deitada': (tester) async {
    for (var i = 0; i < 30 && find.byKey(const ValueKey('battle-fight')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.byKey(const ValueKey('battle-fight')).evaluate().isNotEmpty) {
      expect(find.byKey(const ValueKey('ds-single')), findsOneWidget);
      expect(find.byKey(const ValueKey('battle-bottom-grid')), findsOneWidget);
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
    final pixel = FontLoader('PixelifySans')..addFont(Future.value(ByteData.sublistView(File('assets/fonts/PixelifySans.ttf').readAsBytesSync())));
    await pixel.load();
    await I18n.load();
    await UserData.instance.load();
    await SpriteBoxes.load();
    await AppSettings.instance.load();
    // Os dados que as telas guardam em cache (carregados aqui, fora do relógio falso de cada teste).
    // O banco e os dados da calculadora carregados aqui: guardados em cache, se a primeira tela a pedir fosse num teste
    // (com o relógio falso), as próximas ficariam esperando para sempre.
    await DamageData.load();
    await LocalDatabase.instance.movesByName();
    await LocalDatabase.instance.pokemonRow(6);
    // As tabelas que a batalha usa (cada uma vira um cache na primeira vez).
    final db = LocalDatabase.instance;
    await Future.wait([db.moveRules(), db.battleItems(), db.moveAnims(), db.npcSets(), db.speciesById(), db.defaultPokemon(), db.allPokemonRows()]);
    await Future.wait([Trainers.load(), GymLeaders.load()]);
    // O motor das batalhas (QuickJS) também: carregado só na primeira batalha, as outras esperariam para sempre.
    try {
      await BattleSimulator.load();
    } catch (_) {
      // Sem a biblioteca do QuickJS (LIBQUICKJSC_TEST_PATH): as batalhas não abrem e os testes delas só olham a tela.
    }
  });

  final problems = <String>[];
  tearDownAll(() {
    if (problems.isNotEmpty) fail('Telas cortadas no celular:\n${problems.join('\n')}');
  });

  for (final entry in screens.entries) {
    for (final (w, h, scale) in sizes) {
      testWidgets('${entry.key} em ${w.toInt()}x${h.toInt()} (texto ×$scale)', (tester) async {
        if (!hasFonts) return markTestSkipped('Sem a fonte Roboto do Flutter: não dá para medir os textos.');
        AppSettings.instance.setThemePokemon(themed[entry.key] ?? 0);
        // O fundo de campeão: liberado pelo Hall da Fama.
        if (entry.key.contains('campeão')) {
          final league = UserData.instance['league'];
          UserData.instance.update({'themeChampion': true, 'league': {...?(league as Map?), 'hall': [{'key': 'x', 'region': 'Kanto', 'team': [{'id': 6}]}]}});
          addTearDown(() => UserData.instance.update({'themeChampion': false, 'league': league}));
        }
        // "deitada": a mesma tela com o celular na horizontal.
        final landscape = entry.key.contains('deitada');
        tester.view.physicalSize = landscape ? Size(h * 3, w * 3) : Size(w * 3, h * 3);
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
  final t = siteTheme(SiteColors.forBrightness(Brightness.dark), Brightness.dark, AppSettings.instance.themeAccent);
  return t.copyWith(
    textTheme: t.textTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: t.appBarTheme.copyWith(titleTextStyle: t.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto')),
  );
}
