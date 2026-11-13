// lib/screens/factory_panels.dart
//
// As telas da Battle Factory (lib/services/factory_run.dart): o começo
// (escolher o inicial, comprar Pokémon e shiny com as moedas, continuar a
// corrida), a corrida em tela cheia no lugar da batalha (FactoryScreen: o
// resultado do andar, o capturado, a carta de bônus, a loja com "Continuar" e
// o mapa com os caminhos de cada andar) e a batalha de cada andar. Igual ao
// site (web-site/src/components/FactoryPanels.jsx e web-site/src/lib/factoryBattle.js).

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import 'package:share_plus/share_plus.dart';
import '../utils/hud_colors.dart';

import '../i18n/text.dart';
import '../services/account_sync.dart';
import '../services/animated_sprites.dart';
import '../services/battle_log.dart';
import '../services/battle_sounds.dart';
import '../services/damage_calc.dart';
import '../services/factory_daily.dart';
import '../services/factory_widget.dart';
import '../services/factory_run.dart';
import '../services/league.dart';
import '../services/missions_reminder.dart';
import '../services/local_database.dart';
import '../services/team_battle.dart';
import '../services/team_sets.dart';
import '../services/trainers.dart';
import '../services/turn_battle.dart';
import 'package:uuid/uuid.dart';
import '../services/user_data.dart';
import '../utils/pokemon_colors.dart';
import '../utils/site_ui.dart';
import '../widgets/battle_scene.dart';
import '../widgets/bw_bag.dart';
import '../widgets/bw_party.dart';
import '../widgets/bw_summary.dart';
import '../widgets/ds_layout.dart';
import 'region_maps.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/trainer_sprite.dart';
import '../widgets/type_chip.dart';
import 'turn_battle_screen.dart' show battleMonName, battleBarHeight, battleBottomHeight;

/// Os itens da árvore: o símbolo, o nome (do jogo, sem traduzir) e de onde cai. Igual ao site.
const pieceInfo = {
  'key-stone': ('🔮', 'Key Stone', 'chefes com Mega'),
  'sparkling-stone': ('💎', 'Sparkling Stone', 'chefes com Z-Move'),
  'comet-shard': ('☄️', 'Comet Shard', 'chefes com Dynamax, Gigantamax ou Tera'),
  'relic-crown': ('👑', 'Relic Crown', 'lendários e míticos'),
};

/// Os itens em linha ("🔮 2 · 💎 0..."), só os que têm (ou todos, com [all]).
String piecesLine(Map<String, int> pieces, {bool all = false}) =>
    [for (final e in pieces.entries) if (all || e.value > 0) '${pieceInfo[e.key]!.$1} ${e.value}'].join(' · ');

/// A Factory da conta (meta e corrida).
Json currentFactory() => FactoryRun.of(UserData.instance.league);

/// Salva a Factory na conta.
void saveFactory(Json factory) {
  // As missões do dia andam com o que mudou na corrida. Igual ao site.
  final before = currentFactory();
  factory = FactoryDaily.track(before, factory);
  // Os vistos na corrida vão para a Pokédex (visto × capturado). Igual ao site.
  factory = FactoryRun.withSeen(factory, FactoryData.loaded);
  // Acabou a corrida da semana: o andar vai para o ranking dela (uma vez, com a conta conectada). Igual ao site.
  final last = factory['last'] as Map?;
  if (last?['weekly'] != null && last?['posted'] != true) {
    factory = {...factory, 'last': {...last!, 'posted': true}};
    final floor = (last['floor'] as num?)?.toInt() ?? 0;
    if (floor > 0) AccountSync.instance.saveWeekly('${last['weekly']}', floor, 'factory');
  }
  UserData.instance.update({'league': {...UserData.instance.league, 'factory': factory}});
  // Cumpriu as três missões de hoje: o lembrete das 20h de hoje sai da agenda.
  if (MissionsReminder.doneToday(factory) && !MissionsReminder.doneToday(before)) MissionsReminder.instance.reschedule();
  // O widget das missões do dia (tela inicial do Android).
  FactoryWidget.update(factory);
}

/// Os golpes que o Pokémon (id) sabe no nível.
Future<List<String>> _movesFor(int id, int level) async {
  final row = await LocalDatabase.instance.pokemonRow(id);
  final moves = await LocalDatabase.instance.movesByName();
  if (row == null) return const ['tackle'];
  return FactoryRun.movesAt(row['moves'] as List, level, [for (final t in row['types'] as List) '$t'], moves);
}

/// A batalha do andar atual da corrida. Quem está de pé vai na frente
/// (factoryOrder: a posição de cada um no time da corrida, para ler o HP no fim).
Future<(TurnBattle, List<int>)> factoryBattle(Json run) async {
  final order = FactoryRun.battleOrder(run);
  final team = FactoryRun.teamOf(run);
  final data = await FactoryData.load();
  final mine = <Member>[
    for (final i in order) FactoryRun.memberOf(run, team[i], await _movesFor((team[i]['id'] as num).toInt(), (team[i]['level'] as num).toInt()), data)
  ];
  final theirs = <Member>[for (final f in FactoryRun.foesOf(run)) FactoryRun.foeMember(f, await _movesFor((f['id'] as num).toInt(), (f['level'] as num).toInt()))];
  final a = await TurnBattleSetup.mons(mine, battleMonName);
  final b = await TurnBattleSetup.mons(theirs, battleMonName);
  if (a.isEmpty || b.isEmpty) throw StateError('Não foi possível montar a batalha do andar.');
  final seed = ((run['seed'] as num).toInt() ^ ((run['floor'] as num).toInt() * 2654435761)) & 0xFFFFFFFF;
  // Selvagem: as Poké Balls da Bolsa funcionam (captureFor: a taxa de captura de cada um).
  // O cenário: o lugar do andar (cidade, floresta, caverna, mar...).
  // Líder de ginásio no ginásio, Elite dos Quatro e Campeão na Liga.
  // O líder no ginásio do tipo dele, a Elite dos Quatro na Liga, o Campeão na sala dele e o vilão na base da equipe.
  final scene = FactoryRun.bossScene(data, run['encounter']?['boss'] as Map?, '${run['encounter']?['scene'] ?? run['encounter']?['biome'] ?? 'grass'}');
  // E o clima do lugar (sol no deserto, chuva no mar, neve na caverna de gelo...).
  // E o efeito do lugar (terreno, chuva de diamantes, aura sombria...; no céu, ventos fortes).
  final place = FactoryRun.fieldOf(run, scene, data);
  // A barra de XP e o XP na hora: quem lutou ganha tudo; com o Exp. Share, o resto a metade.
  final kind = run['encounter']?['kind'] as String?;
  final expBar = (
    mons: [for (final i in order) (level: (team[i]['level'] as num).toInt(), exp: (team[i]['exp'] as num).toInt())],
    table: [
      for (final f in FactoryRun.foesOf(run))
        () {
          final all = FactoryRun.expShares(run, data, f, null, FactoryRun.expFactor(kind));
          return [for (final i in order) all[i]];
        }(),
    ],
    share: run['expShare'] == true ? FactoryRun.expShare : 0.0,
  );
  // A partir de certos andares, a dupla de treinadores luta em batalha dupla.
  final doubles = FactoryRun.isDoubleBattle(run);
  final battle = TurnBattle(a, b, League.seededRandom(seed),
      mode: doubles ? 'doubles' : 'singles',
      controllers: doubles ? const [['me', 'me'], ['npc1', 'npc2']] : null,
      startBags: FactoryRun.bagsFor(run),
      healPct: true,
      capture: FactoryRun.captureFor(run, data),
      startWeather: FactoryRun.weatherOf(run, scene, FactoryRun.clockOf().season, data).isNotEmpty
          ? FactoryRun.weatherOf(run, scene, FactoryRun.clockOf().season, data)
          : (place == 'wind' ? 'wind' : ''),
      startField: place == 'wind' ? '' : place,
      startExp: {
        // cap: o limite de nível do Nuzlocke (o motor para o XP nele).
        'mons': [for (final m in expBar.mons) {'level': m.level, 'exp': m.exp, if (FactoryRun.levelCapOf(data, run) != null) 'cap': FactoryRun.levelCapOf(data, run)}],
        'table': expBar.table,
        'share': expBar.share,
      })
    ..ai = 'normal'
    ..seed = seed
    ..members = (mine: BattleLog.toRecord(mine), theirs: BattleLog.toRecord(theirs))
    ..scene = scene
    // Nuzlocke com o Modo Set: sem a pergunta de trocar quando o adversário cai.
    ..noShift = FactoryRun.nuzRule(run, 'setMode');
  battle.expBar = expBar;
  // O lendário que foge: depois de roamTurns turnos, ele vai embora.
  if (FactoryRun.foesOf(run).firstOrNull?['roam'] == true) battle.fleeAfter = FactoryRun.roamTurns;
  return (battle, order);
}

/// A barra de XP de quem está na posição (slot) da batalha (0 a 1), com o que já ganhou (foeHp: o HP na tela de cada adversário). null fora da Factory. Igual ao site.
double? expBarOf(TurnBattle battle, int slot, List<int> foeHp) {
  final bar = battle.expBar;
  if (bar == null || slot >= bar.mons.length) return null;
  var extra = 0;
  for (var j = 0; j < bar.table.length; j++) {
    final hp = j < foeHp.length ? foeHp[j] : battle.teams[1][j].hp;
    if (hp > 0 && battle.captured != j) continue;
    final row = bar.table[j];
    extra += (battle.fought[j]?.contains(slot) ?? false) ? row[slot] : (row[slot] * bar.share).floor();
  }
  // Passou de nível na luta: a barra no nível novo.
  final mon = bar.mons[slot];
  final total = mon.exp + extra;
  var level = mon.level;
  while (total >= FactoryRun.expAt(level + 1)) {
    level++;
  }
  return FactoryRun.expProgress({'level': level, 'exp': total});
}

/// Como o time terminou a batalha (para winFloor): a parte do HP de cada um, na ordem da corrida, a Bolsa, se capturou o selvagem e quem lutou contra cada adversário.
({List<double> hp, Map<String, int> bag, bool captured, int? capturedIndex, List<List<int>> fought, List<int>? gained, String? ball, bool fled, double? foeHp}) factoryAfter(
    TurnBattle battle, List<int> order, Json run) {
  final hp = [for (final m in FactoryRun.teamOf(run)) FactoryRun.hpOf(m)];
  for (var slot = 0; slot < order.length && slot < battle.teams[0].length; slot++) {
    final mon = battle.teams[0][slot];
    hp[order[slot]] = mon.maxHp > 0 ? ((mon.hp < 0 ? 0 : mon.hp) / mon.maxHp * 1000).round() / 1000 : 0;
  }
  // Quem lutou contra cada adversário (posições na corrida), para o XP.
  final fought = [
    for (var j = 0; j < FactoryRun.foesOf(run).length; j++) [for (final slot in battle.fought[j] ?? const <int>[]) slot < order.length ? order[slot] : slot],
  ];
  // O XP que cada um ganhou na luta (o motor deu na hora), na ordem da corrida.
  final now = battle.expNow;
  List<int>? gained;
  if (now != null) {
    gained = List.filled(FactoryRun.teamOf(run).length, 0);
    for (final e in ((now['gained'] as Map?) ?? const {}).entries) {
      final slot = int.parse('${e.key}');
      final i = slot < order.length ? order[slot] : slot;
      if (i < gained.length) gained[i] += (e.value as num).toInt();
    }
  }
  // O lendário que fugiu: o HP que ficou (para a próxima vez).
  final foe = battle.teams[1].isEmpty ? null : battle.teams[1][0];
  final foeHp = battle.fled && foe != null && foe.maxHp > 0 ? ((foe.hp < 0 ? 0 : foe.hp) / foe.maxHp * 1000).round() / 1000 : null;
  return (
    hp: hp,
    bag: {for (final id in FactoryRun.bagItems) id: battle.bags[0][id] ?? 0},
    captured: battle.captured != null,
    capturedIndex: battle.captured,
    fought: fought,
    gained: gained,
    ball: battle.capturedBall,
    fled: battle.fled,
    foeHp: foeHp,
  );
}

/// Os capangas de cada equipe vilã (homem e mulher). Igual ao site.
const _gruntTrainers = {
  'rocket': ['sd-rocketgrunt', 'sd-rocketgruntf'], 'aqua': ['sd-aquagrunt', 'sd-aquagruntf'], 'magma': ['sd-magmagrunt', 'sd-magmagruntf'],
  'galactic': ['sd-galacticgrunt', 'sd-galacticgruntf'], 'plasma': ['sd-plasmagrunt', 'sd-plasmagruntf'], 'flare': ['sd-flaregrunt', 'sd-flaregruntf'],
  'skull': ['sd-skullgrunt', 'sd-skullgruntf'], 'aether': ['sd-aetheremployee', 'sd-aetheremployeef'], 'star': ['sd-stargrunt-s', 'sd-stargruntf-s'],
  'yell': ['sd-yellgrunt', 'sd-yellgruntf'], 'macro': ['sd-officeworker', 'sd-officeworkerf'],
};

/// Quem é o adversário do andar: o chefe (nome, treinador e música) ou um selvagem (sem treinador).
({String foeName, String? foeTrainer, Json challenge}) factoryFoe(Json run) {
  final encounter = run['encounter'] as Map;
  final boss = encounter['boss'] as Map?;
  final kind = encounter['kind'];
  // Na base de uma equipe vilã, o capanga dela.
  final grunt = _gruntTrainers[encounter['grunt']];
  return (
    // Dupla de treinadores: os dois juntos.
    foeName: '${boss?['name'] ?? (encounter['pair'] == true ? tr('Dupla de treinadores') : '')}',
    foeTrainer: (boss?['trainer'] as String?)?.isNotEmpty == true
        ? boss!['trainer'] as String
        : grunt != null
            ? grunt[((encounter['trainerSeed'] as num?)?.toInt() ?? 0) % 2]
            // Os outros treinadores: uma classe comum (Youngster, Hiker...), nunca um líder ou um personagem importante.
            : kind == 'wild' || kind == 'wildboss'
                ? null
                // A dupla de treinadores: o sprite com os dois juntos.
                : encounter['pair'] == true
                    ? 'pair:${(encounter['trainerSeed'] as num?)?.toInt() ?? 0}'
                    // Um treinador que faz sentido no lugar do encontro (nadador na água, alpinista na montanha...).
                    : 'generic:${(encounter['trainerSeed'] as num?)?.toInt() ?? 0}:${encounter['scene'] ?? ''}',
    challenge: {'kind': 'factory', 'wild': kind == 'wild' || kind == 'wildboss', if (boss != null) 'boss': Map<String, dynamic>.from(boss)},
  );
}

const _statLabel = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spa': 'SpA', 'spd': 'SpD', 'spe': 'Spe'};

/// Nome de um item da corrida (TM, pedra, Cristal Z...), como nos jogos (não traduz).
String _itemName(String id) => id.startsWith('tm:') ? 'TM ${prettySlug(id.substring(3))}' : prettySlug(id.startsWith('evo:') ? id.substring(4) : id);

/// O sprite do item (TM, ficha de serviço e Cristal Z têm nomes próprios).
Widget _itemIcon(String id, [double size = 28]) {
  final own = {'move-tutor': 'tm-case', 'move-reminder': 'heart-scale', 'dynamax-band': 'wishing-piece', 'tera-orb': 'tera-orb'}[id];
  final file = id.startsWith('tm:')
      ? 'tm-normal'
      : id.startsWith('evo:')
          ? id.substring(4)
          : own ?? (id.endsWith('-z') ? '$id--held' : id);
  return Image.asset('assets/database/sprites/items/$file.png',
      width: size, height: size, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => SizedBox(width: size, height: size));
}

/// O que cada item segurado faz na batalha (como nos jogos). Igual ao site.
const _heldEffect = {
  'choice-band': 'Ataque ×1,5, mas só usa o primeiro golpe escolhido até trocar',
  'choice-specs': 'Ataque Especial ×1,5, mas só usa o primeiro golpe escolhido até trocar',
  'choice-scarf': 'Velocidade ×1,5, mas só usa o primeiro golpe escolhido até trocar',
  'life-orb': 'Golpes 30% mais fortes; perde 10% do HP a cada ataque',
  'expert-belt': 'Golpes super efetivos 20% mais fortes',
  'muscle-band': 'Golpes físicos 10% mais fortes',
  'wise-glasses': 'Golpes especiais 10% mais fortes',
  'leftovers': 'Recupera 1/16 do HP no fim de cada turno',
  'sitrus-berry': 'Com metade do HP ou menos, come e recupera 1/4 do HP',
  'assault-vest': 'Defesa Especial ×1,5, mas só pode usar golpes de ataque',
  'rocky-helmet': 'Quem acerta um golpe de contato perde 1/6 do HP',
  'eviolite': 'Defesa e Defesa Especial ×1,5 se ele ainda pode evoluir',
  'focus-sash': 'Com o HP cheio, aguenta com 1 de HP um golpe que o derrubaria',
  'quick-claw': '20% de chance de agir primeiro no turno',
  'shell-bell': 'Recupera 1/8 do dano que causa',
  'black-sludge': 'Tipo Veneno recupera 1/16 do HP por turno; os outros perdem 1/8',
  'weakness-policy': 'Levou um golpe super efetivo: Ataque e Ataque Especial +2',
  'lum-berry': 'Cura qualquer problema de status (uma vez)',
  'scope-lens': 'Mais chance de acerto crítico (+1 nível)',
  'bright-powder': 'Golpes do adversário erram 10% mais',
  'air-balloon': 'Flutua: imune a golpes de Terra até levar um golpe',
  'heavy-duty-boots': 'Não sofre dano das armadilhas do campo (Stealth Rock, Spikes...)',
  'kings-rock': 'Golpes de dano têm 10% de chance de fazer o adversário recuar',
};

const _gimmickLabel = {'mega': 'Mega', 'z': 'Z-Move', 'dmax': 'Dynamax', 'tera': 'Tera'};

/// A categoria do golpe (na tela de esquecer golpe).
const _categoryLabel = {'physical': 'Físico', 'special': 'Especial', 'status': 'Status'};

Widget _hpBar(BuildContext context, double hp) {
  final value = hp.clamp(0.0, 1.0);
  final color = value > 0.5 ? const Color(0xFF10B981) : value > 0.2 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
  return Container(
    width: 48,
    height: 6,
    margin: const EdgeInsets.only(top: 2),
    decoration: BoxDecoration(color: SiteColors.of(context).line, borderRadius: BorderRadius.circular(3)),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(widthFactor: value, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))),
  );
}

Widget _mon(BuildContext context, Map m, {bool selected = false, VoidCallback? onTap, Key? key, String name = ''}) {
  final c = SiteColors.of(context);
  final shiny = m['shiny'] == true;
  final hp = m['hp'] == null ? null : FactoryRun.hpOf(m);
  final down = hp != null && !(hp > 0);
  final extras = (m['extras'] as List?)?.length ?? 0;
  return InkWell(
    key: key,
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 78,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? Colors.amber : Colors.transparent, width: 2),
      ),
      child: Column(children: [
        Opacity(opacity: down ? 0.4 : 1, child: SizedBox(width: 48, height: 48, child: PokemonSprite((m['id'] as num).toInt(), shiny: shiny, fill: 0.9))),
        if (name.isNotEmpty || shiny)
          FittedBox(fit: BoxFit.scaleDown, child: Text('${shiny ? '✨ ' : ''}$name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.text), maxLines: 1)),
        if (m['level'] != null) Text('Nv. ${m['level']}', style: TextStyle(fontSize: 11, color: c.muted)),
        if (hp != null) down ? Text(tr('Desmaiado'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))) : _hpBar(context, hp),
        if (m['item'] != null)
          FittedBox(fit: BoxFit.scaleDown, child: Text('${_itemName('${m['item']}')}${extras > 0 ? ' +$extras' : ''}', style: TextStyle(fontSize: 10, color: c.muted), maxLines: 1)),
      ]),
    ),
  );
}

/// O dinheiro e a Bolsa da corrida (Poké Balls e remédios).
/// As molduras da caixa de texto (loja de cosméticos). Igual ao site.
const _frameNames = {'gold': 'Dourada', 'crystal': 'Cristal', 'night': 'Noite', 'sakura': 'Sakura'};
const _frameColors = {
  'gold': (Color(0xFFF59E0B), Color(0xFFFDE68A)),
  'crystal': (Color(0xFF67E8F9), Color(0xFFA5F3FC)),
  'night': (Color(0xFF4C1D95), Color(0xFF7C3AED)),
  'sakura': (Color(0xFFF472B6), Color(0xFFFBCFE8)),
};

/// A cor de cada região (o tema dela na barra da corrida). Igual ao site.
const _regionTheme = {
  'Kanto': Color(0xFFB91C1C), 'Johto': Color(0xFFA16207), 'Hoenn': Color(0xFF15803D), 'Sinnoh': Color(0xFF1D4ED8), 'Hisui': Color(0xFF0F766E), 'Unova': Color(0xFF3F3F46),
  'Kalos': Color(0xFF0369A1), 'Alola': Color(0xFFEA580C), 'Galar': Color(0xFF7E22CE), 'Paldea': Color(0xFFBE123C),
};

BoxDecoration _frameBox(String id, bool on) {
  final (outer, inner) = _frameColors[id] ?? (const Color(0xFF334155), const Color(0xFF334155));
  return BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: outer, width: 4),
    boxShadow: [BoxShadow(color: inner, spreadRadius: -2), if (on) const BoxShadow(color: Color(0xFFFBBF24), spreadRadius: 2)],
  );
}

/// A loja de cosméticos: a Poké Ball que você joga nas batalhas e a moldura da caixa de texto. Igual ao site.
Widget _cosmeticsTile(BuildContext context, Json factory, void Function(Json?) save) {
  final c = SiteColors.of(context);
  final coins = ((factory['coins'] as num?) ?? 0).toInt();
  return Column(
    key: const ValueKey('factory-cosmetics'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr('Com as moedas: a Poké Ball que você joga nas batalhas e a moldura da caixa de texto.'), style: TextStyle(color: c.muted, fontSize: 12)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in FactoryRun.cosmeticBalls.entries)
          Builder(builder: (context) {
            final have = FactoryRun.hasCosmetic(factory, 'ball', e.key);
            final using = factory['ball'] == e.key;
            return InkWell(
              key: ValueKey('cosmetic-${e.key}'),
              borderRadius: BorderRadius.circular(10),
              onTap: !have && coins < e.value
                  ? null
                  : () => save(have ? FactoryRun.equipCosmetic(factory, 'ball', using ? null : e.key) : FactoryRun.buyCosmetic(factory, 'ball', e.key)),
              child: Container(
                width: 92,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: using ? const Color(0xFFFBBF24) : Colors.transparent, width: 2)),
                child: Column(children: [
                  Image.asset('assets/database/sprites/items/${e.key}.png', width: 28, height: 28, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => const SizedBox(height: 28)),
                  Text(prettySlug(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.text)),
                  Text(using ? '✓ ${tr('Usando')}' : have ? tr('Usar') : '🪙 ${e.value}', style: TextStyle(fontSize: 10, color: c.muted)),
                ]),
              ),
            );
          }),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in FactoryRun.cosmeticFrames.entries)
          Builder(builder: (context) {
            final have = FactoryRun.hasCosmetic(factory, 'frame', e.key);
            final using = factory['frame'] == e.key;
            return InkWell(
              key: ValueKey('frame-${e.key}'),
              onTap: !have && coins < e.value
                  ? null
                  : () => save(have ? FactoryRun.equipCosmetic(factory, 'frame', using ? null : e.key) : FactoryRun.buyCosmetic(factory, 'frame', e.key)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: _frameBox(e.key, using),
                child: Text('${tr(_frameNames[e.key]!)} · ${using ? '✓ ${tr('Usando')}' : have ? tr('Usar') : '🪙 ${e.value}'}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.text)),
              ),
            );
          }),
      ]),
    ],
  );
}

/// A corrida da semana (o torneio entre amigos): a mesma semente, o mesmo inicial e a mesma regra para todo mundo; o
/// ranking é o andar alcançado. Igual ao site.
class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.factory, required this.data, required this.names, required this.onContinue});
  final Json factory;
  final FactoryData data;
  final String Function(int) names;
  final VoidCallback onContinue;

  static const _ruleText = {
    'normal': 'Sem regra especial: chegue o mais longe que puder.',
    'nuzlocke': 'Nuzlocke: quem desmaia vai embora e só um capturado por área (rota, cidade e cada lugar).',
    'noItems': 'Sem itens: a corrida começa com a Bolsa vazia.',
  };

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final week = League.weekKey();
    final w = FactoryRun.weeklyOf(data, week);
    final logged = AccountSync.instance.uid != null;
    return Container(
      key: const ValueKey('factory-weekly'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('🏆 ${tr('Corrida da semana')}', style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
        const SizedBox(height: 6),
        Row(children: [
          SizedBox(width: 48, height: 48, child: PokemonSprite(w.starter, fill: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(names(w.starter), style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
              Text(tr(_ruleText[w.rule]!), style: TextStyle(color: c.muted, fontSize: 12)),
              Text(tr('A mesma corrida para todo mundo nesta semana: veja quem chega mais longe.'), style: TextStyle(color: c.muted, fontSize: 11)),
            ]),
          ),
          PillButton(
            key: const ValueKey('factory-weekly-start'),
            label: tr('Jogar'),
            onPressed: () {
              final next = FactoryRun.startWeekly(factory, data, week);
              if (next == null) return;
              saveFactory({...factory, 'run': next});
              onContinue();
            },
          ),
        ]),
        const SizedBox(height: 6),
        if (!logged)
          Text(tr('Entre na conta para aparecer no ranking.'), style: TextStyle(color: c.muted, fontSize: 12))
        else
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: AccountSync.instance.watchRanking(10, 'factory', week),
            builder: (context, snap) {
              final rows = snap.data ?? const [];
              if (rows.isEmpty) return Text(tr('Ninguém jogou ainda nesta semana.'), style: TextStyle(color: c.muted, fontSize: 12));
              return Column(key: const ValueKey('factory-weekly-ranking'), children: [
                for (var k = 0; k < rows.length; k++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: rows[k]['uid'] == AccountSync.instance.uid ? const Color(0x26F59E0B) : c.card, borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      Expanded(child: Text('${k + 1}. ${rows[k]['name']}', style: TextStyle(color: c.text, fontSize: 12))),
                      Text(tr('Andar {0}').replaceAll('{0}', '${rows[k]['score']}'), style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]);
            },
          ),
      ]),
    );
  }
}

Widget _runStatus(BuildContext context, Json run) {
  final c = SiteColors.of(context);
  final bag = FactoryRun.bagOf(run);
  final style = TextStyle(fontWeight: FontWeight.bold, color: c.text);
  return Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
    Text('💰 ${run['money']}', style: style),
    for (final id in FactoryRun.bagItems)
      if ((bag[id] ?? 0) > 0) Row(mainAxisSize: MainAxisSize.min, children: [_itemIcon(id, 22), Text('×${bag[id]}', style: style)]),
  ]);
}

/// Usar a Bolsa fora da batalha e o time: item principal, mecânica, ensinar golpes e itens guardados.
class _BagAndItems extends StatefulWidget {
  final Json run;
  final FactoryData data;
  final Map<int, String> names;
  final void Function(Json next) onSave;

  /// Só a Bolsa ('bag') ou só o time ('team'), já aberto (o menu da tela da corrida).
  final String? only;
  const _BagAndItems({required this.run, required this.data, required this.names, required this.onSave, this.only, this.onClose});

  /// Fechar a Bolsa (o "✕" da barra de baixo).
  final VoidCallback? onClose;

  @override
  State<_BagAndItems> createState() => _BagAndItemsState();
}

class _BagAndItemsState extends State<_BagAndItems> {

  /// Ensinar um golpe: TM (os que ele aprende por máquina), Move Tutor (tutor e ovo) ou Move Reminder (os do nível).
  Future<void> _teach(int index) async {
    final run = widget.run;
    final mon = FactoryRun.teamOf(run)[index];
    final id = (mon['id'] as num).toInt(), level = (mon['level'] as num).toInt();
    final row = await LocalDatabase.instance.pokemonRow(id);
    final learnset = [for (final m in (row?['moves'] as List?) ?? const []) m as List];
    final own = [for (final m in (mon['moves'] as List?) ?? const []) '$m'];
    final current = own.isNotEmpty ? own : await _movesFor(id, level);
    bool has(String move, List<String> ways) => learnset.any((m) => m[0] == move && ways.contains(m[1]));
    List<String> unique(Iterable<String> list) => [for (final m in {...list}) if (!current.contains(m)) m];
    final tms = (run['tms'] as Map?) ?? const {};
    final tokens = (run['tokens'] as Map?) ?? const {};
    final sources = <(String, String, List<String>)>[
      ('tm', 'TM', unique([for (final e in tms.entries) if ((e.value as num) > 0 && has('${e.key}', const ['machine'])) '${e.key}'])),
      if (((tokens['move-tutor'] as num?) ?? 0) > 0)
        ('move-tutor', 'Move Tutor', unique([for (final m in learnset) if (m[1] == 'tutor' || m[1] == 'egg') '${m[0]}'])),
      if (((tokens['move-reminder'] as num?) ?? 0) > 0)
        ('move-reminder', 'Move Reminder', unique([for (final m in learnset) if (m[1] == 'level-up' && (m[2] as num) <= level) '${m[0]}'])),
    ].where((s) => s.$3.isNotEmpty).toList();
    if (!mounted) return;
    final picked = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📀 ${tr('Ensinar golpe')}'),
        content: SizedBox(
          width: 360,
          child: sources.isEmpty
              ? Text(tr('Nada para ensinar a ele agora (TM que ele aprende ou fichas de Move Tutor/Reminder).'))
              : ListView(shrinkWrap: true, children: [
                  for (final (source, label, list) in sources) ...[
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      for (final move in list) ActionChip(label: Text(prettySlug(move)), onPressed: () => Navigator.pop(context, (move, source))),
                    ]),
                  ],
                ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancelar')))],
      ),
    );
    if (picked == null || !mounted) return;
    var slot = -1;
    if (current.length >= 4) {
      final chosen = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr('Esquecer qual golpe para aprender {0}?').replaceAll('{0}', prettySlug(picked.$1))),
          children: [for (var i = 0; i < current.length; i++) SimpleDialogOption(onPressed: () => Navigator.pop(context, i), child: Text(prettySlug(current[i])))],
        ),
      );
      if (chosen == null) return;
      slot = chosen;
    }
    final next = FactoryRun.teachMove(run, index, picked.$1, current, slot, picked.$2);
    if (next != null) widget.onSave(next);
  }

  /// O que falta escolher em quem: ('bag', item), ('stash', posição) ou ('teach', '').
  (String, String)? _using;

  /// A Bolsa como no Black & White, em bolsos: remédios em quem está ferido, Revive em quem desmaiou, segurar os itens
  /// guardados e ensinar os TMs. Igual ao site (BagPanel).
  Widget _bwBag(BuildContext context) {
    final run = widget.run;
    final team = FactoryRun.teamOf(run);
    final bag = FactoryRun.bagOf(run);
    final items = <String, List<BagEntry>>{'items': [], 'medicine': [], 'balls': [], 'tms': [], 'key': []};
    void using(String kind, String id) => setState(() => _using = (kind, id));
    for (final id in FactoryRun.bagItems) {
      if ((bag[id] ?? 0) <= 0) continue;
      final pocket = id.endsWith('-ball') ? 'balls' : id == 'revive' || FactoryRun.healShare.containsKey(id) ? 'medicine' : 'items';
      final usable = pocket == 'medicine' && [for (var i = 0; i < team.length; i++) i].any((i) => FactoryRun.applyBagItem(run, id, i) != null);
      items[pocket]!.add(BagEntry(
          id: id,
          name: prettySlug(id),
          count: bag[id],
          icon: id,
          help: _FactoryScreenState._help(id),
          onUse: pocket == 'medicine' ? () => using('bag', id) : null,
          disabled: !usable));
    }
    final stash = [for (final x in (run['stash'] as List?) ?? const []) '$x'];
    for (var k = 0; k < stash.length; k++) {
      items['items']!.add(BagEntry(
          id: 'stash:$k',
          name: _itemName(stash[k]),
          icon: stash[k],
          help: '${_FactoryScreenState._help(stash[k])} ${tr('(guardado: escolha quem segura)')}',
          use: tr('SEGURAR'),
          onUse: () => using('stash', '$k')));
    }
    for (final e in ((run['tms'] as Map?) ?? const {}).entries) {
      if ((e.value as num) > 0) {
        items['tms']!.add(BagEntry(
            id: 'tm:${e.key}', name: _itemName('tm:${e.key}'), count: (e.value as num).toInt(), icon: 'tm-normal',
            help: _FactoryScreenState._help('tm:${e.key}'), use: tr('ENSINAR'), onUse: () => using('teach', '')));
      }
    }
    for (final e in ((run['tokens'] as Map?) ?? const {}).entries) {
      if ((e.value as num) > 0) {
        items['tms']!.add(BagEntry(
            id: '${e.key}', name: prettySlug('${e.key}'), count: (e.value as num).toInt(), icon: 'tm-normal',
            help: _FactoryScreenState._help('${e.key}'), use: tr('ENSINAR'), onUse: () => using('teach', '')));
      }
    }
    for (final (flag, id) in const [('townMap', 'town-map'), ('dmax', 'dynamax-band'), ('tera', 'tera-orb'), ('expShare', 'exp-share')]) {
      if (run[flag] == true) items['key']!.add(BagEntry(id: id, name: prettySlug(id), icon: id, help: _FactoryScreenState._help(id)));
    }
    final u = _using;
    // Escolher em quem: a tela do time do Black & White, no mesmo lugar.
    if (u != null) {
      return BwParty(
        testKey: 'bag-target',
        title: u.$1 == 'stash' ? tr('Quem vai segurar?') : u.$1 == 'teach' ? tr('Ensinar a quem?') : tr('Usar em qual Pokémon?'),
        team: [
          for (final m in team)
            PartySlot(
                id: (m['id'] as num).toInt(),
                shiny: m['shiny'] == true,
                name: battleMonName({'name': widget.names[(m['id'] as num).toInt()] ?? ''}),
                level: (m['level'] as num).toInt(),
                hp: FactoryRun.hpOf(m).toDouble()),
        ],
        disabled: (i) => u.$1 == 'bag' && FactoryRun.applyBagItem(run, u.$2, i) == null,
        onPick: (i) {
          setState(() => _using = null);
          if (u.$1 == 'bag') {
            final next = FactoryRun.applyBagItem(run, u.$2, i);
            if (next != null) widget.onSave(next);
          } else if (u.$1 == 'stash') {
            widget.onSave(FactoryRun.equipFromStash(run, int.parse(u.$2), i));
          } else {
            _teach(i);
          }
        },
        onCancel: () => setState(() => _using = null),
      );
    }
    return BwBag(
      onClose: widget.onClose,
      testKey: 'factory-bag',
      onSelect: (_) => setState(() => _using = null),
      pockets: [
        BagPocket(id: 'items', label: 'Itens', img: 'leftovers', items: items['items']!),
        BagPocket(id: 'medicine', label: 'Remédios', img: 'potion', items: items['medicine']!),
        BagPocket(id: 'balls', label: 'Poké Balls', img: 'poke-ball', items: items['balls']!),
        BagPocket(id: 'tms', label: 'TMs e golpes', img: 'tm-normal', items: items['tms']!),
        BagPocket(id: 'key', label: 'Itens-chave', img: 'key-stone', items: items['key']!),
      ],
    );
  }

  /// O tocado na tela do time (os dados e os itens dele) e os dados calculados.
  int? _sel;
  Future<SummaryData?>? _selData;

  @override
  void didUpdateWidget(covariant _BagAndItems old) {
    super.didUpdateWidget(old);
    // Mudou o item (ou o time): refaz os dados de quem está aberto.
    if (_sel != null && !identical(old.run, widget.run)) {
      if (_sel! >= FactoryRun.teamOf(widget.run).length) {
        _sel = null;
      } else {
        _selData = _summary(_sel!);
      }
    }
  }

  void _open(int? i) => setState(() {
        _sel = i;
        _selData = i == null ? null : _summary(i);
      });

  /// Os dados do Pokémon da corrida (como a tela DADOS da batalha): os atributos pela conta da calculadora (com os bônus da corrida).
  Future<SummaryData?> _summary(int i) async {
    final run = widget.run;
    final mon = FactoryRun.teamOf(run)[i];
    final id = (mon['id'] as num).toInt(), level = (mon['level'] as num).toInt();
    final own = [for (final m in (mon['moves'] as List?) ?? const []) '$m'];
    final slugs = own.isNotEmpty ? own : await _movesFor(id, level);
    final member = FactoryRun.memberOf(run, mon, slugs, widget.data);
    final calc = await TeamBattle.calcPokemon(await DamageData.load(), member);
    final moves = await LocalDatabase.instance.movesByName();
    if (calc == null) return null;
    final boost = FactoryRun.boostOf(run, mon);
    int stat(String k) => (calc.rawStats[k]! * (1 + (boost[k] ?? 0))).round();
    final maxHp = stat('hp');
    return SummaryData(
      id: id,
      shiny: mon['shiny'] == true,
      // O gênero (decide evoluções como a do Combee e a do Burmy).
      name: '${battleMonName({'name': widget.names[id] ?? ''})}${switch (FactoryRun.genderOf(widget.data, mon)) { 'F' => ' ♀', 'M' => ' ♂', _ => '' }}',
      level: level,
      hp: (FactoryRun.hpOf(mon) * maxHp).round(),
      maxHp: maxHp,
      types: [for (final t in calc.types) t.toLowerCase()],
      ability: calc.ability,
      item: mon['item'] == null ? '' : _itemName('${mon['item']}'),
      stats: {for (final (k, _) in summaryStats) k: stat(k)},
      moves: [
        for (final slug in slugs)
          if (moves[slug] != null) SummaryMove(prettySlug(slug), '${moves[slug]!['type']}', (moves[slug]!['pp'] as num?)?.toInt() ?? 0, (moves[slug]!['pp'] as num?)?.toInt() ?? 0),
      ],
    );
  }

  static const _ink = Color(0xFF0F172A);

  Widget _bwButton(String label, Color color, VoidCallback? onTap, {Key? key}) => FilledButton(
        key: key,
        // Botões baixos: cabem mais itens na página (tamanho fixo).
        style: FilledButton.styleFrom(
            backgroundColor: color,
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10)),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      );

  /// O item tocado na página ITENS: mostra o que ele faz embaixo do nome.
  String? _itemInfo;

  /// Um item na lista (ícone, nome e os botões); tocando nele aparece o que ele faz.
  Widget _itemRow(String id, String name, List<Widget> actions, {Key? key, required String info, bool main = false}) => Material(
        key: key,
        color: main ? const Color(0xFFFEF3C7) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _itemInfo = _itemInfo == info ? null : info),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
            child: Row(children: [
              _itemIcon(id, 24),
              const SizedBox(width: 6),
              // Nome do item como no jogo (não traduz); tocado, o que ele faz embaixo.
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${main ? '★ ' : ''}$name ${_itemInfo == info ? '▴' : '▾'}', maxLines: 1, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                  if (_itemInfo == info && _FactoryScreenState._help(id).isNotEmpty)
                    Text(_FactoryScreenState._help(id), key: ValueKey('item-info-$info'), style: const TextStyle(color: Color(0xFF334155), fontSize: 10.5)),
                ]),
              ),
              ...actions,
            ]),
          ),
        ),
      );

  /// Os itens de quem foi aberto (a página ITENS): o principal (o efeito de verdade), os extras (só um pouco no atributo)
  /// e segurar um item guardado.
  Widget _monItems(int i) {
    final run = widget.run;
    final mon = FactoryRun.teamOf(run)[i];
    final stash = [for (final x in (run['stash'] as List?) ?? const []) '$x'];
    final extras = [for (final x in (mon['extras'] as List?) ?? const []) '$x'];
    Widget title(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 3),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
        );
    return Container(
      key: const ValueKey('team-options'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFF0F3D44), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0B2A2F), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('🎒 ${tr('Itens que ele segura')} (★ ${tr('o principal')})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
        if (mon['item'] == null && extras.isEmpty)
          Text(tr('Nenhum item. Escolha um dos guardados abaixo.'), style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
        if (mon['item'] != null)
          _itemRow('${mon['item']}', _itemName('${mon['item']}'), main: true, info: 'main', key: const ValueKey('team-item-main'), [
            _bwButton(tr('TIRAR'), const Color(0xFFDC2626), () => widget.onSave(FactoryRun.unequipItem(run, i)), key: const ValueKey('team-unequip')),
          ]),
        for (var k = 0; k < extras.length; k++)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _itemRow(extras[k], _itemName(extras[k]), info: 'extra-$k', key: ValueKey('team-item-extra-$k'), [
              _bwButton('★', const Color(0xFFD97706), () => widget.onSave(FactoryRun.setMainItem(run, i, k)), key: ValueKey('team-main-$k')),
              const SizedBox(width: 4),
              _bwButton(tr('TIRAR'), const Color(0xFFDC2626), () => widget.onSave(FactoryRun.unequipItem(run, i, k)), key: ValueKey('team-unequip-$k')),
            ]),
          ),
        if (stash.isNotEmpty) ...[
          title('🎁 ${tr('Guardados: toque para ele segurar')}'),
          for (var k = 0; k < stash.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _itemRow(stash[k], _itemName(stash[k]), info: 'stash-$k', key: ValueKey('team-stash-$k'), [
                _bwButton(tr('SEGURAR'), const Color(0xFF16A34A), () => widget.onSave(FactoryRun.equipFromStash(run, k, i)), key: ValueKey('team-equip-$k')),
              ]),
            ),
        ],
      ]),
    );
  }

  /// As opções de quem foi aberto (a página OPÇÕES): quem abre a batalha, ensinar golpe e a mecânica.
  Widget _monActions(int i) {
    final run = widget.run;
    final mon = FactoryRun.teamOf(run)[i];
    final canTeach = ((run['tms'] as Map?) ?? const {}).values.any((n) => (n as num) > 0) || ((run['tokens'] as Map?) ?? const {}).values.any((n) => (n as num) > 0);
    final gimmicks = FactoryRun.gimmicksOf(widget.data, run, mon);
    return Container(
      key: const ValueKey('team-actions'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFF0F3D44), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0B2A2F), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (i == 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF5CC07A), borderRadius: BorderRadius.circular(8)),
              child: Text(tr('Abre a batalha'), style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
            )
          else
            _bwButton('⬆ ${tr('PRIMEIRO NA BATALHA')}', const Color(0xFF2563EB), () {
              widget.onSave(FactoryRun.setLead(run, i));
              _open(0);
            }, key: const ValueKey('team-lead')),
          if (canTeach) _bwButton('📀 ${tr('ENSINAR GOLPE')}', const Color(0xFF7C3AED), () => _teach(i), key: const ValueKey('team-teach')),
          if (gimmicks.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: DropdownButton<String>(
                key: const ValueKey('team-gimmick'),
                underline: const SizedBox(),
                isDense: true,
                dropdownColor: Colors.white,
                style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900),
                value: FactoryRun.gimmickOf(widget.data, run, mon).isEmpty ? 'none' : FactoryRun.gimmickOf(widget.data, run, mon),
                items: [
                  DropdownMenuItem(value: 'none', child: Text(tr('Sem mecânica'))),
                  for (final g in gimmicks) DropdownMenuItem(value: g, child: Text(_gimmickLabel[g]!)),
                ],
                onChanged: (g) => widget.onSave(FactoryRun.setGimmick(run, i, g ?? 'none')),
              ),
            ),
        ]),
      ]),
    );
  }

  /// O time como a tela de trocar da batalha (Black & White): toque num Pokémon para ver os dados dele e equipar itens.
  Widget _bwTeam(BuildContext context) {
    final run = widget.run;
    final team = FactoryRun.teamOf(run);
    final sel = _sel;
    if (sel != null && sel < team.length) {
      return FutureBuilder<SummaryData?>(
        future: _selData,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) {
            return Container(
              color: Hud.tint(const Color(0xFF1F6F78)),
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: snap.connectionState == ConnectionState.done
                  ? _bwButton('✕ ${tr('Voltar')}', const Color(0xFFDC2626), () => _open(null))
                  : const CircularProgressIndicator(color: Colors.white),
            );
          }
          return _TeamPages(d, key: ValueKey('team-summary-$sel'), onBack: () => _open(null), items: _monItems(sel), actions: _monActions(sel));
        },
      );
    }
    // Os 6 no lugar do campo, como a tela de trocar da batalha (3 linhas de 2, sem rolar).
    // O limite de nível de agora (o próximo chefe e os desvios): quem chegou nele para de ganhar XP até vencer o chefe.
    final cap = FactoryRun.levelCapOf(widget.data, run);
    return BwParty(
      testKey: 'factory-team',
      fill: true,
      title: cap == null ? null : '📈 ${tr('Nível máximo agora: {0}. Sobe quando você vence o próximo chefe.').replaceAll('{0}', '$cap')}',
      // Os ovos ocupam vagas do time (e chocam com as vitórias).
      eggs: [for (final e in FactoryRun.eggsOf(run)) (e['left'] as num).toInt()],
      mystery: {for (final (k, e) in FactoryRun.eggsOf(run).indexed) if (e['mystery'] == true) k},
      team: [
        for (final m in team)
          PartySlot(
            id: (m['id'] as num).toInt(),
            shiny: m['shiny'] == true,
            name: '${m['nick'] ?? ''}'.isNotEmpty ? '${m['nick']}' : battleMonName({'name': widget.names[(m['id'] as num).toInt()] ?? ''}),
            level: (m['level'] as num).toInt(),
            hp: FactoryRun.hpOf(m).toDouble(),
            max: cap != null && (m['level'] as num).toInt() >= cap,
            // A amizade (os corações) e, de quem veio de uma troca, o treinador de antes (OT).
            hearts: FactoryRun.heartsOf(m),
            // O item que ele segura (★ o principal; +N os extras).
            sub: m['item'] == null
                ? (m['ot'] != null ? '🔁 OT ${m['ot']}' : null)
                : '★ ${_itemName('${m['item']}')}${((m['extras'] as List?) ?? const []).isNotEmpty ? ' +${(m['extras'] as List).length}' : ''}',
          ),
      ],
      onPick: _open,
    );
  }

  @override
  Widget build(BuildContext context) => widget.only == 'bag' ? _bwBag(context) : _bwTeam(context);
}

/// Os dados de um Pokémon do time em páginas de tamanho fixo, como o resumo dos jogos: DADOS, GOLPES, ITENS e OPÇÕES, trocando
/// arrastando para o lado (ou pelas setas e abas). Igual ao site.
class _TeamPages extends StatefulWidget {
  const _TeamPages(this.data, {super.key, required this.items, required this.actions, required this.onBack});
  final SummaryData data;
  final Widget items, actions;
  final VoidCallback onBack;

  @override
  State<_TeamPages> createState() => _TeamPagesState();
}

class _TeamPagesState extends State<_TeamPages> {
  final _pages = PageController();
  int _page = 0;
  static const _ink = Color(0xFF0F172A);
  static const _tabs = ['DADOS', 'GOLPES', 'ITENS', 'OPÇÕES'];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) => _pages.animateToPage(page.clamp(0, _tabs.length - 1), duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  Widget _info(SummaryData d) {
    final hp = d.maxHp > 0 ? (d.hp / d.maxHp).clamp(0.0, 1.0) : 0.0;
    Widget row(String label, String value) => Row(children: [
          SizedBox(width: 74, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
          // Habilidade e item: nomes do jogo (não traduz).
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, maxLines: 1, style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.w900)))),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: const Color(0xFFBDE7F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
          child: PokemonSprite(d.id, shiny: d.shiny, fill: 0.85),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 4, runSpacing: 2, children: [for (final t in d.types) TypeChip(t)]),
            const SizedBox(height: 3),
            Row(children: [
              const Text('HP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(3)),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                      widthFactor: hp,
                      child: Container(
                          decoration: BoxDecoration(
                              color: hp > 0.5 ? const Color(0xFF34D399) : hp > 0.2 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(3)))),
                ),
              ),
              const SizedBox(width: 4),
              Text('${d.hp}/${d.maxHp}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ]),
            row(tr('Habilidade'), d.ability.isEmpty ? '—' : d.ability),
            row(tr('Item'), d.item.isEmpty ? '—' : d.item),
          ]),
        ),
      ]),
      const SizedBox(height: 6),
      // Os atributos em duas colunas (cabe sem rolar).
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
          child: Column(children: [
            for (var r = 0; r < summaryStats.length; r += 2)
              Expanded(
                child: Row(children: [
                  for (var k = r; k < r + 2; k++) ...[
                    if (k > r) const SizedBox(width: 12),
                    Expanded(
                      child: k >= summaryStats.length
                          ? const SizedBox()
                          : Row(children: [
                              Expanded(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(summaryStats[k].$2, maxLines: 1, style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w800)))),
                              Text('${d.stats[summaryStats[k].$1] ?? '—'}', style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w900)),
                            ]),
                    ),
                  ],
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }

  // Os 4 golpes dividem a altura da página (sem rolar, em qualquer celular).
  Widget _moves(SummaryData d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var k = 0; k < 4; k++)
          Expanded(
            child: k >= d.moves.length ? const SizedBox() : Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Builder(builder: (context) {
              final mv = d.moves[k];
              return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
              child: Row(children: [
                if (mv.type.isNotEmpty) TypeChip(mv.type),
                const SizedBox(width: 6),
                // Nome do golpe como no jogo (não traduz).
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(mv.name, maxLines: 1, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900)))),
                Text('PP ${mv.pp}/${mv.maxPp}', style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            );
            }),
          )),
      ]);

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    Widget arrow(String text, int to, String key) => InkWell(
          key: ValueKey(key),
          onTap: to < 0 || to >= _tabs.length ? null : () => _go(to),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(text, style: TextStyle(color: to < 0 || to >= _tabs.length ? Colors.white24 : Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        );
    return Container(
      key: const ValueKey('team-pages'),
      color: Hud.tint(const Color(0xFF1F6F78)),
      padding: const EdgeInsets.all(6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // O nome e o nível, as abas (a página de agora acesa) e voltar ao time.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF0F3D44), border: Border.all(color: const Color(0xFF0B2A2F), width: 2), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            arrow('◀', _page - 1, 'team-prev'),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(children: [
                  Text('${d.name} Lv${d.level}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(width: 8),
                  for (var k = 0; k < _tabs.length; k++)
                    GestureDetector(
                      key: ValueKey('team-tab-$k'),
                      onTap: () => _go(k),
                      child: Container(
                        margin: const EdgeInsets.only(right: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: k == _page ? const Color(0xFFF97316) : Colors.white12, borderRadius: BorderRadius.circular(6)),
                        child: Text(tr(_tabs[k]), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ]),
              ),
            ),
            arrow('▶', _page + 1, 'team-next'),
            InkWell(
              key: const ValueKey('bw-summary-back'),
              onTap: widget.onBack,
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text('✕', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 16, fontWeight: FontWeight.w900))),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        // As páginas: arrastar para o lado troca.
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              _info(d),
              _moves(d),
              // Muitos itens guardados: só esta lista rola.
              SingleChildScrollView(child: widget.items),
              widget.actions,
            ],
          ),
        ),
      ]),
    );
  }
}

/// O começo: corrida em andamento (continuar no mapa), ou escolher o inicial; e comprar Pokémon (e shiny) com as moedas.
/// As missões de hoje, com o progresso e as moedas de cada uma.
Widget _dailyMissions(BuildContext context, Json factory) {
  final c = SiteColors.of(context);
  final daily = FactoryDaily.stateOf(factory);
  return Container(
    key: const ValueKey('factory-daily'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('📅 ${tr('Missões de hoje')}', style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
      for (final m in FactoryDaily.of()) ...[
        const SizedBox(height: 8),
        Builder(builder: (context) {
          final value = min(m.count, ((daily['p'] as Map)[m.kind] as num?)?.toInt() ?? 0);
          final done = (daily['done'] as List).contains(m.kind);
          return Column(key: ValueKey('daily-${m.kind}'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text('${done ? '✅' : '▫️'} ${tr(m.label).replaceAll('{0}', '${m.count}')}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: done ? FontWeight.normal : FontWeight.w600,
                        color: done ? c.muted : c.text,
                        decoration: done ? TextDecoration.lineThrough : null)),
              ),
              Text('$value/${m.count} · 🪙${m.coins}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.text)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / m.count,
                minHeight: 6,
                backgroundColor: c.line,
                color: done ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
              ),
            ),
          ]);
        }),
      ],
    ]),
  );
}

/// Os modos da corrida e o texto de cada um. Igual ao site.
const runModeTexts = [
  ('mono', '🎨 Monotipo: só dá para capturar Pokémon com um tipo do inicial'),
];
const _modeIcons = {'nuzlocke': '🕯️', 'mono': '🎨', 'noItems': '🎒', 'regionalAll': '🌍'};

/// Uma corrida do histórico: o dia, o andar, as moedas, os itens da árvore, os modos e o time (o MVP com ⭐). Igual ao site.
Widget _historyRow(BuildContext context, Map h) {
  final c = SiteColors.of(context);
  final sum = (h['summary'] as Map?) ?? const {};
  final mvp = sum['mvp'] as List?;
  final pieces = piecesLine(FactoryRun.piecesOf(h));
  return Container(
    key: const ValueKey('history-row'),
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tr('Andar {0} · +{1} moedas').replaceAll('{0}', '${h['floor']}').replaceAll('{1}', '${h['coins']}')}${pieces.isEmpty ? '' : ' · $pieces'}',
              style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 13)),
          Text('${[for (final m in (h['modes'] as List?) ?? const []) _modeIcons['$m'] ?? ''].join()} ${'${h['date']}'.split('-').reversed.join('/')}',
              style: TextStyle(color: c.muted, fontSize: 11)),
        ]),
      ),
      for (final m in ((sum['team'] as List?) ?? const []).take(6))
        Stack(children: [
          SizedBox.square(dimension: 28, child: PokemonSprite(((m as List)[0] as num).toInt(), shiny: m[2] == 1, fill: 0.95)),
          if (mvp != null && mvp[0] == m[0] && mvp[1] == m[1]) const Positioned(right: 0, top: 0, child: Text('⭐', style: TextStyle(fontSize: 9))),
        ]),
    ]),
  );
}

/// A troca dos itens da árvore: 3 de um por 1 de outro (quando falta um tipo de chefe). Igual ao site.
class _PiecesTrade extends StatefulWidget {
  final Json factory;
  final void Function(Json) onSave;
  const _PiecesTrade({required this.factory, required this.onSave});

  @override
  State<_PiecesTrade> createState() => _PiecesTradeState();
}

class _PiecesTradeState extends State<_PiecesTrade> {
  String _from = FactoryRun.pieceItems.first, _to = FactoryRun.pieceItems.last;

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final next = FactoryRun.tradePieces(widget.factory, _from, _to);
    DropdownButton<String> pick(String value, void Function(String) onPick, Key key) => DropdownButton<String>(
          key: key,
          value: value,
          isDense: true,
          underline: const SizedBox(),
          items: [for (final i in FactoryRun.pieceItems) DropdownMenuItem(value: i, child: Text('${pieceInfo[i]!.$1} ${pieceInfo[i]!.$2}', style: const TextStyle(fontSize: 12)))],
          onChanged: (v) => v == null ? null : setState(() => onPick(v)),
        );
    return Container(
      key: const ValueKey('pieces-trade'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🔁 ${tr('Trocar itens da árvore')} · ${piecesLine(FactoryRun.piecesOf(widget.factory), all: true)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 13)),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
          Text('${FactoryRun.pieceTrade}×', style: TextStyle(color: c.text, fontSize: 12)),
          pick(_from, (v) => _from = v, const ValueKey('trade-from')),
          Text('→ 1×', style: TextStyle(color: c.text, fontSize: 12)),
          pick(_to, (v) => _to = v, const ValueKey('trade-to')),
          TextButton(key: const ValueKey('trade-pieces'), onPressed: next == null ? null : () => widget.onSave(next), child: Text(tr('Trocar'))),
        ]),
      ]),
    );
  }
}

/// O que a árvore já dá (a soma de tudo comprado), como começa a próxima corrida. Igual ao site.
class _Bonuses extends StatelessWidget {
  final Json factory;
  final FactoryData data;
  const _Bonuses({required this.factory, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final lines = bonusLines(factory, data);
    return Container(
      key: const ValueKey('tree-bonuses'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📊 ${tr('Seus bônus')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 13)),
        if (lines.isEmpty) Text(tr('Nada ainda: compre melhorias na árvore.'), style: TextStyle(color: c.muted, fontSize: 12)),
        for (final l in lines) Text(l, style: TextStyle(color: c.text, fontSize: 12)),
      ]),
    );
  }
}

/// Os bônus da árvore, em texto: como a próxima corrida começaria. Igual ao site.
List<String> bonusLines(Json factory, FactoryData data) {
  final starters = FactoryRun.startersOf(factory, data);
  final empty = starters.isEmpty ? null : FactoryRun.startRun(FactoryRun.empty(), data, starters.first, 1);
  final run = starters.isEmpty ? null : FactoryRun.startRun({...factory, 'owned': FactoryRun.ownedOf(factory)}, data, starters.first, 1);
  if (run == null || empty == null) return const [];
  String pct(num v) => '+${(v * 100).round()}%';
  final boost = Map<String, dynamic>.from(run['teamBoost'] as Map);
  final mult = Map<String, dynamic>.from(run['mult'] as Map);
  const names = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spa': 'SpA', 'spd': 'SpD', 'spe': 'Spe'};
  final bag = Map<String, dynamic>.from(run['bag'] as Map), bag0 = Map<String, dynamic>.from(empty['bag'] as Map);
  final extra = [for (final e in bag.entries) if (((e.value as num) - ((bag0[e.key] as num?) ?? 0)) > 0) '+${(e.value as num) - ((bag0[e.key] as num?) ?? 0)} ${_itemName(e.key)}'];
  final level = (FactoryRun.teamOf(run).first['level'] as num) - (FactoryRun.teamOf(empty).first['level'] as num);
  return [
    if (boost.values.any((v) => (v as num) > 0)) '⚔️ ${[for (final e in boost.entries) if ((e.value as num) > 0) '${names[e.key]} ${pct(e.value as num)}'].join(' · ')}',
    if ((mult['exp'] as num) > 1 || (mult['money'] as num) > 1)
      '📈 ${tr('XP')} ×${mult['exp']} · 💰 ${tr('dinheiro')} ×${mult['money']}${(mult['shop'] as num) < 1 ? ' · 🏷️ ${tr('loja')} -${((1 - (mult['shop'] as num)) * 100).round()}%' : ''}',
    if (level > 0) '🎓 ${tr('Inicial')} +$level ${tr('níveis')}',
    if (_int(run['money']) > 0) '💵 ${tr('Começa com {0} de dinheiro').replaceAll('{0}', '${run['money']}')}',
    if (extra.isNotEmpty) '🎒 ${extra.join(' · ')}',
    if (((run['stash'] as List?) ?? const []).isNotEmpty) '🧺 ${tr('{0} itens guardados para segurar').replaceAll('{0}', '${(run['stash'] as List).length}')}',
    if (_int(run['shinyRate'] ?? 1) > 1) '✨ ${tr('Shiny {0}× mais comum').replaceAll('{0}', '${run['shinyRate']}')}',
    if (_int(run['winHeal'] ?? 0) > 0) '💗 ${tr('Cura {0}% depois de cada vitória').replaceAll('{0}', '${run['winHeal']}')}',
    if (_int(run['catchBonus'] ?? 0) > 0) '🎯 ${tr('Captura {0}% mais fácil').replaceAll('{0}', '${run['catchBonus']}')}',
  ];
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// A galeria das melhores corridas: o andar, o time e o dia.
Widget _bestRuns(BuildContext context, List gallery) {
  final c = SiteColors.of(context);
  return Container(
    key: const ValueKey('factory-gallery'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('🖼️ ${tr('Suas melhores corridas')}', style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
      for (final (k, g) in gallery.indexed)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            SizedBox(width: 26, child: Text(k < 3 ? const ['🥇', '🥈', '🥉'][k] : '${k + 1}.', textAlign: TextAlign.center)),
            const SizedBox(width: 4),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Andar {0}').replaceAll('{0}', '${g['floor']}'), style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 13)),
              Text('${(g['games'] as num? ?? 0) > 0 ? '🎮${g['games']} ' : ''}${g['nuzlocke'] == true ? '🕯️ ' : ''}${g['weekly'] == true ? '🏆 ' : ''}${'${g['date']}'.split('-').reversed.join('/')}',
                  style: TextStyle(color: c.muted, fontSize: 11)),
            ]),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(children: [
                for (final m in (g['team'] as List))
                  Tooltip(
                    message: 'Lv. ${(m as List)[1]}',
                    child: SizedBox.square(dimension: 34, child: PokemonSprite((m[0] as num).toInt(), shiny: m[2] == 1, fill: 0.95)),
                  ),
              ]),
            ),
          ]),
        ),
    ]),
  );
}

/// O PC: os Pokémon das corridas (o time do fim e quem saiu do time). Tocando num, abre os dados e dá para pôr num
/// dos seus times (para as outras batalhas) ou soltar. Igual ao site.
class _BoxPanel extends StatelessWidget {
  final Json factory;
  final String Function(int) name;
  final void Function(Json) onSave;
  const _BoxPanel({required this.factory, required this.name, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final box = [for (final b in (factory['box'] as List?) ?? const []) Map<String, dynamic>.from(b as Map)];
    return _panel(context, '💻 ${tr('PC')} · ${box.length}/${FactoryRun.boxSize}', key: const ValueKey('factory-box'), [
      Text(tr('Quando a corrida acaba, o time vai para o PC (e quem saiu do time no caminho também). Toque num Pokémon para pôr num dos seus times.'),
          style: TextStyle(color: c.muted, fontSize: 12)),
      const SizedBox(height: 8),
      if (box.isEmpty) Text(tr('O PC está vazio: termine uma corrida.'), style: TextStyle(color: c.muted, fontSize: 12)),
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (final (i, m) in box.indexed)
          InkWell(
            key: ValueKey('box-$i'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => _open(context, i, m),
            child: Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                SizedBox.square(dimension: 40, child: PokemonSprite((m['id'] as num).toInt(), shiny: m['shiny'] == true, fill: 0.95)),
                Text('Nv. ${m['level']}', style: TextStyle(fontSize: 10, color: c.muted, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
      ]),
    ]);
  }

  Future<void> _open(BuildContext context, int index, Map<String, dynamic> m) async {
    final id = (m['id'] as num).toInt();
    final own = [for (final x in (m['moves'] as List?) ?? const []) '$x'];
    final moves = own.isNotEmpty ? own : await _movesFor(id, (m['level'] as num).toInt());
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      // Muitos times: a janela rola (no celular pequeno os botões não cabem).
      isScrollControlled: true,
      builder: (sheet) {
        final c = SiteColors.of(sheet);
        final teams = UserData.instance.teams;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
            key: const ValueKey('box-detail'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SizedBox.square(dimension: 72, child: PokemonSprite(id, shiny: m['shiny'] == true, fill: 0.95)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['shiny'] == true ? '✨ ' : ''}${name(id)}${switch (FactoryData.loaded == null ? null : FactoryRun.genderOf(FactoryData.loaded!, m)) { 'F' => ' ♀', 'M' => ' ♂', _ => '' }}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: c.text, fontSize: 16)),
                    Text('Nv. ${m['level']} · ${m['nature']}${m['item'] != null ? ' · ${prettySlug('${m['item']}')}' : ''}', style: TextStyle(color: c.muted, fontSize: 12)),
                    Text(moves.map(prettySlug).join(' · '), style: TextStyle(color: c.text, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Text(tr('Pôr num time'), style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in teams)
                  Builder(builder: (_) {
                    final free = ((t['pokemon'] as List?) ?? const []).where((x) => x == null).length + (6 - ((t['pokemon'] as List?) ?? const []).length);
                    return OutlinedButton(
                      key: ValueKey('box-team-${t['id']}'),
                      onPressed: free <= 0
                          ? null
                          : () {
                              _toTeam(t['id'] as String?, id, FactoryRun.boxToSet(m, moves));
                              Navigator.pop(sheet);
                            },
                      child: Text('${t['name']} (${6 - free}/6)'),
                    );
                  }),
                FilledButton(
                  key: const ValueKey('box-new-team'),
                  onPressed: () {
                    _toTeam(null, id, FactoryRun.boxToSet(m, moves));
                    Navigator.pop(sheet);
                  },
                  child: Text('+ ${tr('Novo time')}'),
                ),
              ]),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('box-release'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                onPressed: () {
                  onSave(FactoryRun.releaseFromBox(factory, index));
                  Navigator.pop(sheet);
                },
                child: Text(tr('Soltar')),
              ),
            ]),
          ),
          ),
        );
      },
    );
  }

  /// Põe no primeiro lugar vazio do time (ou num time novo "Time do PC").
  static void _toTeam(String? teamId, int id, Json set) {
    final teams = [for (final t in UserData.instance.teams) Map<String, dynamic>.from(t)];
    final i = teams.indexWhere((t) => t['id'] == teamId);
    if (i < 0) {
      teams.add({
        'id': const Uuid().v4(), 'name': tr('Time do PC'), 'color': null,
        'pokemon': [id, null, null, null, null, null], 'sets': [set, null, null, null, null, null],
      });
    } else {
      final ids = [for (var k = 0; k < 6; k++) k < ((teams[i]['pokemon'] as List?) ?? const []).length ? (teams[i]['pokemon'] as List)[k] : null];
      final sets = [for (var k = 0; k < 6; k++) k < ((teams[i]['sets'] as List?) ?? const []).length ? (teams[i]['sets'] as List)[k] : null];
      final slot = ids.indexOf(null);
      if (slot < 0) return;
      ids[slot] = id;
      sets[slot] = set;
      teams[i] = {...teams[i], 'pokemon': ids, 'sets': sets};
    }
    UserData.instance.update({'teams': teams});
  }
}

/// A caça shiny: o Pokémon escolhido, quantas vezes já apareceu e quantas vezes mais comum está o shiny dele.
/// Igual ao site.
class _HuntCard extends StatelessWidget {
  final Json factory;
  final FactoryData data;
  final Map<int, String> names;
  final String Function(int) name;
  final void Function(Json) onSave;
  const _HuntCard({required this.factory, required this.data, required this.names, required this.name, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final hunt = factory['hunt'] as Map?;
    final id = (hunt?['id'] as num?)?.toInt();
    final count = ((hunt?['count'] as num?) ?? 0).toInt();
    final mult = FactoryRun.huntMultOf(count);
    final toNext = mult >= FactoryRun.huntMax ? null : FactoryRun.huntStep - count % FactoryRun.huntStep;
    return _panel(context, '🎯 ${tr('Caça shiny')}', key: const ValueKey('factory-hunt'), [
      Text(tr('Escolha um Pokémon: a cada 10 vezes que ele (ou a linha dele) aparecer nas corridas, o shiny dele fica mais comum, até 8 vezes. Achou o shiny, a contagem recomeça.'),
          style: TextStyle(color: c.muted, fontSize: 12)),
      const SizedBox(height: 8),
      if (id != null)
        Row(children: [
          SizedBox.square(dimension: 56, child: PokemonSprite(id, shiny: true, fill: 0.95)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name(id), style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
              Text('${tr('Encontros: {0}').replaceAll('{0}', '$count')} · ✨ $mult× ${tr('mais comum')}',
                  key: const ValueKey('hunt-count'), style: TextStyle(color: c.text, fontSize: 12)),
              Text(
                  [
                    if (toNext != null) tr('Mais {0} para subir').replaceAll('{0}', '$toNext'),
                    if (((hunt?['found'] as num?) ?? 0) > 0) tr('Shiny achados: {0}').replaceAll('{0}', '${hunt!['found']}'),
                  ].join(' · '),
                  style: TextStyle(color: c.muted, fontSize: 11)),
            ]),
          ),
        ]),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        OutlinedButton(key: const ValueKey('hunt-pick'), onPressed: () => _pick(context), child: Text(id == null ? tr('Escolher Pokémon') : tr('Trocar'))),
        if (id != null)
          TextButton(key: const ValueKey('hunt-stop'), onPressed: () => onSave(FactoryRun.setHunt(factory, data, null)), child: Text(tr('Parar'))),
      ]),
    ]);
  }

  Future<void> _pick(BuildContext context) async {
    var query = '';
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setState) {
        final q = query.trim().toLowerCase();
        // Só as formas básicas (a caça conta a linha inteira).
        final ids = [
          for (final e in names.entries)
            if (data.species.containsKey(e.key) && FactoryRun.huntBase(data, e.key) == e.key && (q.isEmpty || e.value.contains(q))) e.key
        ]..sort();
        return SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.7,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(sheet).bottom),
            child: Column(children: [
              SiteSearchField(hint: 'Buscar Pokémon', onChanged: (t) => setState(() => query = t)),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 72),
                  itemCount: ids.length,
                  itemBuilder: (_, i) => InkWell(
                    key: ValueKey('hunt-option-${ids[i]}'),
                    onTap: () => Navigator.pop(sheet, ids[i]),
                    child: PokemonSprite(ids[i], fill: 0.9),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
    if (picked != null) onSave(FactoryRun.setHunt(factory, data, picked));
  }
}

/// Troca de página arrastando para o lado (ou tocando nas setas): usado no modo da corrida e nas abas do Pokelike.
class _Swipe extends StatelessWidget {
  final int index, count;
  final ValueChanged<int> onChanged;
  final Widget child;
  const _Swipe({required this.index, required this.count, required this.onChanged, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 150) return;
          onChanged(((index + (v < 0 ? 1 : -1)) % count + count) % count);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(anim), child: child),
          ),
          child: KeyedSubtree(key: ValueKey(index), child: child),
        ),
      );
}

/// As bolinhas embaixo: qual página está aberta.
Widget _dots(BuildContext context, int index, int count) {
  final c = SiteColors.of(context);
  return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    for (var i = 0; i < count; i++)
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: i == index ? 16 : 6,
        height: 6,
        decoration: BoxDecoration(color: i == index ? c.text : c.muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3)),
      ),
  ]);
}

/// Os modos da corrida (um por vez): Normal, Nuzlocke e os outros. Arrasta para o lado para trocar.
const _runModes = [
  ('normal', '🎲 Normal: as regras de sempre'),
  ('nuzlocke', 'Modo Nuzlocke: quem desmaia vai embora e só um capturado por área (rota, cidade e cada lugar)'),
  ...runModeTexts,
];

class _ModePicker extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;
  const _ModePicker({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final i = max(0, _runModes.indexWhere((m) => m.$1 == mode));
    final text = '${_runModes[i].$1 == 'nuzlocke' ? '🕯️ ' : ''}${tr(_runModes[i].$2)}';
    final cut = text.indexOf(':');
    final (title, body) = cut < 0 ? (text, '') : (text.substring(0, cut).trim(), text.substring(cut + 1).trim());
    void go(int to) => onChanged(_runModes[(to % _runModes.length + _runModes.length) % _runModes.length].$1);
    return Container(
      key: const ValueKey('factory-mode'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(tr('Modo da corrida'), style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.bold)),
        Row(children: [
          IconButton(key: const ValueKey('factory-mode-prev'), visualDensity: VisualDensity.compact, onPressed: () => go(i - 1), icon: Icon(Icons.chevron_left, color: c.text)),
          Expanded(
            child: _Swipe(
              index: i,
              count: _runModes.length,
              onChanged: go,
              child: Column(key: ValueKey('factory-mode-${_runModes[i].$1}'), children: [
                Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: c.text, fontSize: 15)),
                const SizedBox(height: 2),
                Text(body, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
              ]),
            ),
          ),
          IconButton(key: const ValueKey('factory-mode-next'), visualDensity: VisualDensity.compact, onPressed: () => go(i + 1), icon: Icon(Icons.chevron_right, color: c.text)),
        ]),
        _dots(context, i, _runModes.length),
      ]),
    );
  }
}

/// As abas do Pokelike: os botões em cima e o conteúdo, que também troca arrastando para o lado.
class _HubTabs extends StatelessWidget {
  final List<(String, String, WidgetBuilder)> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  const _HubTabs({required this.tabs, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final i = index.clamp(0, tabs.length - 1);
    return Column(key: const ValueKey('factory-tabs'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (k, t) in tabs.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('factory-tab-${t.$1}'),
                showCheckmark: false,
                selected: k == i,
                onSelected: (_) => onChanged(k),
                label: Text('${t.$1} ${tr(t.$2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.text)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      _dots(context, i, tabs.length),
      const SizedBox(height: 8),
      _Swipe(
        index: i,
        count: tabs.length,
        onChanged: onChanged,
        child: Builder(builder: tabs[i].$3),
      ),
    ]);
  }
}

/// Um painel de aba: o título e o conteúdo num cartão.
Widget _panel(BuildContext context, String title, List<Widget> children, {Key? key}) {
  final c = SiteColors.of(context);
  return Container(
    key: key,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
      const SizedBox(height: 4),
      ...children,
    ]),
  );
}

class FactoryHub extends StatefulWidget {
  final VoidCallback onContinue;
  final bool busy;
  const FactoryHub({super.key, required this.onContinue, this.busy = false});

  @override
  State<FactoryHub> createState() => _FactoryHubState();
}

class _FactoryHubState extends State<FactoryHub> {
  /// A janela com as regras do Nuzlocke (liga e desliga cada uma).
  Future<void> _pickNuzRules(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: Text('🕯️ ${tr('Regras do Nuzlocke')}'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final (rule, icon, text) in FactoryRun.nuzlockeRules)
                  CheckboxListTile(
                    key: ValueKey('factory-nuzlocke-rule-$rule'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _nuzRules.contains(rule),
                    title: Text('$icon ${tr(text)}', style: const TextStyle(fontSize: 13)),
                    onChanged: (on) {
                      setState(() => _nuzRules = on == true ? {..._nuzRules, rule} : ({..._nuzRules}..remove(rule)));
                      setDialog(() {});
                    },
                  ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('OK')))],
          ),
        ),
      );

  FactoryData? _data = FactoryData.loaded;
  ({int id, bool shiny})? _pick;

  /// O modo da corrida (um por vez, arrastando para o lado): normal, nuzlocke, monotipo, sem itens, formas regionais.
  String _mode = 'normal';

  /// As regras do Nuzlocke que você escolhe (o botão aparece com o modo Nuzlocke).
  Set<String> _nuzRules = {...FactoryRun.nuzlockeDefault};
  // A aba aberta embaixo (missões, árvore, loja...).
  int _tab = 0;
  String _query = '';
  Map<int, String> _names = const {};

  @override
  void initState() {
    super.initState();
    FactoryData.load().then((d) => mounted ? setState(() => _data = d) : null);
    LocalDatabase.instance.allPokemonRows().then((rows) {
      if (mounted) setState(() => _names = {for (final r in rows) r['id'] as int: '${r['name']}'});
    });
  }

  void _save(Json factory) => setState(() => saveFactory(factory));
  String _name(int id) => battleMonName({'name': _names[id] ?? ''});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    var factory = currentFactory();
    // Contas antigas que compraram uma forma evoluída: ficam com a primeira forma dela.
    final fixed = FactoryRun.normalizeOwned(factory, data);
    if (!identical(fixed, factory)) {
      factory = fixed;
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _save(fixed) : null);
    }
    final run = factory['run'] == null ? null : Map<String, dynamic>.from(factory['run'] as Map);
    final owned = [for (final x in factory['owned'] as List) (x as num).toInt()];
    final shinies = FactoryRun.shiniesOf(factory);
    final q = _query.trim().toLowerCase();
    final shopList = ([
      for (final e in data.species.entries)
        // Só a primeira forma está à venda (a evolução vem jogando).
        if (FactoryRun.forSale(data, e.key) && !owned.contains(e.key) && (q.isEmpty || (_names[e.key] ?? '').contains(q)))
          (id: e.key, price: FactoryRun.pokemonPrice((e.value[1] as num).toInt()))
    ]..sort((a, b) => a.price != b.price ? a.price.compareTo(b.price) : a.id.compareTo(b.id)))
        .take(24)
        .toList();
    final last = factory['last'] as Map?;
    final coins = (factory['coins'] as num).toInt();
    return Column(
      key: const ValueKey('factory-hub'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🎲 Pokelike', style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
            Text(
              'Um roguelike sem fim pela história de cada região: escolha um inicial no nível 5 e viaje de cidade em cidade, como nos jogos. Cada rota tem 10 andares e um chefe no último; depois vem a cidade, com 10 andares, o Poké Mart, o Centro Pokémon, a Creche e o líder no fim. Nas bifurcações você escolhe o caminho ou entra num lugar (cavernas, florestas, o mar, esgotos, museus...): 10 andares, um chefe e você volta para o andar em que entrou. Capture jogando a bola na batalha; nos lugares sem treinadores, até o chefe dá para capturar. O time não é curado entre os andares. Sem limite de nível, IVs, EVs ou itens; shiny é 1 em 4096. Perdeu: os andares viram moedas para comprar Pokémon e melhorias.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            // Os Star Pieces (caem dos chefes) destravam a árvore. Igual ao site.
            Text('${tr('Recorde: andar {0}').replaceAll('{0}', '${factory['best']}')}${(factory['bestGames'] as num? ?? 0) > 0 ? ' · 🎮 ${tr('{0} jogos zerados numa corrida').replaceAll('{0}', '${factory['bestGames']}')}' : ''} · 🪙 $coins ${tr('moedas')} · ${piecesLine(FactoryRun.piecesOf(factory), all: true)}',
                key: const ValueKey('factory-pieces'), style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
            if (((factory['refunded'] as num?) ?? 0) > 0)
              Container(
                key: const ValueKey('factory-refunded'),
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x26F59E0B), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          '🪙 ${tr('Agora só a primeira forma fica à venda: devolvemos {0} moedas dos evoluídos que você tinha comprado.').replaceAll('{0}', '${factory['refunded']}')}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 12))),
                  TextButton(onPressed: () => _save({...factory, 'refunded': 0}), child: Text(tr('OK'))),
                ]),
              ),
            if (last != null && run == null)
              Text(tr('Última corrida: andar {0}, +{1} moedas.').replaceAll('{0}', '${last['floor']}').replaceAll('{1}', '${last['coins']}'),
                  style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        if (run != null) ...[
          Text(tr('Corrida em andamento: andar {0}').replaceAll('{0}', '${run['floor']}'), style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
          const SizedBox(height: 4),
          _runStatus(context, run),
          _story(context, data, run),
          _nextBoss(context, data, run),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in FactoryRun.teamOf(run)) _mon(context, m, name: _name((m['id'] as num).toInt())),
          ]),
          if ((run['cards'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${tr('Cartas')}: ${[for (final id in run['cards'] as List) tr(FactoryRun.cards['$id']!.label)].join(' · ')}',
                  style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          if (((run['relics'] as List?) ?? const []).isNotEmpty)
            Padding(
              key: const ValueKey('factory-relics'),
              padding: const EdgeInsets.only(top: 4),
              child: Text('🏺 ${tr('Relíquias')}: ${[for (final id in run['relics'] as List) '${FactoryRun.relics['$id']?.icon ?? ''} ${tr(FactoryRun.cardLabel('$id'))}'].join(' · ')}',
                  style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            PillButton(key: const ValueKey('factory-continue-run'), label: '🗺️ ${tr('Continuar a corrida')}', onPressed: widget.busy ? null : widget.onContinue),
            PillButton(label: tr('Desistir (recebe as moedas)'), color: const Color(0xFF64748B), onPressed: () => _save(FactoryRun.endRun(factory, run))),
          ]),
        ] else ...[
          Text(FactoryRun.freePick(factory) ? tr('Escolha o seu inicial grátis (de qualquer geração). Os outros você compra com moedas.') : tr('Escolha com quem começar'),
              style: TextStyle(color: c.muted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in FactoryRun.startersOf(factory, data)) ...[
              _mon(context, {'id': id},
                  name: _name(id), selected: _pick?.id == id && _pick?.shiny == false, onTap: () => setState(() => _pick = (id: id, shiny: false)), key: ValueKey('starter-$id')),
              if (shinies.contains(id))
                _mon(context, {'id': id, 'shiny': true},
                    name: _name(id), selected: _pick?.id == id && _pick?.shiny == true, onTap: () => setState(() => _pick = (id: id, shiny: true)), key: ValueKey('starter-$id-shiny')),
            ],
          ]),
          const SizedBox(height: 4),
          _ModePicker(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
          if (_mode == 'nuzlocke') ...[
            const SizedBox(height: 6),
            Center(
              child: OutlinedButton(
                key: const ValueKey('factory-nuzlocke-rules'),
                onPressed: () => _pickNuzRules(context),
                child: Text('⚙️ ${tr('Regras do Nuzlocke')} (${_nuzRules.length}/${FactoryRun.nuzlockeRules.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          PillButton(
            key: const ValueKey('factory-start'),
            label: '🎲 ${tr('Começar a corrida')}',
            onPressed: widget.busy || _pick == null
                ? null
                : () {
                    final meta = FactoryRun.claimStarter(factory, data, _pick!.id);
                    final next = FactoryRun.startRun(meta, data, _pick!.id, Random().nextInt(1 << 31), shiny: _pick!.shiny, nuzlocke: _mode == 'nuzlocke', nuzRules: _nuzRules, modes: {if (_mode != 'normal' && _mode != 'nuzlocke') _mode});
                    if (next == null) return;
                    saveFactory({...meta, 'run': next});
                    widget.onContinue();
                  },
          ),
        ],
        const SizedBox(height: 12),
        // Tudo o mais em abas: toca no botão ou arrasta para o lado para trocar.
        _HubTabs(
          index: _tab,
          onChanged: (k) => setState(() => _tab = k),
          tabs: [
            ('📅', 'Missões', (context) => _dailyMissions(context, factory)),
            if (run == null) ('🏆', 'Semanal', (context) => _WeeklyCard(factory: factory, data: data, names: _name, onContinue: widget.onContinue)),
            (
              '⬆️',
              'Árvore',
              (context) => _panel(
                    context,
                    '⬆️ ${tr('Árvore de melhorias')}  ★ ${FactoryRun.upgrades.keys.fold(0, (n, id) => n + FactoryRun.upgradeLevel(factory, id))}/${FactoryRun.upgrades.values.fold(0, (n, u) => n + u.max)}',
                    key: const ValueKey('factory-upgrades'),
                    [
            Text(tr('Compradas com moedas, valem em todas as próximas corridas. Cada ramo começa na raiz; para avançar, a anterior, um andar recorde e Pokémon para começar.'),
                style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 6),
            // A árvore em leque: tocando num círculo, abre o que ele faz e o botão de comprar. Igual ao site.
            _SkillTree(factory: factory, onBuy: _save),
            const SizedBox(height: 8),
            _PiecesTrade(factory: factory, onSave: _save),
            const SizedBox(height: 8),
            _Bonuses(factory: factory, data: data),
                    ],
                  )
            ),
            (
              '🪙',
              'Pokémon',
              (context) => _panel(context, '🪙 ${tr('Comprar Pokémon com moedas')}', key: const ValueKey('factory-shop'), [
            Text(tr('Só a primeira forma de cada um (a evolução vem jogando). Os mais fortes custam mais. Comprado, ele aparece entre os iniciais.'),
                style: TextStyle(color: c.muted, fontSize: 12)),
            if (FactoryRun.freePick(factory))
              Text(tr('Primeiro escolha o seu inicial grátis.'), style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            SiteSearchField(hint: 'Buscar Pokémon', onChanged: (t) => setState(() => _query = t)),
            const SizedBox(height: 6),
            for (final p in shopList)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(width: 40, height: 40, child: PokemonSprite(p.id, fill: 0.9)),
                title: Text(_name(p.id), style: TextStyle(color: c.text)),
                subtitle: Text('🪙 ${p.price}', style: TextStyle(color: c.muted)),
                trailing: TextButton(
                  onPressed: coins < p.price || FactoryRun.freePick(factory)
                      ? null
                      : () {
                          final next = FactoryRun.buyPokemon(factory, data, p.id);
                          if (next != null) _save(next);
                        },
                  child: const Text('Comprar'),
                ),
              ),
                  ])
            ),
            (
              '✨',
              'Shiny',
              (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _HuntCard(factory: factory, data: data, names: _names, name: _name, onSave: _save),
                    const SizedBox(height: 12),
                    _panel(context, '✨ ${tr('Inicial shiny')}', key: const ValueKey('factory-shiny-shop'), [
            Text(
                tr('Shiny tem +25% em todos os atributos e não se compra: capture qualquer Pokémon shiny numa corrida e ele vira inicial shiny (a primeira forma dele), até lendário.'),
                style: TextStyle(color: c.muted, fontSize: 12)),
            if (shinies.isEmpty) Text(tr('Nenhum ainda.'), style: TextStyle(color: c.muted, fontSize: 12)),
            for (final id in shinies)
              ListTile(
                key: ValueKey('factory-shiny-$id'),
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(width: 40, height: 40, child: PokemonSprite(id, shiny: true, fill: 0.9)),
                title: Text('✨ ${_name(id)}', style: TextStyle(color: c.text)),
              ),
                  ]),
                  ])
            ),
            ('🎨', 'Cosméticos', (context) => _panel(context, '🎨 ${tr('Loja de cosméticos')}', [_cosmeticsTile(context, factory, (next) => next == null ? null : setState(() => saveFactory(next)))])),
            ('💻', 'PC', (context) => _BoxPanel(factory: factory, name: _name, onSave: _save)),
            (
              '📜',
              'Corridas',
              (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (((factory['gallery'] as List?) ?? const []).isNotEmpty) ...[_bestRuns(context, factory['gallery'] as List), const SizedBox(height: 12)],
                    _panel(context, '📜 ${tr('Últimas corridas')}', key: const ValueKey('factory-history'), [
                      if (((factory['history'] as List?) ?? const []).isEmpty) Text(tr('Nenhuma corrida ainda.'), style: TextStyle(color: c.muted, fontSize: 12)),
                      for (final h in (factory['history'] as List?) ?? const []) _historyRow(context, Map<String, dynamic>.from(h as Map)),
                    ]),
                    if (((factory['hall'] as List?) ?? const []).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _panel(context, '👑 ${tr('Hall da Fama')}', key: const ValueKey('factory-hall'), [
              // A foto do time campeão (no cenário do Campeão), como a tela do Hall da Fama dos jogos. Igual ao site.
              for (final h in factory['hall'] as List)
                Container(
                  key: const ValueKey('hall-photo'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFCD34D), width: 4), borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    AspectRatio(
                      aspectRatio: 3,
                      child: Stack(fit: StackFit.expand, children: [
                        const BattleBackdrop(scene: 'champion-kanto'),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            for (final m in h['team'] as List)
                              SizedBox(width: 48, height: 48, child: PokemonSprite((m['id'] as num).toInt(), shiny: m['shiny'] == true, fill: 0.95)),
                          ]),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text('👑 ${tr('Campeão no andar {0}').replaceAll('{0}', '${h['floor']}')} · ${[for (final m in h['team'] as List) 'Nv. ${m['level']}'].join(' · ')}',
                          style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ]),
                ),
            ],
          ),
        ExpansionTile(
          key: const ValueKey('factory-shiny-shop'),
          tilePadding: EdgeInsets.zero,
          title: Text('✨ ${tr('Inicial shiny')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          children: [
            Text(
                tr('Shiny tem +25% em todos os atributos e não se compra: capture qualquer Pokémon shiny numa corrida e ele vira inicial shiny (a primeira forma dele), até lendário.'),
                style: TextStyle(color: c.muted, fontSize: 12)),
            if (shinies.isEmpty) Text(tr('Nenhum ainda.'), style: TextStyle(color: c.muted, fontSize: 12)),
            for (final id in shinies)
              ListTile(
                key: ValueKey('factory-shiny-$id'),
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(width: 40, height: 40, child: PokemonSprite(id, shiny: true, fill: 0.9)),
                title: Text('✨ ${_name(id)}', style: TextStyle(color: c.text)),
              ),
                      ]),
                    ],
                  ])
            ),
          ],
        ),
      ],
    );
  }
}

/// O texto da história: o começo da região (1º chefe) e quem vem a seguir.
Widget _story(BuildContext context, FactoryData data, Json run) {
  if (data.bosses.isEmpty) return const SizedBox.shrink();
  final c = SiteColors.of(context);
  final boss = FactoryRun.bossOf(data, run);
  final region = '${boss['region']}';
  final intro = run['boss']['step'] == 0 ? FactoryRun.storyLine(data, region, 'intro') : '';
  return Container(
    key: const ValueKey('factory-story'),
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: const Color(0x1A6366F1), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('📖 $region · ${boss['game']}', style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
      if (intro.isNotEmpty) Text(intro, style: TextStyle(color: c.text, fontSize: 13)),
      Text(FactoryRun.storyLine(data, region, '${boss['kind']}', '${boss['name']}'), style: TextStyle(color: c.muted, fontSize: 13)),
    ]),
  );
}

/// O próximo chefe de cidade (o destino da rota).
Widget _nextBoss(BuildContext context, FactoryData data, Json run) {
  if (data.bosses.isEmpty) return const SizedBox.shrink();
  final boss = FactoryRun.targetOf(data, run);
  final game = data.bosses[(run['boss']['region'] as num).toInt()];
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text('👑 ${tr('Chefe em {0}:').replaceAll('{0}', '${boss['city'] ?? ''}')} ${boss['name']} · ${_bossKind(boss['kind'])} · ${game['region']} (${game['game']})',
        style: TextStyle(color: SiteColors.of(context).muted, fontSize: 12)),
  );
}

/// Os biomas das rotas: nome, símbolo e a cor do caminho no mapa. Igual ao site.
const _biomeInfo = <String, (String, String, Color)>{
  'grass': ('Campo', '🌾', Color(0xFF65A30D)),
  'forest': ('Floresta', '🌲', Color(0xFF15803D)),
  'water': ('Mar', '🌊', Color(0xFF0284C7)),
  'cave': ('Caverna', '🪨', Color(0xFF57534E)),
  'mountain': ('Montanha', '⛰️', Color(0xFF78716C)),
  'volcano': ('Vulcão', '🌋', Color(0xFFDC2626)),
  'city': ('Cidade', '🏙️', Color(0xFF6366F1)),
  'snow': ('Neve', '❄️', Color(0xFF38BDF8)),
  'tower': ('Torre', '👻', Color(0xFF7C3AED)),
  'sky': ('Céu', '☁️', Color(0xFF0EA5E9)),
  'beach': ('Praia', '🏖️', Color(0xFFD97706)),
  'underwater': ('Fundo do mar', '🐠', Color(0xFF1E40AF)),
  'swamp': ('Pântano', '🪵', Color(0xFF4D7C0F)),
  'sewer': ('Esgoto', '🚰', Color(0xFF475569)),
  'icecave': ('Caverna de gelo', '🧊', Color(0xFF0891B2)),
  'lavacave': ('Caverna de lava', '🌋', Color(0xFFC2410C)),
  'poisoncave': ('Caverna venenosa', '🍄', Color(0xFF7E22CE)),
  'seacave': ('Caverna aquática', '🐚', Color(0xFF0E7490)),
  'waterfall': ('Gruta da cachoeira', '🏞️', Color(0xFF0369A1)),
  'desert': ('Deserto', '🏜️', Color(0xFFB45309)),
  'ruins': ('Ruínas', '🏛️', Color(0xFFA16207)),
  'flowers': ('Campo de flores', '🌸', Color(0xFFDB2777)),
  'plant': ('Usina', '⚡', Color(0xFFCA8A04)),
  'crystal': ('Mina de cristal', '💎', Color(0xFF7C3AED)),
  'dunes': ('Deserto à noite', '🌙', Color(0xFF4338CA)),
  'bamboo': ('Bambuzal', '🎋', Color(0xFF4D7C0F)),
  'temple': ('Templo', '⛩️', Color(0xFFB91C1C)),
  // As bases das equipes vilãs (só capangas).
  'base-rocket': ('Base da Equipe Rocket', '🏴', Color(0xFFB91C1C)),
  'base-aqua': ('Base da Equipe Aqua', '🏴', Color(0xFF1D4ED8)),
  'base-magma': ('Base da Equipe Magma', '🏴', Color(0xFFC2410C)),
  'base-galactic': ('Base da Equipe Galáctica', '🏴', Color(0xFF0E7490)),
  'base-plasma': ('Castelo da Equipe Plasma', '🏴', Color(0xFF1E40AF)),
  'base-flare': ('Laboratório da Equipe Flare', '🏴', Color(0xFFDC2626)),
  'base-skull': ('Base da Equipe Skull', '🏴', Color(0xFF6B21A8)),
  'base-aether': ('Paraíso Aether', '🏴', Color(0xFFCA8A04)),
  'base-star': ('Base da Equipe Star', '🏴', Color(0xFFDB2777)),
  'base-yell': ('Spikemuth (Equipe Yell)', '📣', Color(0xFFBE185D)),
  'base-macro': ('Rose Tower (Macro Cosmos)', '🏢', Color(0xFF1D4ED8)),
};

/// O nome curto de cada melhoria (nos requisitos da árvore). Igual ao site.
const _upgradeNames = {
  'level': 'Treino', 'ivs': 'Genética', 'balls': 'Poké Balls', 'potions': 'Potions', 'revive': 'Revives', 'money': 'Dinheiro',
  'shop': 'Desconto', 'exp': 'XP extra', 'expShare': 'Exp. Share', 'reroll': 'Sortear caminho', 'cards': 'Carta a mais', 'shiny': 'Shiny',
  'greatBalls': 'Great Balls', 'rope': 'Escape Rope', 'coins': 'Moedas', 'map': 'Mapa', 'dmax': 'Dynamax Band', 'tera': 'Tera Orb',
  'superPotions': 'Super Potions', 'hyperPotions': 'Hyper Potions', 'maxPotions': 'Max Potions', 'sitrus': 'Sitrus Berry', 'lum': 'Lum Berry', 'leftovers': 'Leftovers',
  'sash': 'Focus Sash', 'ultraBalls': 'Ultra Balls', 'masterBall': 'Master Ball', 'quickBalls': 'Mão firme', 'netBalls': 'Mira certeira', 'timerBalls': 'Paciência',
  'duskBalls': 'Isca', 'expPlus': 'XP avançado', 'luckyEgg': 'Lucky Egg', 'hpBoost': 'Vigor', 'speBoost': 'Agilidade', 'tutor': 'Move Tutor',
  'reminder': 'Move Reminder', 'atk': 'Força', 'spa': 'Foco', 'def': 'Couraça', 'spd': 'Escudo', 'allStats': 'Mestre',
  'band': 'Choice Band', 'scarf': 'Choice Scarf', 'specs': 'Choice Specs', 'lifeOrb': 'Life Orb', 'vest': 'Assault Vest', 'helmet': 'Rocky Helmet',
  'quickClaw': 'Quick Claw', 'balloon': 'Air Balloon', 'brightPowder': 'Bright Powder', 'boots': 'Heavy-Duty Boots', 'kingsRock': 'King\'s Rock', 'loot': 'Recompensas',
  'expertBelt': 'Expert Belt', 'bonusCoins': 'Tesouro', 'policy': 'Weakness Policy', 'muscleBand': 'Muscle Band', 'wiseGlasses': 'Wise Glasses', 'shellBell': 'Shell Bell',
  'scopeLens': 'Scope Lens', 'eviolite': 'Eviolite', 'victoryHeal': 'Recuperação',
};

/// Cada ponto do mapa: símbolo, nome e o que tem nele.
const _nodeInfo = <String, (String, String, String)>{
  'wild': ('🌿', 'Pokémon selvagem', 'Dá para capturar: jogue a bola antes de ele desmaiar.'),
  'trainer': ('🧢', 'Treinador', 'Dinheiro em dobro.'),
  'ace': ('💪', 'Treinador forte', 'Um Pokémon a mais e mais forte; sempre deixa um item.'),
  'mart': ('🎒', 'Vendedor ambulante', 'Vende o mesmo que o Poké Mart (sem batalha, sem XP).'),
  'center': ('⛺', 'Parada para descanso', 'Alguém do caminho cura o time todo, até quem desmaiou (sem batalha).'),
  'event': ('❓', 'Evento', 'Itens, dinheiro, frutas ou uma ficha de Move Tutor (sem batalha).'),
  'trade': ('🔁', 'Troca', 'Alguém da rota troca um Pokémon com você: o que vem chega 3 níveis acima (com o item de quem foi) e ganha mais XP.'),
  'safari': ('🦒', 'Safari Zone', 'Sem batalha: a entrada custa 500 moedas. 10 Safari Balls para capturar Pokémon raros.'),
  'wildboss': ('🐉', 'Chefe sem treinador', 'Uma Mega, um Gigantamax ou um lendário. Dá para capturar.'),
  'meteor': ('☄️', 'Chuva de meteoros', 'Um Clefairy apareceu com os meteoros (mais chance de shiny).'),
  'mythic': ('✨', 'Pokémon mítico', 'Um Pokémon mítico, raríssimo. Dá para capturar.'),
  'boss': ('👑', 'Chefe', ''),
  'bike': ('🚲', 'Pedalar', 'De bicicleta: passa o andar sem batalha (e sem prêmio).'),
  'rematch': ('🏆', 'Revanche do Campeão', 'O Campeão que você venceu quer revanche: time mais forte, prêmio maior.'),
  'rival': ('⚔️', 'Rival', 'O seu rival te seguiu pela rota: quer ver quem ficou mais forte (prêmio maior).'),
  'leave': ('↩️', 'Voltar', 'Sai da água e volta para onde você entrou.'),
  'area': ('👑', 'Chefe do lugar', 'O Pokémon mais forte daqui (sem treinador): dá para capturar.'),
  'dboss': ('💀', 'Chefe', ''),
};

/// As MOs: o nome (do jogo, sem traduzir), o ícone e o que fazem na corrida. Igual ao site.
const _hmInfo = <String, (String, String, String)>{
  'cut': ('Cut', '✂️', 'Uma vez por rota, corta uma árvore e abre um caminho escondido (um selvagem raro).'),
  'flash': ('Flash', '💡', 'Ilumina cavernas, esgotos e torres: dá para ver os caminhos sem o Mapa, e a caverna secreta sempre tem algo.'),
  'surf': ('Surf', '🌊', 'Deixa navegar pelo mar (o caminho para o Mar).'),
  'dive': ('Dive', '🤿', 'Deixa mergulhar até o fundo do mar.'),
  'rock-smash': ('Rock Smash', '🪨', 'Uma vez por rota, nas cavernas, montanhas e desertos, quebra uma rocha: aparece um selvagem raro do lugar.'),
  'strength': ('Strength', '💪', 'Uma vez por rota, nas cavernas e montanhas, empurra uma pedra: atrás dela, um treinador forte (sempre deixa um item).'),
  'waterfall': ('Waterfall', '🏞️', 'Sobe a cachoeira do Mar até a gruta atrás dela (selvagens e um chefe forte).'),
};

/// O aviso do caminho bloqueado: a MO que falta e com qual insígnia ela vem. Igual ao site.
const _hmHints = {
  'surf': 'Precisa de um Pokémon com Surf no time (ou da 3ª insígnia).',
  'dive': 'Precisa de um Pokémon com Dive no time (ou da 5ª insígnia).',
  'waterfall': 'Precisa de um Pokémon com Waterfall no time (ou da 7ª insígnia).',
};
/// Os itens-chave: o símbolo e para que servem (os nomes são os dos jogos, sem traduzir). Igual ao site.
const _keyInfo = {
  'silph-scope': ('🔭', 'Deixa ver os fantasmas da Pokémon Tower: agora dá para entrar.'),
  'poke-flute': ('🪈', 'Acorda o Snorlax que dorme na rota até Fuchsia City.'),
  'squirt-bottle': ('🚿', 'Molha o Sudowoodo que bloqueia a rota até Ecruteak City.'),
  'old-rod': ('🎣', 'Dá para pescar onde há água (uma vez por rota): vêm os Pokémon de Água mais comuns.'),
  'good-rod': ('🎣', 'Uma vara melhor: na pesca vêm Pokémon de Água menos comuns.'),
  'super-rod': ('🎣', 'A melhor vara: na pesca vêm os Pokémon de Água raros.'),
  'bicycle': ('🚲', 'Uma vez por rota (duas na Cycling Road), passa um andar sem batalha.'),
  'ss-ticket': ('🎫', 'Deixa embarcar na balsa dos portos e das ilhas: treinadores a bordo e um prêmio no fim.'),
};

/// Os caminhos da rodada 14: a pesca e as árvores. Igual ao site.
const _fishInfo = ('🎣', 'Pescaria', 'Um Pokémon de Água mordeu a isca: quem vem depende da vara.');
const _headbuttInfo = ('🌳', 'Árvore sacudida', 'Caiu um Pokémon que vive na árvore.');
const _honeyInfo = ('🍯', 'Árvore de mel', 'Um Pokémon raro está lambendo o mel (mais chance de shiny).');

/// Os desafios dos ginásios, cada um no tema do tipo (os quebra-cabeças dos jogos): o nome e o que fazer. Igual ao site.
const _puzzleInfo = {
  'normal': ('Quem é esse Pokémon?', 'Reconheça a silhueta: acerte 2 de 3.'),
  'fire': ('O quiz do Blaine', 'Responda as perguntas do líder: acerte 2 de 3.'),
  'water': ('O piso de gelo do Juan', 'Pise em todos os ladrilhos uma única vez: pisar de novo quebra o gelo.'),
  'grass': ('O jardim da Erika', 'Ache o caminho entre as cercas vivas até a líder, sem gastar os passos.'),
  'electric': ('As lixeiras do Lt. Surge', 'Dois interruptores, um ao lado do outro, estão escondidos nas lixeiras. O número diz a quantas casas está o mais próximo.'),
  'ice': ('O gelo do Pryce', 'No gelo você escorrega até bater numa pedra. Chegue ao líder.'),
  'fighting': ('Os sacos de pancada da Maylene', 'Memorize a ordem dos golpes e repita sem errar.'),
  'poison': ('As paredes invisíveis do Koga', 'As paredes não aparecem até você bater nelas. Chegue ao líder com poucas batidas.'),
  'ground': ('Os ladrilhos giratórios do Giovanni', 'Cada ladrilho te joga em linha reta até bater. Chegue ao líder.'),
  'flying': ('Os canhões da Skyla', 'O canhão te atira em linha reta até a parede. Chegue à líder.'),
  'psychic': ('Os teleportes da Sabrina', 'Memorize a ordem das plataformas e repita sem errar.'),
  'bug': ('As teias do Bugsy', 'Duas alavancas, uma ao lado da outra, estão escondidas nas teias. O número diz a quantas casas está a mais próxima.'),
  'rock': ('As lajes do Roark', 'Pise em todas as lajes uma única vez: pisar de novo faz desmoronar.'),
  'ghost': ('A ponte invisível do Morty', 'O caminho não aparece: um passo fora dele e você cai. Chegue ao líder.'),
  'dragon': ('As estátuas de dragão do Drayden', 'Memorize a ordem das estátuas e repita sem errar.'),
  'dark': ('No escuro: quem é esse Pokémon?', 'As luzes estão apagadas. Reconheça a silhueta: acerte 2 de 3.'),
  'steel': ('As esteiras do Byron', 'A esteira te leva em linha reta até bater. Chegue ao líder.'),
  'fairy': ('O quiz da Opal', 'Responda as perguntas da líder: acerte 2 de 3.'),
};
const _puzzleCell = {'me': '🧍', 'goal': '🏅', 'rock': '🪨', 'wall': '🧱', 'floor': '', 'done': '✅', 'closed': '🗑️', 'hit': '🔘'};
const _puzzleSkin = {
  'bug': {'closed': '🕸️', 'hit': '🕹️'}, 'water': {'done': '💧', 'floor': '🧊'}, 'rock': {'done': '🪨', 'floor': '⬜'}, 'ghost': {'wall': '🕳️'}, 'grass': {'wall': '🌳'}, 'ice': {'floor': '🧊'},
};
const _puzzleSymbols = {
  'fighting': ['👊', '🦵', '🤜', '🥋'], 'psychic': ['🔴', '🔵', '🟢', '🟡'], 'dragon': ['🐉', '🐲', '🔥', '💎'],
};
const _puzzleQuestion = {
  'strong': 'Qual tipo é super efetivo contra {0}?', 'typeOf': 'Qual é um dos tipos de {0}?', 'hasType': 'Qual destes Pokémon é do tipo {0}?', 'who': 'Quem é esse Pokémon?',
};
const _typePt = {
  'normal': 'Normal', 'fire': 'Fogo', 'water': 'Água', 'grass': 'Planta', 'electric': 'Elétrico', 'ice': 'Gelo', 'fighting': 'Lutador', 'poison': 'Venenoso', 'ground': 'Terra',
  'flying': 'Voador', 'psychic': 'Psíquico', 'bug': 'Inseto', 'rock': 'Pedra', 'ghost': 'Fantasma', 'dragon': 'Dragão', 'dark': 'Sombrio', 'steel': 'Aço', 'fairy': 'Fada',
};

/// O item-chave que falta para este caminho (o Silph Scope, a Poké Flute, a Squirt Bottle) ou null.
Object? _keyNeeded(Json run, Map? node) {
  for (final k in [node?['needs'], node?['blocker']]) {
    if (k != null && !FactoryRun.hasKey(run, k)) return k;
  }
  return null;
}

const _blockerInfo = ('💤', '{0} bloqueia o caminho', 'Com o item certo, ele acorda e luta. Dá para capturar.');
const _aroundInfo = ('↪️', 'Dar a volta', 'Um treinador no desvio; ele continua lá, dormindo.');
const _placeLegendHelp = 'O lendário daqui: é o chefe do lugar. Dá para capturar.';
String _hmHint(Json run, Map? node) => _keyNeeded(run, node) != null
    ? tr(node?['blocker'] != null ? 'Precisa de {0} para acordá-lo; sem ela, só dando a volta.' : 'Precisa de {0} para entrar.').replaceAll('{0}', FactoryRun.keyItems[_keyNeeded(run, node)] ?? '')
    : node?['kind'] == 'safari' && FactoryRun.hmNeeded(run, node) == null
        ? tr('Você precisa de {0} moedas para entrar.').replaceAll('{0}', '${FactoryRun.safariFee}')
        : tr(_hmHints[FactoryRun.hmNeeded(run, node)] ?? _hmHints['surf']!);

/// O clima do lugar (a previsão no mapa). Igual ao site.
const _weatherLabel = {'rain': '🌧️ Chuva', 'sun': '☀️ Sol forte', 'sand': '🏜️ Tempestade de areia', 'snow': '❄️ Neve'};
/// O clima da rota (o mesmo em todos os andares dela) atrai Pokémon diferentes. Igual ao site.
const _weatherPull = {'rain': 'mais Água, Elétrico e Inseto', 'sun': 'mais Fogo, Planta e Terra', 'sand': 'mais Pedra, Terra e Aço', 'snow': 'mais Gelo'};
const _cutInfo = ('🌳', 'Caminho escondido', 'Aberto com Cut: um selvagem raro do lugar.');
const _smashInfo = ('🪨', 'Rocha quebrada', 'Aberta com Rock Smash: um selvagem raro do lugar.');
const _strengthInfo = ('💪', 'Pedra empurrada', 'Aberta com Strength: um treinador forte (sempre deixa um item).');

/// O símbolo do caminho aberto por uma MO (Cut, Rock Smash, Strength). Igual ao site.
(String, String, String)? _hmPathInfo(Map node) => node['cut'] == true
    ? _cutInfo
    : node['smash'] == true
        ? _smashInfo
        : node['strength'] == true
            ? _strengthInfo
            : node['blocker'] != null
                ? _blockerInfo
                : node['around'] == true
                    ? _aroundInfo
                    : node['fish'] != null
                        ? _fishInfo
                        : node['tree'] == 'headbutt'
                            ? _headbuttInfo
                            : node['tree'] == 'honey'
                                ? _honeyInfo
                                : null;
const _eventText = {
  'items': 'Você achou {1}× {0} no caminho!',
  'money': 'Um treinador perdeu 💰{0} e não voltou para buscar.',
  'berries': 'Frutas no caminho: o time recuperou 30% do HP.',
  'tutor': 'Um velho professor te deu uma ficha de Move Tutor.',
  'declined': 'Você seguiu o seu caminho.',
  'bike': 'Você pedalou por este trecho sem encontrar ninguém.',
  'helped': 'O treinador agradeceu e te deu {0}!',
  'secretFound': 'Na caverna secreta: {0} e 💰{1}!',
  'secretEmpty': 'A caverna estava vazia... e escura demais para procurar.',
  'bought': 'O mercador sorriu e te entregou {0}.',
  'betWon': 'Você ganhou a aposta: +💰{0}!',
  'betLost': 'Você perdeu a aposta: −💰{0}.',
  'injuredJoined': 'Você usou {0} e o Pokémon ferido quis ir com você!',
  'noPotion': 'Sem nenhuma poção na Bolsa, não deu para curar o Pokémon ferido.',
};
const _eventIcon = {
  'bike': '🚲', 'money': '💰', 'berries': '🍒', 'tutor': '📀', 'declined': '👣', 'helped': '🤝', 'secretFound': '💎', 'secretEmpty': '🕳️', //
  'bought': '🧳', 'betWon': '🎰', 'betLost': '🎰', 'injuredJoined': '💚', 'noPotion': '🩹',
};

/// As escolhas da rota: o ícone, o texto e os botões. Igual ao site.
const _choiceInfo = <String, (String, String, String, String)>{
  'help': ('🙋', 'Um treinador perdeu as Poké Balls e pede ajuda: dar 💰{0} para ele?', 'AJUDAR', 'RECUSAR'),
  'follow': ('🐾', 'Um Pokémon ferido foge para dentro do mato. Seguir ele?', 'SEGUIR', 'DEIXAR'),
  'secret': ('🕳️', 'Uma entrada escondida entre as pedras: entrar na caverna secreta?', 'ENTRAR', 'NÃO ENTRAR'),
  'merchant': ('🧳', 'Um mercador misterioso oferece {2} por 💰{0}. Comprar?', 'COMPRAR', 'RECUSAR'),
  'bet': ('🎰', 'Um apostador te desafia: 💰{0} no cara ou coroa. Dobra ou perde tudo!', 'APOSTAR', 'RECUSAR'),
  'injured': ('🩹', 'Um {1} ferido na beira do caminho. Usar uma poção nele? Curado, ele quer ir com você.', 'CURAR', 'DEIXAR'),
};

/// A missão da rota. Igual ao site.
const _missionText = {
  'defeat': 'Derrote {0} Pokémon do tipo {1}',
  'catch': 'Capture um Pokémon do tipo {1}',
  'grunts': 'Derrote {0} capangas da base',
};
String _mission(Map m) {
  final type = '${m['type'] ?? ''}';
  return tr(_missionText['${m['kind']}'] ?? '').replaceAll('{0}', '${m['need']}').replaceAll('{1}', type.isEmpty ? '' : type[0].toUpperCase() + type.substring(1));
}

/// As pistas do lendário da região (a última: na rota para a Liga). Igual ao site.
const _legendClues = [
  'Os moradores falam de um Pokémon lendário que vive nesta região...',
  'Pegadas enormes no caminho: algo muito poderoso passou por aqui.',
  'Um velho conta que o lendário só aparece para quem chega perto da Liga.',
  'O ar está pesado: o lendário espera num dos caminhos para a Liga!',
];

/// O líder antes da luta, pelo tipo do ginásio. Igual ao site.
const _leaderLines = {
  'normal': 'Força bruta e simplicidade: o meu time não tem fraquezas escondidas!',
  'fire': 'As chamas do meu ginásio vão testar a sua coragem!',
  'water': 'Vamos ver se você aguenta a força da correnteza!',
  'grass': 'A natureza tem paciência... e raízes fortes. Prepare-se!',
  'electric': 'Sente o choque? É a energia do meu ginásio!',
  'ice': 'Frio e calma: assim se vence uma batalha.',
  'fighting': 'Treino todo dia desde o nascer do sol. Mostre a sua garra!',
  'poison': 'Um passo em falso e o veneno decide a luta.',
  'ground': 'Pise firme: aqui o chão é meu aliado!',
  'flying': 'Vamos ver se você consegue acompanhar o vento!',
  'psychic': 'Eu já vi como esta batalha termina... mas venha mesmo assim.',
  'bug': 'Pequenos, mas espertos: os insetos sempre surpreendem!',
  'rock': 'Duro como pedra: o meu time não cede!',
  'ghost': 'Hehe... os meus Pokémon adoram visitas.',
  'dragon': 'Os dragões só respeitam quem é forte de verdade!',
  'dark': 'Nas sombras, quem ataca primeiro vence.',
  'steel': 'Aço polido e estratégia: nenhum golpe passa fácil.',
  'fairy': 'Encanto e poder: não se engane com a aparência!',
};

/// Depois da luta: o líder entrega a insígnia, o rival reage (conforme perde), o vilão foge. Igual ao site.
const _beatLines = {
  'gym': 'Você venceu de forma justa. Esta insígnia é sua!',
  'elite': 'Impressionante... siga em frente: o próximo da Elite espera.',
  'champion': 'Você é o novo Campeão! O seu nome vai para o Hall da Fama.',
  'villain': 'Isso não acaba aqui! Os nossos planos continuam...',
};
const _rivalBeat = [
  'Hmpf... foi sorte! Da próxima vez eu ganho.',
  'De novo?! Vou treinar em dobro, pode esperar.',
  'Você ficou forte de verdade... mas eu não desisto.',
  'Tudo bem, você é melhor. Te espero na Liga!',
];

/// O plano de cada equipe vilã. Igual ao site.
const _villainPlans = {
  'rocket': 'A Equipe Rocket quer roubar Pokémon raros e dominar o mundo!',
  'aqua': 'A Equipe Aqua quer despertar o lendário e cobrir a terra com o mar!',
  'magma': 'A Equipe Magma quer secar os mares e aumentar a terra firme!',
  'galactic': 'A Equipe Galáctica quer apagar o mundo e criar um novo, sem espírito!',
  'plasma': 'A Equipe Plasma quer separar os Pokémon de todos os treinadores!',
  'flare': 'A Equipe Flare quer um mundo belo... só para eles!',
  'skull': 'A Equipe Skull só quer bagunça e roubar Pokémon por aí!',
  'aether': 'A Fundação Aether esconde segredos sobre as Ultra Beasts!',
  'star': 'A Equipe Star tem os próprios motivos... prove que merece saber!',
};
/// A estação e a hora (do relógio de quem joga): mudam os Pokémon que aparecem e o clima. Igual ao site.
const _seasonLabel = {'spring': '🌸 Primavera', 'summer': '☀️ Verão', 'autumn': '🍂 Outono', 'winter': '❄️ Inverno'};
const _legendInfo = ('🌟', 'Lendário', 'O lendário da região espera aqui. Dá para capturar.');

/// O lendário que foge (Raikou, Entei, Suicune...). Igual ao site.
const _roamInfo = ('🐾', 'Lendário que foge', 'Foge depois do primeiro turno (dormindo ou congelado, não); o HP que você tirar fica para a próxima vez. Dá para capturar.');

/// O capanga do plano da equipe vilã (nas cidades antes da base).
const _plotInfo = ('🚨', 'Capanga da equipe vilã', 'Vencendo, você atrapalha o plano: ganha uma Ultra Ball e o chefe da equipe vem mais fraco.');

/// O nome do lendário que foge sem a forma (Tornadus, não "Tornadus incarnate").
String _roamName(String n) => n.replaceFirst(RegExp(r'[\s-]incarnate$', caseSensitive: false), '');

/// O HUD do mapa: os efeitos do lugar (ícone e nome). Igual ao site.
const _fieldHud = {
  'diamonds': ('💎', 'Chuva de diamantes'), 'rockfall': ('🪨', 'Desmoronamento'), 'ashes': ('🌋', 'Cinzas ardentes'), 'miasma': ('☠️', 'Névoa tóxica'),
  'chill': ('🥶', 'Frio cortante'), 'haunt': ('👻', 'Aura sombria'), 'current': ('🌊', 'Correnteza'), 'spores': ('🍄', 'Esporos'),
  'quicksand': ('⏳', 'Areia movediça'), 'storm': ('⛈️', 'Tempestade'), 'aurora': ('🌌', 'Aurora'), 'fog': ('🌫️', 'Neblina'), 'wind': ('🌬️', 'Ventos fortes'),
  'grassy': ('🌿', 'Grassy Terrain'), 'electric': ('⚡', 'Electric Terrain'), 'psychic': ('🔮', 'Psychic Terrain'), 'misty': ('🌸', 'Misty Terrain'),
};
const _ballHelp = {
  'poke-ball': 'Para capturar os selvagens (jogue na batalha)',
  'great-ball': 'Captura 1,5× melhor',
  'ultra-ball': 'Captura 2× melhor',
  'quick-ball': '5× melhor no primeiro turno',
  'net-ball': '3,5× melhor em Água e Inseto',
  'dusk-ball': '3× melhor em cavernas e torres',
  'timer-ball': 'Melhora a cada turno (até 4×)',
  'master-ball': 'Captura sempre',
};

String _bossKind(Object? kind) =>
    {'gym': tr('Líder de ginásio'), 'rival': tr('Rival'), 'villain': tr('Vilão'), 'elite': tr('Elite dos Quatro'), 'champion': tr('Campeão')}[kind] ?? '';

/// O passo da tela depois do andar: o que ainda falta ver ou escolher (ou nada: o mapa). Igual ao site.
String? _stepOf(Map? p) {
  if (p == null) return null;
  if (p['choice'] != null) return 'choice';
  if (p['seen'] != true && (p['exp'] != null || p['center'] == true || p['event'] != null)) return 'result';
  if (p['capture'] != null) return 'capture';
  if (p['cards'] != null) return 'cards';
  if (p['safari'] != null) return 'safari';
  if (p['puzzle'] != null) return 'puzzle';
  if (p['trade'] != null) return 'trade';
  if (p['shop'] != null) return 'shop';
  return null;
}

/// A corrida em tela cheia, no lugar da batalha: o resultado do andar, o
/// capturado, a carta, a loja (com "Continuar") e o mapa com os caminhos do
/// próximo andar. onBattle(run): começa a batalha do caminho escolhido. Igual ao site.
class FactoryScreen extends StatefulWidget {
  final Future<void> Function(Json run) onBattle;
  final VoidCallback onExit;
  final bool busy;
  const FactoryScreen({super.key, required this.onBattle, required this.onExit, this.busy = false});

  @override
  State<FactoryScreen> createState() => _FactoryScreenState();
}

class _FactoryScreenState extends State<FactoryScreen> {
  /// Já pediu para continuar a batalha guardada (uma vez só por abertura da tela).
  bool _resumeAsked = false;

  FactoryData? _data = FactoryData.loaded;
  Map<int, String> _names = const {};
  int _target = 0;
  int? _unlocked;

  /// Conquistas novas desta tela (com as moedas).
  final List<String> _earned = [];
  int? _regionPick; // a cidade tocada no mapa da região
  String? _panel; // embaixo do menu: 'bag' | 'team' (na loja, a lista de compras)
  Widget? _framePanel; // o que abre dentro da moldura (lista da loja, Bolsa ou time)

  static Color get _border => Hud.edge;
  static const _ink = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    FactoryData.load().then((d) => mounted ? setState(() => _data = d) : null);
    Trainers.load().then((_) => mounted ? setState(() {}) : null);
    LocalDatabase.instance.allPokemonRows().then((rows) {
      if (mounted) setState(() => _names = {for (final r in rows) r['id'] as int: '${r['name']}'});
    });
  }

  /// A música do mapa tocando agora (map_<região>); a batalha troca pela dela e, voltando, o mapa começa de novo.
  String? _track;
  void _music(String? track) {
    if (track == _track) return;
    _track = track;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _track != track) return;
      track == null ? BattleSounds.stopMusic(this) : BattleSounds.startMusic(track, this);
    });
  }

  @override
  void dispose() {
    BattleSounds.stopMusic(this);
    super.dispose();
  }

  String _name(Object? id) => battleMonName({'name': _names[(id as num?)?.toInt()] ?? ''});

  /// Salva; sem mais nada para ver depois do andar, abre o mapa (os caminhos do próximo).
  void _save(Json? next, [Json? meta]) {
    if (next == null) return;
    final out = next['pending'] != null && _stepOf(next['pending'] as Map) == null ? FactoryRun.nextFloor(next, _data!) : next;
    setState(() => saveFactory({...(meta ?? currentFactory()), 'run': out}));
  }

  static String _help(String id) {
    if (_ballHelp.containsKey(id)) return tr(_ballHelp[id]!);
    if (id.startsWith('tm:')) return tr('Ensina o golpe a quem aprende por TM (uma vez)');
    if (id.startsWith('evo:')) return tr('Evolui na hora quem evolui com ela (escolha acima)');
    if (id == 'move-tutor') return tr('Ensina um golpe de tutor ou de ovo (uma vez)');
    if (id == 'move-reminder') return tr('Lembra um golpe do nível (uma vez)');
    if (id == 'dynamax-band') return tr('Libera o Dynamax (e o Gigantamax) para o time');
    if (id == 'tera-orb') return tr('Libera a Terastalização para o time');
    if (id == 'escape-rope') {
      return tr('Se perder uma batalha, o time foge com {0}% do HP e a corrida continua (gasta uma)').replaceAll('{0}', '${(FactoryRun.escapeHp * 100).round()}');
    }
    if (id == 'lucky-egg') {
      return tr('Quem segura ganha +{0}% de XP (como extra, +{1}%)')
          .replaceAll('{0}', '${((FactoryRun.luckyEgg.held - 1) * 100).round()}')
          .replaceAll('{1}', '${((FactoryRun.luckyEgg.extra - 1) * 100).round()}');
    }
    if (id == 'exp-share') return tr('O time todo ganha XP (quem não lutou, a metade)');
    if (id == 'town-map') return tr('Mostra o mapa da rota e deixa escolher o caminho nas bifurcações (sem ele, vai às cegas)');
    if (id == 'revive') return tr('Revive com metade do HP');
    final share = FactoryRun.healShare[id];
    if (share != null) return share >= 1 ? tr('Recupera todo o HP') : tr('Recupera {0}% do HP').replaceAll('{0}', '${(share * 100).round()}');
    if (id == 'rare-candy') return tr('+1 nível');
    final vitamin = FactoryRun.vitamins[id];
    if (vitamin != null) {
      return tr('+{0} EVs em {1}, sem limite').replaceAll('{0}', '${FactoryRun.vitaminEvs}').replaceAll('{1}', _statLabel[vitamin]!);
    }
    if (id == 'bottle-cap') return tr('+{0} IVs em todos os atributos, sem limite').replaceAll('{0}', '${FactoryRun.bottleCapIvs}');
    final boost = FactoryRun.heldBoost[id];
    if (boost != null) {
      final extra = tr('Segura o item; se já tem um, vira extra ({0})')
          .replaceAll('{0}', [for (final e in boost.entries) '+${(e.value * 100).round()}% ${_statLabel[e.key]}'].join(', '));
      return _heldEffect[id] != null ? '${tr(_heldEffect[id]!)}. $extra' : extra;
    }
    // Mega Pedras e Cristais Z (drops dos chefes).
    if (RegExp(r'-z$').hasMatch(id)) return tr('Cristal Z: um golpe do tipo dele vira Movimento Z (uma vez por batalha)');
    if (RegExp(r'ite(-[xy])?$').hasMatch(id) && id != 'eviolite') return tr('Mega Pedra: o Pokémon dela megaevolui (uma vez por batalha)');
    return '';
  }

  // ------------------------------------------------------------ a moldura da batalha

  /// O lugar do campo que está sendo desenhado (os Pokémon e quem está de pé ficam na base com a cor dele).
  String _scene = 'grass';

  /// O campo da batalha, no mesmo tamanho (4:3, como no Black & White) e com o mesmo cenário dela, no lugar em que você está.
  Widget _field(String biome, List<Widget> Function(double w, double h) children, {Key? key}) => ClipRRect(
        key: key,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: _border, width: 4), color: const Color(0xFF9FDCFF)),
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              _scene = battleScene(biome, 0);
              return Stack(children: [Positioned.fill(child: BattleBackdrop(scene: _scene)), ...children(w, h)]);
            }),
          ),
        ),
      );

  /// Um Pokémon no campo, no mesmo lugar da batalha: o seu de costas (grande, na frente à esquerda) ou de frente lá
  /// atrás à direita, do tamanho dele (pela altura) e em cima da base dele.
  Widget _fieldMon(Map mon, double w, double h, {bool back = false}) {
    final sprite = StageMon(id: (mon['id'] as num).toInt(), shiny: mon['shiny'] == true, back: back, scene: _scene);
    return back
        ? Positioned(left: w * 0.01, bottom: h * 0.22, width: w * 0.58, height: w * 0.58, child: sprite)
        : Positioned(right: w * 0.11, bottom: h * foeBottom(_scene), width: w * 0.26, height: w * 0.26, child: sprite);
  }

  /// Alguém de pé na base de lá de trás (Enfermeira Joy, o chefe, um item...).
  /// plain: sem a base (o vendedor no próprio lugar, fora da batalha).
  Widget _far(Widget child, double w, double h, {bool plain = false}) => Positioned(
      right: w * 0.06,
      bottom: h * foeBottom(_scene),
      width: w * 0.36,
      height: w * 0.36,
      child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
        // Uma base do tamanho de um Pokémon médio (Snorlax tem 21 dm; 13 dm dá ~0,8).
        if (!plain) PlatformBase(scene: _scene, side: 'foe', id: 0),
        // Pode passar da base (os treinadores ficam da altura do treinador de lá na batalha).
        OverflowBox(alignment: Alignment.bottomCenter, minWidth: 0, minHeight: 0, maxWidth: w * 0.6, maxHeight: w * 0.6, child: child),
      ]));

  /// Alguém lá atrás (vendedor, Enfermeira...) da altura de uma pessoa perto dos Pokémon.
  Widget _farPerson(String id, double w) {
    final t = Trainers.byId(id);
    return t != null ? TrainerSprite(t, height: farPerson(w)) : _trainerImage(id, farPerson(w) * 80 / trainerAdultPx);
  }

  Widget _trainerImage(String id, double size) => Image.asset('assets/database/sprites/trainers/$id.png',
      height: size, fit: BoxFit.contain, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => const SizedBox());

  /// A barra da corrida (como a do campo na batalha): andar, dinheiro, Bolsa e o time.
  Widget _bar(Json run) {
    final bag = FactoryRun.bagOf(run);
    const style = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      key: const ValueKey('factory-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      // A cor da região (o tema dela na barra). Igual ao site.
      decoration: BoxDecoration(
        color: Hud.tint(const Color(0xFF334155)),
        gradient: _data == null
            ? null
            : LinearGradient(colors: [
                _regionTheme['${_data!.bosses[(run['boss']['region'] as num).toInt()]['region']}'] ?? Hud.tint(const Color(0xFF334155)),
                Hud.tint(const Color(0xFF334155)),
              ], stops: const [0, 0.7]),
        border: Border.symmetric(vertical: BorderSide(color: _border, width: 4)),
      ),
      // Uma linha só, da altura da faixa da batalha (rola de lado se não couber): nada muda de tamanho.
      height: battleBarHeight(context),
      // As informações rolam de lado; o time fica sempre à direita. A Bolsa é só a contagem (o que tem dentro: em BOLSA).
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final w in <Widget>[
                Text('🎲 ${tr('Andar {0}').replaceAll('{0}', '${run['floor']}')}', style: style),
                // O jogo da corrida (cada um é um degrau de dificuldade).
                Tooltip(
                  message: tr('Jogo {0} da corrida: adversários +{1}% em todos os atributos')
                      .replaceAll('{0}', '${FactoryRun.gameOf(run)}')
                      .replaceAll('{1}', '${(FactoryRun.foeBoostAt(FactoryRun.tierOf(run)) * 100).round()}'),
                  child: Text('🎮 ${FactoryRun.gameOf(run)}', key: const ValueKey('factory-game'), style: style),
                ),
                Text('💰 ${run['money']}', style: style),
                Text('🎒 ${FactoryRun.bagItems.fold<int>(0, (n, id) => n + (bag[id] ?? 0))}', key: const ValueKey('factory-bag-count'), style: style),
                // Os ovos que vão junto: quantas vitórias faltam para chocar.
                for (final e in FactoryRun.eggsOf(run))
                  Text('${e['mystery'] == true ? '❔' : '🥚'}${e['left']}', key: const ValueKey('factory-egg'), style: style),
                Text('📖 ${FactoryRun.dexOf(run).length}', key: const ValueKey('factory-dex'), style: style),
                if (_data != null) _badges(_data!, run),
                for (final hm in (run['hms'] as List? ?? const [])) Text(_hmInfo[hm]?.$2 ?? '', style: style),
                for (final k in (run['keyItems'] as List? ?? const [])) Text(_keyInfo[k]?.$1 ?? '', key: ValueKey('factory-key-$k'), style: style),
                if (((run['gcCoins'] as num?) ?? 0) > 0) Text('🎰 ${run['gcCoins']}', key: const ValueKey('factory-coins'), style: style),
                if (run['honey'] != null)
                  Text('🍯${max(0, FactoryRun.honeyFloors - ((run['floor'] as num).toInt() - (run['honey']['floor'] as num).toInt()))}', key: const ValueKey('factory-honey'), style: style),
                if (run['berry'] != null)
                  Text('🌱${max(0, (run['berry']['need'] as num).toInt() - ((run['floor'] as num).toInt() - (run['berry']['floor'] as num).toInt()))}', key: const ValueKey('factory-berry'), style: style),
                if (run['daycare'] != null) const Text('🏡', style: style),
              ])
                Padding(padding: const EdgeInsets.only(right: 8), child: w),
            ]),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final m in FactoryRun.teamOf(run))
            Column(mainAxisSize: MainAxisSize.min, children: [
              Opacity(opacity: FactoryRun.hpOf(m) > 0 ? 1 : 0.4, child: SizedBox(width: 20, height: 20, child: PokemonSprite((m['id'] as num).toInt(), shiny: m['shiny'] == true, fill: 0.9))),
              Container(
                width: 22,
                height: 3,
                color: const Color(0xFF0F172A),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: FactoryRun.hpOf(m).clamp(0.0, 1.0),
                  child: Container(color: FactoryRun.hpOf(m) > 0.5 ? const Color(0xFF34D399) : FactoryRun.hpOf(m) > 0.2 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444)),
                ),
              ),
            ]),
        ]),
      ]),
    );
  }

  /// O mapa da região: as cidades da história, na ordem, acendendo conforme você ganha as insígnias (a de agora
  /// piscando). Igual ao site.
  Widget _regionMap(Json run, FactoryData data, VoidCallback close) {
    final game = data.bosses[(run['boss']['region'] as num).toInt()];
    final leaders = (game['leaders'] as List).cast<Map>();
    final step = (run['boss']['step'] as num).toInt();
    final cities = <({String city, List<int> steps})>[];
    for (var k = 0; k < leaders.length; k++) {
      final city = leaders[k]['city'] as String?;
      if (city == null || city.isEmpty) continue;
      if (cities.isNotEmpty && cities.last.city == city) {
        cities.last.steps.add(k);
      } else {
        cities.add((city: city, steps: [k]));
      }
    }
    final color = _regionTheme['${game['region']}'] ?? const Color(0xFF334155);
    final c = SiteColors.of(context);
    // Onde o lendário que foge foi visto e as cidades do plano da equipe vilã (e a base dela).
    final roam = FactoryRun.roamerSeen(data, run);
    final plot = FactoryRun.villainPlot(data, run);
    final chapters = [for (final x in (plot?['chapters'] as List?) ?? const []) x as Map];
    final clock = FactoryRun.clockOf();
    final sky = FactoryRun.weatherOf(run, FactoryRun.shownScene(run, '${run['scene'] ?? 'grass'}', data), clock.season, data);
    Widget chip(String text, {Color bg = const Color(0xCC0F172A), String? key}) => Container(
          key: key == null ? null : ValueKey(key),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        );
    return Column(key: const ValueKey('region-map'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _overlayHeader('🗺️ ${game['region']} · ${game['game']}', close),
      Padding(
        key: const ValueKey('region-hud'),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(spacing: 4, children: [
          chip(clock.night ? '🌙 ${tr('Noite')}' : '☀️ ${tr('Dia')}'),
          chip(sky.isNotEmpty ? tr(_weatherLabel[sky] ?? sky) : '🌤️ ${tr('Tempo bom')}'),
          chip(tr(_seasonLabel[clock.season] ?? '')),
          if (plot != null)
            chip(
                '🚨 ${tr('Plano da {0}: {1}/{2} atrapalhados').replaceAll('{0}', _teamNames[plot['team']] ?? 'Equipe Rocket').replaceAll('{1}', '${plot['foiled']}').replaceAll('{2}', '${chapters.length}')}',
                bg: const Color(0xFFB91C1C),
                key: 'region-plot'),
          ]),
        ),
      ),
      if (regionMaps['${game['region']}'] != null)
        (_townMapRegion(run, '${game['region']}', [for (final x in cities) (city: x.city, steps: x.steps)], step, roam, plot, chapters))
      else
      Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.25), Colors.transparent]), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < cities.length; i++)
            Builder(builder: (context) {
              final done = cities[i].steps.every((k) => k < step);
              final here = !done && (i == 0 || cities[i - 1].steps.every((k) => k < step));
              return Padding(
                key: ValueKey(done ? 'city-lit' : here ? 'city-here' : 'city-dark'),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? const Color(0xFFFBBF24) : here ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                      border: Border.all(color: done ? const Color(0xFFFDE68A) : here ? Colors.white : const Color(0xFF64748B), width: 2),
                      boxShadow: [if (done) const BoxShadow(color: Color(0xFFFBBF24), blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cities[i].city, style: TextStyle(fontWeight: FontWeight.bold, color: done ? c.text : c.muted)),
                    // Onde o lendário que foge foi visto (embaixo do nome da cidade).
                    if (roam != null && cities[i].steps.contains(roam['at']))
                      Text('🐾 ${_roamName(_name(roam['id']))} ${tr('foi visto aqui')}',
                          key: const ValueKey('region-roamer'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ])),
                  if (here) Text('◀ ${tr('você está indo para cá')}', style: const TextStyle(fontSize: 11, color: Color(0xFF0EA5E9))),
                  for (final x in chapters)
                    if (cities[i].steps.contains(x['step']))
                      Text(' ${x['foiled'] == true ? '✔' : x['past'] == true ? '✖' : '🚨'}',
                          key: const ValueKey('region-plot-city'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  if (plot != null && plot['base'] == cities[i].city)
                    Text(' 🏴 ${tr('Base')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
                ]),
              );
            }),
        ]),
      ),
    ]);
  }

  /// O Town Map (como nos jogos): o mar, as terras, as rotas e as cidades; tocando numa, o nome dela embaixo. Igual
  /// ao site.
  Widget _townMapRegion(Json run, String region, List<({String city, List<int> steps})> cities, int step, Json? roam, Json? plot, List<Map> chapters) {
    bool done(int i) => cities[i].steps.every((k) => k < step);
    final hereIndex = [for (var i = 0; i < cities.length; i++) i].where((i) => !done(i) && (i == 0 || done(i - 1))).firstOrNull ?? -1;
    final int shown = (_regionPick ?? (hereIndex < 0 ? 0 : hereIndex)).clamp(0, cities.isEmpty ? 0 : cities.length - 1);
    // O mapa em que está a cidade escolhida (Johto também mostra Kanto).
    final map = regionMapFor(region, cities.isEmpty ? null : cities[shown].city)!;
    final storyNames = {for (final c in cities) c.city};
    String marks(int i) => [
          if (roam != null && cities[i].steps.contains(roam['at'])) '🐾',
          for (final x in chapters)
            if (cities[i].steps.contains(x['step'])) x['foiled'] == true ? '✔' : x['past'] == true ? '✖' : '🚨',
          if (plot != null && plot['base'] == cities[i].city) '🏴',
        ].join();
    final c = cities.isEmpty ? null : cities[shown];
    const ring = Color(0xFFF6A834);
    // Onde está o treinador: na rota, entre a cidade de antes e a próxima (pelo andar); na cidade, nela.
    List<double>? xyOf(int k) => k >= 0 && k < cities.length ? map.cities[cities[k].city] : null;
    final target = xyOf(hereIndex);
    final before = xyOf(hereIndex - 1) ?? (target == null ? null : [target[0] - 6, target[1] + 6]);
    final walk = (FactoryRun.routePos(run) / FactoryRun.routeLength).clamp(0.0, 1.0);
    final meAt = target == null || before == null ? null : [before[0] + (target[0] - before[0]) * walk, before[1] + (target[1] - before[1]) * walk];
    final me = Trainers.mine;
    // O nome curto no mapa (sem "City", "Town"...); o completo fica na faixa de baixo.
    Widget label(String text, {double opacity = 1}) => Opacity(
          opacity: opacity,
          child: Text(text.replaceFirst(RegExp(r' (City|Town|Island|Village)$'), ''),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, height: 1, shadows: [
                Shadow(blurRadius: 2),
                Shadow(blurRadius: 2),
                Shadow(offset: Offset(0, 1), blurRadius: 2),
              ])),
        );
    return Container(
      key: const ValueKey('town-map-region'),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(color: const Color(0xFF14396F), border: Border.all(color: const Color(0xFF0F172A), width: 4), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // O mapa ocupa a largura toda (sem faixas dos lados); mais alto que 250, rola na vertical, aberto no treinador.
        LayoutBuilder(builder: (context, outer) {
          final fullH = outer.maxWidth / map.aspect, viewH = min(fullH, 250.0);
          final startY = meAt == null ? 0.0 : (meAt[1] / 100 * fullH - viewH / 2).clamp(0.0, max(0.0, fullH - viewH)).toDouble();
          return SizedBox(
          height: viewH,
          child: SingleChildScrollView(
            key: const ValueKey('town-map-scroll'),
            controller: ScrollController(initialScrollOffset: startY),
            child: SizedBox(
              width: outer.maxWidth,
              height: fullH,
              child: LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth / 100, h = box.maxHeight / 100;
                // Os nomes que esbarrariam em outro vão para cima do círculo.
                final side = <String, String>{};
                final placed = <Rect>[];
                final all = [for (final e in map.cities.entries) (city: e.key, xy: e.value)]..sort((a, b) => a.xy[1].compareTo(b.xy[1]));
                for (final l in all) {
                  final name = l.city.replaceFirst(RegExp(r' (City|Town|Island|Village)$'), '');
                  final lw = name.length * 5.0, x = l.xy[0] * w, y = l.xy[1] * h;
                  final boxes = {
                    'below': Rect.fromLTWH(x - lw / 2, y + 7, lw, 11), 'above': Rect.fromLTWH(x - lw / 2, y - 22, lw, 11),
                    'right': Rect.fromLTWH(x + 10, y - 6, lw, 11), 'left': Rect.fromLTWH(x - 10 - lw, y - 6, lw, 11),
                  };
                  bool hits(Rect r) => r.left < 0 || r.right > box.maxWidth || placed.any((q) => q.overlaps(r));
                  final order = l.xy[1] > 90 ? ['above', 'right', 'left', 'below'] : ['below', 'above', 'right', 'left'];
                  final pick = order.firstWhere((k) => !hits(boxes[k]!), orElse: () => order.first);
                  side[l.city] = pick;
                  placed.add(boxes[pick]!);
                }
                // Onde fica o nome (embaixo, em cima, à direita ou à esquerda do círculo).
                Widget placeLabel(String city, double x, double y, double down, Widget child) {
                  final s = side[city] ?? 'below';
                  if (s == 'right') return Positioned(left: x + 10, top: y - 6, child: child);
                  if (s == 'left') return Positioned(right: box.maxWidth - x + 10, top: y - 6, child: child);
                  return Positioned(left: x - 60, width: 120, top: s == 'above' ? y - 21 : y + down, child: Center(child: child));
                }
                return Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: Image.asset('assets/database/sprites/maps/${map.id}.webp', key: const ValueKey('town-map-image'), fit: BoxFit.fill)),
                  // As vilas e cidades que não são da história (só o círculo).
                  for (final e in map.cities.entries)
                    if (!storyNames.contains(e.key)) ...[
                      Positioned(
                        left: e.value[0] * w - 5,
                        top: e.value[1] * h - 5,
                        child: Container(
                            width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1E3A5F), border: Border.all(color: ring, width: 2))),
                      ),
                      if (!map.art) placeLabel(e.key, e.value[0] * w, e.value[1] * h, 6, label(e.key, opacity: 0.9)),
                    ],
                  // Os nomes das cidades da história.
                  for (var i = 0; i < cities.length; i++)
                    if (map.cities[cities[i].city] != null && !map.art)
                      placeLabel(cities[i].city, map.cities[cities[i].city]![0] * w, map.cities[cities[i].city]![1] * h, 9, label(cities[i].city)),
                  for (var i = 0; i < cities.length; i++)
                    if (map.cities[cities[i].city] != null)
                      Positioned(
                        left: map.cities[cities[i].city]![0] * w - 12,
                        top: map.cities[cities[i].city]![1] * h - 12,
                        width: 24,
                        height: 24,
                        child: GestureDetector(
                          key: ValueKey(done(i) ? 'city-lit' : i == hereIndex ? 'city-here' : 'city-dark'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _regionPick = i),
                          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == hereIndex ? const Color(0xFF38BDF8) : done(i) ? const Color(0xFFFCD34D) : const Color(0xFF1D5E8C),
                                border: Border.all(color: i == shown ? const Color(0xFFFDE047) : (i == hereIndex ? Colors.white : ring), width: 3),
                              ),
                            ),
                            if (marks(i).isNotEmpty) Positioned(top: -12, child: Text(marks(i), style: const TextStyle(fontSize: 11, height: 1))),
                          ]),
                        ),
                      ),
                  // O treinador: onde você está agora.
                  if (meAt != null)
                    Positioned(
                      key: const ValueKey('town-map-me'),
                      left: meAt[0] * w - 20,
                      top: meAt[1] * h - 40,
                      width: 40,
                      height: 40,
                      child: IgnorePointer(
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: me != null ? TrainerSprite(me, height: 36) : const Text('📍', style: TextStyle(fontSize: 18, height: 1)))),
                    ),
                ]);
              }),
            ),
          ),
        );
        }),
        // A faixa de baixo (como no Town Map): o nome da cidade escolhida e o que tem nela.
        if (c != null)
          Container(
            key: const ValueKey('town-map-name'),
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: c.city),
                if (shown == hereIndex) TextSpan(text: ' · ◀ ${tr('você está indo para cá')}') else if (done(shown)) const TextSpan(text: ' · ✔'),
                if (roam != null && c.steps.contains(roam['at']))
                  TextSpan(text: ' · 🐾 ${_roamName(_name(roam['id']))} ${tr('foi visto aqui')}', style: const TextStyle(color: Color(0xFFFCD34D))),
                if (chapters.any((x) => c.steps.contains(x['step'])))
                  TextSpan(text: ' · 🚨 ${_teamNames[plot?['team']] ?? ''}', style: const TextStyle(color: Color(0xFFFCA5A5))),
                if (plot != null && plot['base'] == c.city) TextSpan(text: ' · 🏴 ${tr('Base')}', style: const TextStyle(color: Color(0xFFFCA5A5))),
              ]),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ]),
    );
  }

  /// A ajuda para quem está começando: tipos, clima, efeitos, status, mecânicas e captura. Igual ao site.
  Widget _helpPanel(VoidCallback close) {
    final c = SiteColors.of(context);
    return Column(key: const ValueKey('help-panel'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _overlayHeader('❓ ${tr('Ajuda')}', close),
      for (final (icon, title, text) in _helpTopics)
        Container(
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$icon ${tr(title)}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 13)),
            Text(tr(text), style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ),
      const SizedBox(height: 8),
    ]);
  }

  /// As insígnias da região de agora: uma por líder de ginásio, na cor do tipo dele; as ganhas acesas, as que faltam
  /// apagadas. Igual ao site.
  Widget _badges(FactoryData data, Json run) {
    final leaders = (data.bosses[(run['boss']['region'] as num).toInt()]['leaders'] as List).cast<Map>();
    final step = (run['boss']['step'] as num).toInt();
    final gyms = [for (var k = 0; k < leaders.length; k++) if (leaders[k]['kind'] == 'gym') k];
    if (gyms.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('factory-badges'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: const Color(0x800F172A), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final k in gyms)
          Tooltip(
            message: tr('Insígnia de {0}').replaceAll('{0}', '${leaders[k]['name']}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.rotate(
                angle: pi / 4,
                child: Container(
                  key: ValueKey(k < step ? 'badge-won' : 'badge-missing'),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: k < step ? getColorForType(FactoryRun.leaderType(data, leaders[k])) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: k < step ? Colors.white : Colors.white30),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  /// Um botão do menu, como os da batalha ("▸ LUTAR"); sub: uma linha menor embaixo.
  Widget _menuButton(String label, VoidCallback? onTap, {String? sub, Key? key, bool active = false}) => Material(
        key: key,
        color: active ? (_dark ? const Color(0x24FFFFFF) : const Color(0xFFFEF3C7)) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('▸ $label', style: TextStyle(color: _dlgText, fontWeight: FontWeight.w900)),
                if (sub != null && sub.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(left: 12), child: Text(sub, style: TextStyle(color: _dlgSub, fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        ),
      );

  /// Um botão da linha fixa de ferramentas (BOLSA, TIME, MAPA, AJUDA).
  Widget _toolButton(String icon, String label, VoidCallback onTap, {Key? key, bool active = false}) => Material(
        key: key,
        color: active ? (_dark ? const Color(0x33FFFFFF) : const Color(0xFFFEF3C7)) : (_dark ? const Color(0x14FFFFFF) : const Color(0x0F0F172A)),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$icon $label', maxLines: 1, style: TextStyle(color: _dlgText, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
          ),
        ),
      );

  /// Os botões em duas colunas (ou um embaixo do outro).
  Widget _menuGrid(List<Widget> items, {bool wide = false}) {
    if (wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final i in items) _MenuRow(child: Padding(padding: const EdgeInsets.only(bottom: 4), child: i))]);
    return Column(children: [
      for (var k = 0; k < items.length; k += 2)
        _MenuRow(
          child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Expanded(child: items[k]),
            const SizedBox(width: 4),
            Expanded(child: k + 1 < items.length ? items[k + 1] : const SizedBox()),
          ]),
        )),
    ]);
  }

  /// A lista da loja (dentro da moldura): para quem é a compra e os itens.
  Widget _shopList(BuildContext context, Json run, Json p, FactoryData data) {
    final c = SiteColors.of(context);
    final team = FactoryRun.teamOf(run);
    final target = min(_target, team.length - 1);
    // Compacto (cabe no celular, por cima do campo): o alvo numa fileira de ícones e cada item numa linha.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Para quem é a compra (bolas e itens da Bolsa vão para a Bolsa):'), style: TextStyle(color: c.muted, fontSize: 11)),
      const SizedBox(height: 4),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < team.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                key: ValueKey('target-$i'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _target = i),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: target == i ? const Color(0xFFFBBF24) : Colors.transparent, width: 2),
                  ),
                  child: Opacity(
                    opacity: FactoryRun.hpOf(team[i]) > 0 ? 1 : 0.45,
                    child: PokemonSprite((team[i]['id'] as num).toInt(), shiny: team[i]['shiny'] == true, fill: 0.9),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          Text('${_name(team[target]['id'])} · Nv. ${team[target]['level']}', style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 6),
      for (final id in p['shop'] as List)
        Container(
          key: ValueKey('shop-$id'),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            _itemIcon('$id', 26),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_itemName('$id'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 13)),
                // O que o item faz (inteiro: a linha cresce).
                Text(FactoryRun.shopOwned(run, '$id') ? tr('Você já tem') : _help('$id'), style: TextStyle(color: c.muted, fontSize: 11, height: 1.2)),
              ]),
            ),
            const SizedBox(width: 4),
            FilledButton(
              key: ValueKey('buy-$id'),
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: (run['money'] as num) < FactoryRun.shopPrice(run, '$id') ||
                      FactoryRun.shopOwned(run, '$id') ||
                      ('$id'.startsWith('evo:') && FactoryRun.canEvolveWith(data, team[target], '$id'.substring(4), FactoryRun.regionOf(data, run)).isEmpty)
                  ? null
                  : () => _save(FactoryRun.buyItem(run, '$id', target, data)),
              child: Text('💰${FactoryRun.shopPrice(run, '$id')}', style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ),
    ]);
  }

  /// A caixa de diálogo no tema: escura no tema escuro, branca no claro (igual ao site).
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _dlgText => _dark ? Colors.white : _ink;
  Color get _dlgSub => _dark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
  BoxDecoration _dlgBox() => BoxDecoration(
        color: _dark ? null : Colors.white,
        gradient: _dark ? LinearGradient(colors: [Hud.tint(const Color(0xFF4D4D4D), 0.12), Hud.tint(const Color(0xFF2E2E2E), 0.12)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
        border: Border.all(color: _dark ? const Color(0xFF1A1A1A) : const Color(0xFF334155), width: 3),
        borderRadius: BorderRadius.circular(12),
      );

  /// O título e o "fechar" do que abre por cima do campo.
  Widget _overlayHeader(String title, VoidCallback onClose) => Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(children: [
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          IconButton(tooltip: tr('Fechar'), 
              key: const ValueKey('overlay-close'),
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(4)),
                  child: const Text('✕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
        ]),
      );

  /// O time da corrida para a tela do time (BwParty).
  List<PartySlot> _party(Json run) => [
        for (final m in FactoryRun.teamOf(run))
          PartySlot(
              id: (m['id'] as num).toInt(),
              shiny: m['shiny'] == true,
              name: (m['nick'] as String?) ?? _name(m['id']),
              level: (m['level'] as num).toInt(),
              hp: FactoryRun.hpOf(m).toDouble(),
              sub: m['item'] != null ? _itemName('${m['item']}') : null),
      ];

  /// A moldura: o campo, a barra e a caixa de texto com o menu (igual à batalha). A Bolsa, o time, a loja e a troca
  /// abrem por cima do campo (a mesma tela, como no jogo; dá para jogar com o celular de lado).
  /// Tudo abre no lugar do campo, do tamanho dele (nada muda o tamanho da tela).
  bool get _fullPanel => false;

  /// O que abre por cima (Bolsa, time, loja): aparece subindo de leve (sem surgir de uma vez).
  Widget _panelBox(Widget panel) => TweenAnimationBuilder<double>(
        key: ValueKey('panel-$_panel'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child)),
        child: ClipRRect(
          key: const ValueKey('factory-panel'),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            // O time e o esquecer golpe com o fundo das telas do jogo (verde-azulado), até embaixo.
            decoration: BoxDecoration(color: _panel == 'team' || (_learn != null && _learnStep == 'forget') ? Hud.tint(const Color(0xFF1F6F78)) : SiteColors.of(context).card, border: Border.all(color: _border, width: 4)),
            // O time tem tamanho fixo (as páginas trocam arrastando); o resto rola se não couber.
            // O time e o PC têm tamanho fixo (o PC: o time e a caixa 6×6 do tamanho do campo); o resto rola se não couber.
            child: _panel == 'team' || _panel == 'pc' ? panel : SingleChildScrollView(child: panel),
          ),
        ),
      );

  Widget _frame({required Widget field, Json? run, required List<Widget> text, Widget? menu, List<Widget>? tools}) => Stack(children: [
        _frameColumn(field: field, run: run, text: text, menu: menu, tools: tools),
        if (_framePanel != null && _fullPanel) Positioned.fill(child: _panelBox(_framePanel!)),
      ]);

  // Deitado (DsLayout): o campo com a faixa à esquerda e a tela de baixo à direita, como na batalha.
  // [tools]: BOLSA, TIME, MAPA e AJUDA numa linha fixa no alto da tela de baixo; os caminhos e o resto, nas páginas (◀ ▶).
  Widget _frameColumn({required Widget field, Json? run, required List<Widget> text, Widget? menu, List<Widget>? tools}) => DsLayout(
      top: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // A mesma tela da batalha: o campo (4:3) com a fala dentro dele, embaixo, no mesmo lugar e do mesmo tamanho.
        LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = w * 3 / 4;
          return Stack(children: [
            // Sem corte seco: a tela do lugar troca com um fade (mapa, loja, resultado...).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: field,
            ),
            Positioned(
              left: w * 0.015,
              right: w * 0.015,
              bottom: h * 0.015,
              height: h * 0.21,
              child: _PagedText(
                key: const ValueKey('factory-text'),
                // A moldura comprada na loja de cosméticos (por cima da caixa no tema).
                decoration: (currentFactory()['frame'] is String
                        ? _dlgBox().copyWith(border: Border.all(color: _frameColors[currentFactory()['frame']]?.$1 ?? _border, width: 3))
                        : _dlgBox())
                    .copyWith(borderRadius: BorderRadius.circular(8)),
                style: TextStyle(color: _dlgText, fontSize: 14, height: 1.25, fontWeight: FontWeight.bold),
                children: text,
              ),
            ),
            // A Bolsa e a loja aparecem por cima do campo; o time cobre a tela toda (como a tela do time da batalha).
            if (_framePanel != null && !_fullPanel) Positioned.fill(child: _panelBox(_framePanel!)),
          ]);
        }),
        // A faixa (da altura da faixa da batalha) e a tela de baixo (da altura da tela de baixo da batalha).
        if (run != null)
          _bar(run)
        else
          Container(height: battleBarHeight(context), decoration: BoxDecoration(color: Hud.tint(const Color(0xFF334155)), border: Border.symmetric(vertical: BorderSide(color: _border, width: 4)))),
      ]),
        bottom: Container(
          key: const ValueKey('factory-bottom'),
          height: battleBottomHeight(context),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Hud.base, border: Border.all(color: _border, width: 4), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
          // Os botões ficam sempre nos mesmos lugares (como na batalha): o que não cabe vai para a próxima página (◀ ▶).
          child: menu == null
              ? null
              : Container(
                  padding: const EdgeInsets.all(6),
                  decoration: _dlgBox(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (tools != null) ...[
                      SizedBox(
                        key: const ValueKey('factory-tools'),
                        height: 30,
                        child: Row(children: [
                          for (final (i, t) in tools.indexed) ...[if (i > 0) const SizedBox(width: 4), Expanded(child: t)],
                        ]),
                      ),
                      Divider(height: 9, thickness: 1, color: _dlgSub.withValues(alpha: 0.35)),
                    ],
                    Expanded(child: _PagedMenu(key: ValueKey(('menu', field.key)), color: _dlgText, child: menu is _MenuRow ? menu : _MenuRow(child: menu))),
                  ]),
                ),
        ),
      );

  Widget _small(String text, {Color? color}) => Text(text, style: TextStyle(fontSize: 13, color: color ?? _dlgText));

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    var factory = currentFactory();
    if (factory['run'] == null) {
      _music(null);
      return _over(factory);
    }
    // Conquistas novas (com as moedas) e o Hall da Fama, conforme a corrida anda.
    final (progressed, earned) = FactoryRun.progress(factory, Map<String, dynamic>.from(factory['run'] as Map));
    if (!identical(progressed, factory)) {
      factory = progressed;
      _earned.addAll(earned);
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => saveFactory(progressed)) : null);
    }
    final run = Map<String, dynamic>.from(factory['run'] as Map);
    _music(FactoryRun.mapMusic(data, run));
    final team = FactoryRun.teamOf(run);
    final lead = team.where((m) => FactoryRun.hpOf(m) > 0).firstOrNull ?? team.firstOrNull;
    final p = FactoryRun.pendingOf(run);
    final step = _stepOf(p);
    // Saiu no meio da batalha do andar: voltando, ela continua de onde parou (direto, sem passar pelo mapa).
    if (!_resumeAsked && !widget.busy && p == null && run['encounter'] != null && run['battle'] is Map && (run['battle'] as Map)['floor'] == run['floor']) {
      _resumeAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? widget.onBattle(run) : null);
    }
    // As ferramentas (numa linha fixa da tela de baixo, sempre no mesmo lugar). Igual ao site.
    final tools = [
      _toolButton('🎒', tr('BOLSA'), () => setState(() => _panel = _panel == 'bag' ? null : 'bag'), key: const ValueKey('factory-menu-bag'), active: _panel == 'bag'),
      _toolButton('🧩', tr('TIME'), () => setState(() => _panel = _panel == 'team' ? null : 'team'), key: const ValueKey('factory-menu-team'), active: _panel == 'team'),
      _toolButton('🗺️', tr('MAPA'), () => setState(() {
        _regionPick = null;
        _panel = _panel == 'region' ? null : 'region';
      }),
          key: const ValueKey('factory-menu-region'), active: _panel == 'region'),
      _toolButton('❓', tr('AJUDA'), () => setState(() => _panel = _panel == 'help' ? null : 'help'), key: const ValueKey('factory-menu-help'), active: _panel == 'help'),
    ];
    Widget frame;
    void close() => setState(() => _panel = null);
    _framePanel = _panel == 'region'
        ? _regionMap(run, data, close)
        : _panel == 'help'
            ? _helpPanel(close)
            : _panel == 'bag'
        ? _BagAndItems(run: run, data: data, names: _names, onSave: _save, only: 'bag', onClose: close)
        : _panel == 'team'
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _overlayHeader('🧩 ${tr('Time')}', close),
                Expanded(child: _BagAndItems(run: run, data: data, names: _names, onSave: _save, only: 'team')),
              ])
            : step == 'shop' && _panel == 'buy'
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _overlayHeader('${p?['mart'] == true ? '🎒 ${tr('Vendedor ambulante')}' : p?['store'] != null ? '🏬 ${p!['store']}' : '🛒 Poké Mart'} · 💰${run['money']}', close),
                    Padding(padding: const EdgeInsets.all(8), child: _shopList(context, run, p!, data)),
                  ])
                // A Creche: um lugar da cidade (separado do Poké Mart).
                : p == null && _panel == 'daycare'
                    ? _daycarePanel(run, data, close)
                    : step == 'puzzle'
                    ? _puzzlePanel(run, data)
                    : p == null && _panel == 'album'
                    ? _albumPanel(run, close)
                    : p == null && _panel == 'towntrade' && _townTradeOpen(run)
                    ? _townTradePanel(run, data, close)
                    : p == null && _panel == 'corner' && FactoryRun.cornerOf(data, run) != null
                    ? _cornerPanel(run, data, close)
                    : p == null && (_panel ?? '').startsWith('deleter') && FactoryRun.tutorsOf(data, run).contains('deleter')
                    ? _deleterPanel(run, data, close)
                    // O PC do Centro Pokémon da cidade (como nos jogos).
                    : _panel == 'pc' && FactoryRun.atPc(run)
                        ? _pcPanel(run, close)
                        : null;
    // Esquecer um golpe para aprender o novo: a tela dos 5 golpes por cima de tudo (como nos jogos).
    if (step == 'result' && _learn != null && _learnStep == 'forget') _framePanel = _forgetPanel(run);
    if (step == 'result' && _learn != null && _learn!.isNotEmpty) {
      frame = _learnFrame(run, p!);
    } else if (step == 'result') {
      frame = _resultFrame(run, p!, lead);
    } else if (step == 'choice') {
      frame = _choiceFrame(run, p!, lead, data);
    } else if (step == 'capture') {
      frame = _captureFrame(run, p!, lead, tools);
    } else if (step == 'safari') {
      frame = _safariFrame(run, p!, lead, data);
    } else if (step == 'puzzle') {
      frame = _puzzleFrame(run, data);
    } else if (step == 'trade') {
      frame = _tradeFrame(run, p!, lead, data);
    } else if (step == 'cards') {
      frame = _frame(
        run: run,
        field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-cards'), (w, h) => [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.03, vertical: h * 0.08),
                  child: Row(children: [
                    for (final id in p!['cards'] as List)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            key: ValueKey('card-$id'),
                            onTap: () => _save(FactoryRun.takeCard(run, '$id', data)),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                border: Border.all(color: FactoryRun.relics.containsKey('$id') ? const Color(0xFF4C1D95) : const Color(0xFF1E293B), width: 3),
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: FactoryRun.relics.containsKey('$id') ? const [Color(0xFFC4B5FD), Color(0xFFFAE8FF)] : const [Color(0xFFFDE68A), Colors.white]),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(FactoryRun.relics['$id']?.icon ?? '🃏', style: const TextStyle(fontSize: 26)),
                                if (FactoryRun.relics.containsKey('$id'))
                                  Text(tr('Relíquia').toUpperCase(), style: const TextStyle(color: _ink, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: w * 0.26,
                                      child: Text(FactoryRun.cardText(tr(FactoryRun.cardLabel('$id')), '$id', (run['floor'] as num?)?.toInt()), textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12)),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
        text: [
          Text('🃏 ${tr((p!['cards'] as List).any((c) => FactoryRun.relics.containsKey('$c')) ? 'Escolha uma carta de bônus (ou a relíquia: muda a regra da corrida)' : 'Escolha uma carta de bônus')}')
        ],
      );
    } else if (step == 'shop' && p!['mart'] == true) {
      // Na rota: o vendedor ambulante (vende o mesmo que o Poké Mart), no próprio lugar: o cenário não muda e não tem
      // as bases da batalha. Igual ao site.
      final scene = '${run['scene'] ?? 'grass'}';
      final me = Trainers.mine;
      frame = _frame(
        run: run,
        field: _field(scene, key: const ValueKey('factory-shop'), (w, h) => [
              _far(_farPerson('sd-backpacker', w), w, h, plain: true),
              // Acima da caixa de texto (que fica dentro do campo, como na batalha).
              if (me != null) Positioned(left: w * 0.06, bottom: h * 0.23, child: TrainerSprite(me, height: nearPerson(w))),
              Positioned(
                left: 10,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
                  child: Text('🎒 ${tr('Vendedor ambulante')}', style: const TextStyle(fontWeight: FontWeight.w900, color: _ink, fontSize: 13)),
                ),
              ),
            ]),
        text: [Text('${tr('Um vendedor ambulante! Tenho o mesmo que o Poké Mart. Do que você precisa?')} 💰${run['money']}')],
        menu: _menuGrid([
          _menuButton(tr('COMPRAR'), () => setState(() => _panel = _panel == 'buy' ? null : 'buy'), active: _panel == 'buy', key: const ValueKey('factory-menu-buy')),
          _menuButton(tr('CONTINUAR'), () {
            _panel = null;
            _save({...run, 'pending': {...p, 'shop': null}});
          }, key: const ValueKey('factory-continue')),
        ]),
        tools: tools,
      );
    } else if (step == 'shop') {
      frame = _frame(
        run: run,
        field: _field(FactoryRun.shownScene(run, 'city', data), key: const ValueKey('factory-shop'), (w, h) => [
              Positioned(
                left: 0,
                right: 0,
                bottom: h * 0.22,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _trainerImage('sd-clerk', w * 0.4),
                  _trainerImage('sd-clerkf', w * 0.4),
                ]),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h * 0.26,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFFBBF24), width: 6)),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD97706), Color(0xFF92400E)]),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
                  child: Text(p?['store'] != null ? '🏬 ${p?['store']}' : '🛒 Poké Mart', style: const TextStyle(fontWeight: FontWeight.w900, color: _ink, fontSize: 13)),
                ),
              ),
            ]),
        text: [Text('${tr('Bem-vindo! Do que você precisa?')} 💰${run['money']}')],
        menu: _menuGrid([
          _menuButton(tr('COMPRAR'), () => setState(() => _panel = _panel == 'buy' ? null : 'buy'), active: _panel == 'buy', key: const ValueKey('factory-menu-buy')),
          _menuButton(tr('CONTINUAR'), () {
            _panel = null;
            _save({...run, 'pending': {...p!, 'shop': null}});
          }, key: const ValueKey('factory-continue')),
        ]),
        tools: tools,
      );
    } else if (p == null && run['route'] != null) {
      frame = _mapFrame(run, data, lead, tools);
    } else if (p == null && run['encounter'] != null) {
      frame = _frame(
        run: run,
        field: _field('grass', (w, h) => [if (lead != null) _fieldMon(lead, w, h, back: true)]),
        text: [Text(tr('Lutar no andar {0}').replaceAll('{0}', '${run['floor']}'))],
        menu: _menuButton(tr('LUTAR'), widget.busy || FactoryRun.teamDown(run) ? null : () => widget.onBattle(run), key: const ValueKey('factory-fight')),
      );
    } else {
      frame = _frame(run: run, field: _field('grass', (w, h) => const []), text: const [Text('...')]);
    }
    return Column(key: const ValueKey('factory-screen'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      frame,
      for (final id in _earned)
        Container(
          key: ValueKey('achievement-$id'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0x26F59E0B), borderRadius: BorderRadius.circular(12)),
          child: Text('🏆 ${tr('Conquista: {0}').replaceAll('{0}', tr(FactoryRun.achievements[id]!.label))} (+🪙${FactoryRun.achievements[id]!.coins})',
              style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
        ),
      if (_unlocked != null)
        Container(
          key: const ValueKey('factory-shiny-unlocked'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0x26F59E0B), borderRadius: BorderRadius.circular(12)),
          child: Text('✨ ${tr('{0} shiny liberado para começar as próximas corridas!').replaceAll('{0}', _name(_unlocked))}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
        ),
      Wrap(alignment: WrapAlignment.spaceBetween, children: [
        TextButton(onPressed: widget.onExit, child: Text('← ${tr('Sair (a corrida fica salva)')}')),
        TextButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                content: Text(tr('Desistir da corrida? A pontuação vira moedas.')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Cancelar'))),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Desistir (recebe as moedas)'))),
                ],
              ),
            );
            if (ok == true && mounted) setState(() => saveFactory(FactoryRun.endRun(currentFactory(), run)));
          },
          child: Text(tr('Desistir (recebe as moedas)'), style: TextStyle(color: c.muted)),
        ),
      ]),
    ]);
  }

  /// Acabou (perdeu ou desistiu): o resumo da corrida (andar, capturas, quem
  /// caiu no Nuzlocke, o time e o MVP), as moedas e o recorde. Igual ao site.
  Widget _over(Json factory) {
    final last = factory['last'] as Map?;
    final sum = last?['summary'] as Map?;
    final mvp = sum?['mvp'] as List?;
    final team = [for (final m in (sum?['team'] as List?) ?? const []) m as List];
    return Column(key: const ValueKey('factory-over'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _frame(
        field: _field('over', (w, h) => [
              if (mvp == null)
                const Center(child: Text('🏁', style: TextStyle(fontSize: 64)))
              else ...[
                // Os números da corrida à esquerda, o MVP no meio e o time embaixo.
                Positioned(
                  left: w * 0.03, top: h * 0.04, width: w * 0.4,
                  child: Column(key: const ValueKey('factory-over-summary'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final l in _summaryLines(sum!))
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withAlpha(115), borderRadius: BorderRadius.circular(6)),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(l, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      ),
                  ]),
                ),
                Positioned(
                  left: w * 0.3, width: w * 0.4, top: h * 0.04, height: h * 0.58,
                  child: Column(key: const ValueKey('factory-over-mvp'), children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
                      child: const Text('⭐ MVP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                    Expanded(child: PokemonSprite((mvp[0] as num).toInt(), shiny: mvp[2] == 1, fill: 0.95)),
                  ]),
                ),
                Positioned(
                  left: w * 0.04, right: w * 0.04, bottom: h * 0.04, height: h * 0.3,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (final m in team)
                      Flexible(child: Column(children: [
                        Expanded(child: PokemonSprite((m[0] as num).toInt(), shiny: m[2] == 1, fill: 0.9)),
                        Text('Lv${m[1]}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 3)])),
                      ])),
                  ]),
                ),
              ],
            ]),
        text: [
          Text(tr('A corrida acabou')),
          if (last != null)
            _small('${tr('Andar {0} · +{1} moedas').replaceAll('{0}', '${last['floor']}').replaceAll('{1}', '${last['coins']}')}${last['pieces'] is Map && piecesLine(FactoryRun.piecesOf(last)).isNotEmpty ? ' · ${piecesLine(FactoryRun.piecesOf(last))}' : ''}'),
          _small('${tr('Recorde: andar {0}').replaceAll('{0}', '${factory['best']}')} · 🪙 ${factory['coins']} ${tr('moedas')}', color: const Color(0xFF64748B)),
        ],
        menu: _menuGrid([
          if (sum != null) _menuButton(tr('ENVIAR'), () => _shareSummary(last!), key: const ValueKey('factory-over-share')),
          _menuButton(tr('VOLTAR'), widget.onExit, key: const ValueKey('factory-over-exit')),
        ]),
      ),
    ]);
  }

  /// Capturas, treinadores, insígnias e quem caiu (Nuzlocke). Igual ao site.
  List<String> _summaryLines(Map sum) => [
        '🎯 ${tr('Capturas')}: ${sum['captures'] ?? 0}',
        '⚔️ ${tr('Treinadores')}: ${sum['defeated'] ?? 0}',
        if (((sum['badges'] as num?) ?? 0) > 0) '🏅 ${tr('Insígnias')}: ${sum['badges']}',
        if (sum['fallen'] != null) '🪦 ${tr('Caídos')}: ${sum['fallen']}',
      ];

  /// O resumo em texto, para mandar para alguém. Igual ao site.
  void _shareSummary(Map last) {
    final sum = last['summary'] as Map;
    final mvp = sum['mvp'] as List?;
    final text = [
      '🎲 Pokelike · PocketDex',
      '🏁 ${tr('Andar {0} · +{1} moedas').replaceAll('{0}', '${last['floor']}').replaceAll('{1}', '${last['coins']}')}',
      _summaryLines(sum).join(' · '),
      if (mvp != null) '⭐ MVP: ${_name(mvp[0])} Lv${mvp[1]}',
      if ((sum['team'] as List).isNotEmpty) '🧩 ${[for (final m in sum['team'] as List) _name((m as List)[0])].join(', ')}',
    ].join('\n');
    SharePlus.instance.share(ShareParams(text: text, subject: 'Pokelike · PocketDex'));
  }

  /// O resultado: XP, níveis, dinheiro, Enfermeira Joy, drops, o item do treinador forte, a história; ou o Centro Pokémon e os eventos.
  Widget _resultFrame(Json run, Json p, Map? lead) {
    final team = FactoryRun.teamOf(run);
    final event = p['event'] as Map?;
    final items = [p['drop'], p['reward']].whereType<String>().toList();
    final eventIcon = _eventIcon[event?['kind']] ?? '🎁';
    // A primeira evolução do andar, com a animação dos jogos.
    final evo = (p['levels'] as List? ?? const []).cast<Map>().where((l) => l['evolved'] != null).firstOrNull;
    final evoTo = (evo?['evolved'] as num?)?.toInt();
    final evoFrom = evoTo == null ? null : _data?.evolutions.entries.where((e) => e.value.any((x) => x[0] == evoTo)).firstOrNull?.key;
    final beat = p['beat'] as Map?;
    final mission = p['mission'] as Map?;
    // A Enfermeira Joy só na cidade; na rota, quem cura é alguém do caminho (Pokémon Breeder, Doctor...). Igual ao site.
    final town = FactoryRun.inTown('${run['scene'] ?? 'grass'}');
    final (healerSprite, healerName) = town ? ('sd-nurse', 'Enfermeira Joy') : FactoryRun.healerOf(run);
    return _frame(
      run: run,
      field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-result'), (w, h) => [
            if (p['center'] == true || p['joy'] == true)
              _far(_farPerson(healerSprite, w), w, h)
            else if (items.isNotEmpty)
              _far(_itemIcon(items.first, w * 0.16), w, h)
            else if (event != null)
              _far(Text(eventIcon, style: TextStyle(fontSize: w * 0.12)), w, h),
            if (lead != null) _fieldMon(lead, w, h, back: true),
            if (evoTo != null && evoFrom != null)
              Positioned.fill(child: _EvolutionFx(from: evoFrom, to: evoTo)),
          ]),
      text: [
        if (evoTo != null && evoFrom != null)
          Text('✨ ${tr('{0} evoluiu para {1}!').replaceAll('{0}', _name(evoFrom)).replaceAll('{1}', _name(evoTo))}',
              key: const ValueKey('factory-evolved'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
        if (p['center'] == true)
          Text(town ? '🏥 ${tr('Centro Pokémon: o seu time foi curado!')}' : '⛺ ${tr('{0} cuidou do seu time: todos curados!').replaceAll('{0}', healerName)}',
              key: const ValueKey('factory-center'))
        else if (event != null)
          Text(
              tr(_eventText['${event['kind']}'] ?? '')
                  .replaceAll('{0}', const ['money', 'betWon', 'betLost'].contains(event['kind']) ? '${event['money']}' : _itemName('${event['item'] ?? ''}'))
                  .replaceAll('{1}', '${event['kind'] == 'secretFound' ? event['money'] : event['count'] ?? ''}'),
              key: const ValueKey('factory-event'))
        else ...[
          Text('🏆 ${tr('Andar vencido!')} +${p['exp']} XP · +💰${p['money']}'),
          for (final l in (p['levels'] as List? ?? const []))
            if (l['friend'] == true)
              _small('💞 ${_name(l['evolved'])}: ${tr('evoluiu pela amizade!')}')
            else if ((l['index'] as num).toInt() < team.length)
              _small('${_name(team[(l['index'] as num).toInt()]['id'])}: Nv. ${l['from']} → ${l['to']}${l['evolved'] != null ? ' · ${tr('evoluiu!')}' : ''}'),
        ],
        if (p['shed'] == true) Text('🐚 ${tr('Shedinja apareceu na vaga do time!')}', key: const ValueKey('factory-shed'), style: const TextStyle(fontSize: 13)),
        for (final e in ((p['pieces'] as Map?) ?? const {}).entries)
          Text('${pieceInfo['${e.key}']!.$1} ${tr('+{0} {1} (para a árvore, no fim da corrida)').replaceAll('{0}', '${e.value}').replaceAll('{1}', pieceInfo['${e.key}']!.$2)}',
              key: ValueKey('factory-pieces-drop-${e.key}'), style: const TextStyle(fontSize: 13)),
        for (final x in (p['picked'] as List? ?? const []))
          Text(x['follow'] == true
              ? '🐾 ${tr('{0}, que segue você, achou {1}!').replaceAll('{0}', _name(x['id'])).replaceAll('{1}', _itemName('${x['item']}'))}'
              : '🎒 ${tr('{0} achou {1} (Pickup)!').replaceAll('{0}', _name(x['id'])).replaceAll('{1}', _itemName('${x['item']}'))}',
              key: const ValueKey('factory-pickup'), style: const TextStyle(fontSize: 13)),
        for (final id in (p['lost'] as List? ?? const []))
          Text('🕯️ ${tr('Nuzlocke: {0} desmaiou e foi embora.').replaceAll('{0}', _name(id))}',
              key: const ValueKey('factory-lost'), style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
        if (p['joy'] == true)
          Text('💗 ${town ? tr('A Enfermeira Joy apareceu e curou o time todo!') : tr('{0} apareceu e curou o time todo!').replaceAll('{0}', healerName)}',
              key: const ValueKey('factory-joy'), style: const TextStyle(fontSize: 13)),
        for (final id in items) ...[
          Text('🎁 ${tr('Ganhou {0}!').replaceAll('{0}', _itemName(id))}', key: ValueKey('factory-drop-$id'), style: const TextStyle(fontSize: 13)),
          if (_help(id).isNotEmpty) Text(_help(id), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
        ],
        if (beat != null)
          Text(
              '💬 ${beat['name']}: ${tr(beat['kind'] == 'rival' ? _rivalBeat[min(_rivalBeat.length, ((run['rivalWins'] as num?) ?? 1).toInt()) - 1] : _beatLines[beat['kind']] ?? _beatLines['gym']!)}',
              key: const ValueKey('factory-beat-line'),
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
        if (p['fled'] != null)
          Text('🐾 ${tr('{0} fugiu! Ele continua andando pela região (com o HP que ficou): veja no mapa onde foi visto.').replaceAll('{0}', _name(p['fled']))}',
              key: const ValueKey('factory-fled'), style: const TextStyle(fontSize: 13)),
        if (p['plot'] != null)
          Text(
              '🚨 ${tr('Você atrapalhou o plano da {0} ({1})! Ganhou {2}; o chefe da equipe vai estar mais fraco.').replaceAll('{0}', _teamNames[p['plot']['team']] ?? 'Equipe Rocket').replaceAll('{1}', '${p['plot']['chapter']}').replaceAll('{2}', _itemName('${p['plot']['item']}'))}',
              key: const ValueKey('factory-plot'),
              style: const TextStyle(fontSize: 13)),
        if (p['flawless'] != null)
          Text('🏆 ${tr('Liga sem nenhum desmaio! Prêmio: {0}.').replaceAll('{0}', _itemName('${p['flawless']}'))}',
              key: const ValueKey('factory-flawless'), style: const TextStyle(fontSize: 13)),
        if (p['dowsed'] != null)
          Text('📡 ${tr('Você achou {0} escondido no caminho!').replaceAll('{0}', _itemName('${p['dowsed']}'))}',
              key: const ValueKey('factory-dowsed'), style: const TextStyle(fontSize: 13)),
        if (p['key'] != null)
          Text('${_keyInfo[p['key']]?.$1 ?? '🔑'} ${tr('Você recebeu {0}!').replaceAll('{0}', FactoryRun.keyItems[p['key']] ?? '${p['key']}')} ${tr(_keyInfo[p['key']]?.$2 ?? '')}',
              key: const ValueKey('factory-key'), style: const TextStyle(fontSize: 13, color: Color(0xFFD97706))),
        if (p['placeReward'] != null)
          Text('🎁 ${tr('Pela ajuda, te deram {0}!').replaceAll('{0}', _itemName('${p['placeReward']}'))}',
              key: const ValueKey('factory-place-reward'), style: const TextStyle(fontSize: 13, color: Color(0xFFD97706))),
        if (p['hm'] != null && _hmInfo[p['hm']] != null)
          Text(
              '${_hmInfo[p['hm']]!.$2} ${tr('Com a insígnia, você ganhou a MO {0}!').replaceAll('{0}', _hmInfo[p['hm']]!.$1)} ${tr(_hmInfo[p['hm']]!.$3)}',
              key: const ValueKey('factory-hm'),
              style: const TextStyle(fontSize: 13, color: Color(0xFFD97706))),
        if (mission != null)
          Text('📋 ${tr('Missão cumprida: {0}!').replaceAll('{0}', _mission(mission))} +💰${mission['money']} · 🎁 ${_itemName('${mission['item']}')}',
              key: const ValueKey('factory-mission-done'), style: const TextStyle(fontSize: 13, color: Color(0xFFD97706))),
        if (p['story'] != null)
          for (final line in '${p['story']}'.split('\n\n')) Text('📖 $line', key: const ValueKey('factory-story-end'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
      menu: FactoryRun.atPc(run) && _panel == 'pc'
          // O PC aberto (como no site): só o FECHAR embaixo.
          ? _menuButton(tr('FECHAR'), () => setState(() => _panel = null), key: const ValueKey('factory-pc-close'))
          : FactoryRun.atPc(run)
              ? _menuGrid([
                  _menuButton('💻 ${tr('PC')}', () => setState(() => _panel = 'pc'), key: const ValueKey('factory-pc-open')),
                  _menuButton(tr('CONTINUAR'), () {
                    setState(() => _panel = null);
                    _afterResult(run, p);
                  }, key: const ValueKey('factory-continue')),
                ])
              : FactoryRun.photoNow(run) != null
                  ? _menuGrid([_menuButton(tr('CONTINUAR'), () => _afterResult(run, p), key: const ValueKey('factory-continue')), _photoButton(run)])
                  : _menuButton(tr('CONTINUAR'), () => _afterResult(run, p), key: const ValueKey('factory-continue')),
    );
  }

  /// O PC (como nos jogos): o time à esquerda e a caixa 6×6 à direita ([_PcPanel]). Igual ao site.
  Widget _pcPanel(Json run, VoidCallback close) =>
      _PcPanel(key: const ValueKey('factory-pc'), run: run, data: _data!, nameOf: (id) => _name(id), onSave: (next) => _save(next));



  /// Os golpes que o time aprende subindo de nível (como nos jogos), um de cada vez: (posição no time, golpe, entrou sozinho).
  List<(int, String, bool)>? _learn;

  /// 'ask' (quer aprender?), 'forget' (a tela dos 5 golpes); [_learnMsg]: o que aconteceu (com CONTINUAR).
  String _learnStep = 'ask';
  String? _learnMsg;
  int? _forgetPick;
  Map<String, Map<String, dynamic>> _moveData = const {};

  /// Depois do resultado do andar: os golpes novos de quem subiu de nível. Com vaga, aprende sozinho; com 4, pergunta.
  /// Os golpes de quem subiu ficam guardados (não mudam mais sozinhos).
  Future<void> _afterResult(Json run, Json p) async {
    _moveData = await LocalDatabase.instance.movesByName();
    var next = run;
    final queue = <(int, String, bool)>[];
    for (final l in (p['levels'] as List? ?? const []).cast<Map>()) {
      if (l['friend'] == true) continue;
      final i = (l['index'] as num).toInt();
      final team = FactoryRun.teamOf(next);
      if (i >= team.length) continue;
      final mon = team[i];
      final id = (mon['id'] as num).toInt();
      final from = (l['from'] as num).toInt(), to = (l['to'] as num).toInt();
      final row = await LocalDatabase.instance.pokemonRow(id);
      if (row == null) continue;
      final own = [for (final m in (mon['moves'] as List?) ?? const []) '$m'];
      var current = own.isNotEmpty ? own : await _movesFor(id, from);
      for (final move in FactoryRun.movesLearnedBetween(row['moves'] as List, from, to, _moveData)) {
        if (current.contains(move)) continue;
        if (current.length < 4) {
          current = [...current, move];
          queue.add((i, move, true));
        } else {
          queue.add((i, move, false));
        }
      }
      next = {...next, 'team': [for (var k = 0; k < team.length; k++) k == i ? {...team[k], 'moves': current} : team[k]]};
    }
    if (!mounted) return;
    if (queue.isEmpty) return _save({...next, 'pending': {...p, 'seen': true}});
    _learn = queue;
    _learnStep = 'ask';
    _learnMsg = null;
    _save(next);
  }

  /// O próximo golpe da fila (sem mais nenhum, segue o andar).
  void _nextLearn(Json run, Json p) {
    _learn!.removeAt(0);
    _learnStep = 'ask';
    _learnMsg = null;
    _forgetPick = null;
    if (_learn!.isEmpty) {
      _learn = null;
      _save({...run, 'pending': {...p, 'seen': true}});
    } else {
      setState(() {});
    }
  }

  /// "Fulano quer aprender X": aprendeu sozinho (tinha vaga), ou a pergunta (SIM abre a tela dos 5 golpes).
  Widget _learnFrame(Json run, Json p) {
    final (i, move, auto) = _learn!.first;
    final mon = FactoryRun.teamOf(run)[i];
    final name = _name(mon['id']);
    final mv = prettySlug(move);
    final msg = _learnMsg ?? (auto ? '✨ ${tr('{0} aprendeu {1}!').replaceAll('{0}', name).replaceAll('{1}', mv)}' : null);
    return _frame(
      run: run,
      field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-learn'), (w, h) => [_fieldMon(mon, w, h, back: true)]),
      text: [
        Text(msg ?? tr('{0} quer aprender {1}, mas já sabe 4 golpes. Esquecer um?').replaceAll('{0}', name).replaceAll('{1}', mv),
            key: const ValueKey('factory-learn-text')),
      ],
      menu: msg != null
          ? _menuButton(tr('CONTINUAR'), () => _nextLearn(run, p), key: const ValueKey('learn-continue'))
          : _learnStep == 'forget'
              // Na tela dos 5 golpes: confirmar o tocado (ESQUECER ou NÃO APRENDER) e VOLTAR, nos botões de baixo.
              ? _menuGrid([
                  _menuButton(
                      _forgetPick == null
                          ? tr('Escolha um golpe')
                          : _forgetPick == FactoryRun.teamOf(run)[i]['moves'].length
                              ? tr('NÃO APRENDER')
                              : '${tr('ESQUECER')} ${prettySlug('${(FactoryRun.teamOf(run)[i]['moves'] as List)[_forgetPick!]}')}',
                      _forgetPick == null ? null : () => _confirmForget(run),
                      key: const ValueKey('forget-confirm')),
                  _menuButton(tr('VOLTAR'), () => setState(() {
                        _learnStep = 'ask';
                        _forgetPick = null;
                      }), key: const ValueKey('forget-back')),
                ])
          : _menuGrid([
              _menuButton(tr('SIM'), () => setState(() => _learnStep = 'forget'), key: const ValueKey('learn-yes')),
              _menuButton(tr('NÃO'), () => setState(() => _learnMsg = tr('{0} não aprendeu {1}.').replaceAll('{0}', name).replaceAll('{1}', mv)),
                  key: const ValueKey('learn-no')),
            ]),
    );
  }

  /// Confirma o golpe tocado na tela dos 5 golpes: esquece ele e aprende o novo (o novo tocado: não aprende).
  void _confirmForget(Json run) {
    final (i, move, _) = _learn!.first;
    final mon = FactoryRun.teamOf(run)[i];
    final name = _name(mon['id']);
    final current = [for (final m in (mon['moves'] as List?) ?? const []) '$m'];
    final pick = _forgetPick!;
    final mv = prettySlug(move);
    _learnStep = 'ask';
    _forgetPick = null;
    if (pick >= current.length) {
      setState(() => _learnMsg = tr('{0} não aprendeu {1}.').replaceAll('{0}', name).replaceAll('{1}', mv));
      return;
    }
    _learnMsg = tr('1, 2 e... Pronto! {0} esqueceu {1} e aprendeu {2}!').replaceAll('{0}', name).replaceAll('{1}', prettySlug(current[pick])).replaceAll('{2}', mv);
    _save(FactoryRun.learnMove(run, i, move, current, pick));
  }

  /// Esquecer um golpe (como nos jogos): o Pokémon à esquerda e os 5 golpes à direita (os 4 de agora e o novo), no lugar
  /// do campo (como a Bolsa); toque num para ver o que ele faz e confirme embaixo. Escolher o novo é não aprender.
  Widget _forgetPanel(Json run) {
    final (i, move, _) = _learn!.first;
    final mon = FactoryRun.teamOf(run)[i];
    final id = (mon['id'] as num).toInt();
    final name = _name(id);
    final current = [for (final m in (mon['moves'] as List?) ?? const []) '$m'];
    final five = [...current, move];
    final types = [for (final t in (_data?.species[id]?.elementAtOrNull(4) as List?) ?? const []) '$t'];
    const ink = Color(0xFF0F172A);
    Widget tile(int k) {
      final slug = five[k];
      final m = _moveData[slug] ?? const {};
      final isNew = k == current.length;
      final picked = _forgetPick == k;
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Material(
          key: ValueKey('forget-$k'),
          color: picked ? const Color(0xFFFDBA74) : isNew ? const Color(0xFFFEF3C7) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _forgetPick = k),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
              child: Row(children: [
                if (m['type'] != null) TypeChip('${m['type']}'),
                const SizedBox(width: 6),
                // Nome do golpe como no jogo (não traduz).
                Expanded(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(prettySlug(slug), maxLines: 1, style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w900)))),
                if (isNew)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(4)),
                    child: Text(tr('NOVO'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                Text('PP ${m['pp'] ?? '—'}', style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      );
    }

    final pick = _forgetPick;
    final pm = pick == null ? null : _moveData[five[pick]];
    return Container(
      key: const ValueKey('forget-panel'),
      color: Hud.tint(const Color(0xFF1F6F78)),
      padding: const EdgeInsets.all(6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF0F3D44), border: Border.all(color: const Color(0xFF0B2A2F), width: 2), borderRadius: BorderRadius.circular(8)),
          // O golpe tocado: poder, precisão e categoria no lugar do título.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
                pm == null
                    ? tr('Esquecer qual golpe?')
                    : '${prettySlug(five[pick!])} · ${tr('Poder')} ${pm['power'] ?? '—'} · ${tr('Precisão')} ${pm['accuracy'] ?? '—'} · ${tr(_categoryLabel['${pm['damage_class']}'] ?? '')}',
                key: const ValueKey('forget-title'),
                maxLines: 1,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // O Pokémon à esquerda (como nos jogos).
          SizedBox(
            width: 84,
            child: Column(children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: const Color(0xFFBDE7F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF0F3D5C), width: 2)),
                child: PokemonSprite(id, shiny: mon['shiny'] == true, fill: 0.85),
              ),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text(name, maxLines: 1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              Text('Lv${mon['level']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 3, runSpacing: 3, alignment: WrapAlignment.center, children: [for (final t in types) TypeChip(t)]),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var k = 0; k < five.length; k++) tile(k)])),
        ]),
      ]),
    );
  }

  /// Capturou na batalha: entra no time (com o time cheio, escolhe quem sai ou solta).
  /// Uma escolha na rota: aceitar ou seguir o caminho. Igual ao site.
  Widget _choiceFrame(Json run, Json p, Map? lead, FactoryData data) {
    final choice = p['choice'] as Map;
    final info = _choiceInfo['${choice['kind']}'] ?? _choiceInfo['help']!;
    final poor = const ['help', 'merchant', 'bet'].contains(choice['kind']) && (run['money'] as num) < ((choice['cost'] as num?) ?? 0);
    final mon = choice['mon'] as Map?;
    final scene = '${run['scene'] ?? 'grass'}';
    void decide(bool accept) {
      final next = FactoryRun.resolveChoice(run, data, accept);
      if (next['encounter'] != null) {
        setState(() => saveFactory({...currentFactory(), 'run': next}));
        widget.onBattle(next);
      } else {
        _save(next);
      }
    }

    return _frame(
      run: run,
      field: _field(scene, key: const ValueKey('factory-choice'), (w, h) => [
            if (mon != null) _fieldMon(mon, w, h) else _far(Text(info.$1, style: TextStyle(fontSize: w * 0.12)), w, h),
            if (lead != null) _fieldMon(lead, w, h, back: true),
          ]),
      text: [
        Text(
            '${info.$1} ${tr(info.$2).replaceAll('{0}', '${choice['cost'] ?? ''}').replaceAll('{1}', mon == null ? '' : '${mon['shiny'] == true ? '✨ ' : ''}${_name(mon['id'])}').replaceAll('{2}', choice['item'] == null ? '' : _itemName('${choice['item']}'))}',
            key: ValueKey('factory-choice-${choice['kind']}')),
        if (choice['kind'] == 'secret' && run['flash'] != true) _small(tr('Está escuro lá dentro: sem Flash, pode não achar nada.'), color: _dlgSub),
        if (poor) _small(tr('Você não tem dinheiro suficiente.'), color: const Color(0xFFDC2626)),
      ],
      menu: _menuGrid([
        _menuButton(tr(info.$3), widget.busy || poor || (choice['kind'] == 'follow' && FactoryRun.teamDown(run)) ? null : () => decide(true),
            key: const ValueKey('choice-yes')),
        _menuButton(tr(info.$4), widget.busy ? null : () => decide(false), key: const ValueKey('choice-no')),
      ]),
    );
  }

  bool _townTradeOpen(Json run) {
    final trade = (run['town'] as Map?)?['trade'] as Map?;
    return trade != null && trade['done'] != true;
  }

  /// A troca da cidade: quem você dá ao morador (só serve quem ele pediu). Igual ao site.
  Widget _townTradePanel(Json run, FactoryData data, VoidCallback close) {
    final trade = (run['town'] as Map)['trade'] as Map;
    final ok = FactoryRun.townTradeable(run, data);
    return BwParty(
      testKey: 'towntrade',
      title: tr('Quem você dá em troca do {0}?').replaceAll('{0}', _name(trade['give'])),
      team: [for (final m in _party(run)) PartySlot(id: m.id, shiny: m.shiny, name: m.name, level: m.level, hp: m.hp, sub: m.sub)],
      disabled: (i) => !ok.contains(i),
      onPick: (i) {
        _panel = null;
        _save(FactoryRun.townTrade(run, i, data));
      },
      onCancel: close,
    );
  }

  /// O botão da foto (o capturado ou a vitória sobre um chefe). Igual ao site.
  Widget _photoButton(Json run) {
    final shot = FactoryRun.takePhoto(run, FactoryRun.photoNow(run));
    return _menuButton('📸 ${tr(shot != null ? 'FOTO' : 'FOTO GUARDADA')}', shot == null ? null : () => _save(shot), key: const ValueKey('factory-photo'));
  }

  /// As ações da rota (rodada 14), numa grade de duas colunas. Igual ao site.
  List<Widget> _routeActions(Json run, FactoryData data, bool meeting, bool town) {
    final fish = meeting ? null : FactoryRun.fishPath(run, data);
    final shake = meeting ? null : FactoryRun.headbuttPath(run);
    final honey = meeting ? null : FactoryRun.slatherHoney(run);
    final licked = meeting ? null : FactoryRun.honeyPath(run);
    final plant = meeting || town ? null : FactoryRun.plantBerry(run, data);
    final pick = FactoryRun.berryReady(run) ? FactoryRun.harvestBerry(run) : null;
    final bike = meeting ? null : FactoryRun.bikePath(run, data);
    final photos = (run['photos'] as List?) ?? const [];
    Widget act(String key, String label, Json next) => _menuButton(label, widget.busy ? null : () => _save(next), key: ValueKey(key));
    final acts = [
      if (fish != null) act('factory-fish', '🎣 ${tr('PESCAR')}', fish),
      if (shake != null) act('factory-headbutt', '🌳 ${tr('SACUDIR A ÁRVORE')}', shake),
      if (honey != null) act('factory-honey-put', '🍯 ${tr('PASSAR MEL')}', honey),
      if (licked != null) act('factory-honey-go', '🍯 ${tr('VER O MEL')}', licked),
      if (plant != null) act('factory-berry-plant', '🌱 ${tr('PLANTAR FRUTA')}', plant),
      if (pick != null) act('factory-berry-pick', '🍓 ${tr('COLHER {0}× {1}').replaceAll('{0}', '${run['berry']['count']}').replaceAll('{1}', _itemName('${run['berry']['item']}'))}', pick),
      if (bike != null) act('factory-bike', '🚲 Bicycle', bike),
      if (photos.isNotEmpty)
        _menuButton('📷 ${tr('ÁLBUM')} (${photos.length})', widget.busy ? null : () => setState(() => _panel = _panel == 'album' ? null : 'album'),
            active: _panel == 'album', key: const ValueKey('factory-album')),
    ];
    return acts.isEmpty ? const [] : [KeyedSubtree(key: const ValueKey('route-actions'), child: _menuGrid(acts))];
  }

  /// O álbum da corrida: cada foto com o lugar, o Pokémon e o andar. Igual ao site.
  Widget _albumPanel(Json run, VoidCallback close) {
    final photos = (run['photos'] as List?) ?? const [];
    return Column(key: const ValueKey('album'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _overlayHeader('📷 ${tr('Álbum da corrida')}', close),
      Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.9,
          children: [
            for (var k = 0; k < photos.length; k++)
              Container(
                key: ValueKey('photo-$k'),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: Stack(fit: StackFit.expand, children: [
                      BattleBackdrop(scene: battleScene('${photos[k]['scene'] ?? 'grass'}', null)),
                      if (photos[k]['id'] != null)
                        Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(heightFactor: 0.8, child: PokemonSprite((photos[k]['id'] as num).toInt(), shiny: photos[k]['shiny'] == true, fill: 0.9))),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    child: Text(
                        '${photos[k]['shiny'] == true ? '✨ ' : ''}${photos[k]['name'] ?? _name(photos[k]['id'])} · ${tr('Andar {0}').replaceAll('{0}', '${photos[k]['floor']}')}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _ink, height: 1.1)),
                  ),
                ]),
              ),
          ],
        ),
      ),
    ]);
  }

  /// O desafio do ginásio: o cenário do ginásio, o nome do desafio e os botões (memorizei, desistir, continuar). Igual ao site.
  Widget _puzzleFrame(Json run, FactoryData data) {
    final v = FactoryRun.puzzleView(run)!;
    final info = _puzzleInfo[v['type']]!;
    return _frame(
      field: _field('gym-${v['type']}', key: const ValueKey('factory-puzzle'), (w, h) => const []),
      run: run,
      text: [Text('🧩 ${tr(info.$1)}', style: const TextStyle(fontWeight: FontWeight.w900))],
      menu: v['done'] == true
          ? _menuButton(tr('CONTINUAR'), () => _save(FactoryRun.finishPuzzle(run)), key: const ValueKey('factory-continue'))
          : _menuGrid([
              if (v['kind'] == 'memory' && v['seq'] != null) _menuButton(tr('MEMORIZEI'), () => _save(FactoryRun.puzzleAct(run, data, -1)), key: const ValueKey('puzzle-ready')),
              _menuButton(tr('DESISTIR DO DESAFIO'), () => _save(FactoryRun.finishPuzzle(run)), key: const ValueKey('puzzle-quit')),
            ]),
    );
  }

  /// As casas do desafio (por cima do campo): o que fazer, o placar, a pergunta e a grade de botões. Igual ao site.
  Widget _puzzlePanel(Json run, FactoryData data) {
    final v = FactoryRun.puzzleView(run)!;
    final c = SiteColors.of(context);
    final type = '${v['type']}';
    final info = _puzzleInfo[type]!;
    final skin = {..._puzzleCell, ...?_puzzleSkin[type]};
    final symbols = _puzzleSymbols[type] ?? _puzzleSymbols['psychic']!;
    final done = v['done'] == true, kind = v['kind'];
    final prompt = v['prompt'] as Map?;
    final seq = v['seq'] as List?;
    final cells = v['cells'] as List;
    final cols = (v['cols'] as num).toInt();
    final status = done
        ? (v['won'] == true
            ? '🎉 ${tr('Você venceu o desafio! O time do líder vem {0} níveis abaixo.').replaceAll('{0}', '${FactoryRun.gymEdgeLevels}')}'
            : '💥 ${tr('Não foi desta vez: o líder luta com tudo.')}')
        : kind == 'quiz' || kind == 'silhouette'
            ? tr('Pergunta {0} de {1} · acertos: {2}').replaceAll('{0}', '${min((v['total'] as num).toInt(), (v['at'] as num).toInt() + 1)}').replaceAll('{1}', '${v['total']}').replaceAll('{2}', '${v['right']}')
            : kind == 'memory'
                ? (seq != null ? tr('Memorize a ordem.') : tr('Repita a ordem: {0} de {1}.').replaceAll('{0}', '${v['at']}').replaceAll('{1}', '${v['total']}'))
                : kind == 'tiles'
                    ? tr('Faltam {0}.').replaceAll('{0}', '${v['left']}')
                    : kind == 'switches'
                        ? tr('Tentativas: {0} · achados: {1} de 2').replaceAll('{0}', '${v['left']}').replaceAll('{1}', '${v['found']}')
                        : kind == 'maze' && v['hidden'] == true
                            ? tr('Batidas que ainda aguenta: {0}').replaceAll('{0}', '${v['left']}')
                            : tr('Jogadas: {0}').replaceAll('{0}', '${v['left']}');
    final question = prompt == null
        ? null
        : tr(_puzzleQuestion[prompt['q']]!).replaceAll('{0}', prompt['q'] == 'typeOf' ? _name(prompt['mon']) : tr(_typePt[prompt['type']] ?? ''));
    Widget cell(int i) {
      final x = cells[i] as Map;
      final code = '${x['c']}';
      final off = widget.busy || done || (kind == 'memory' && seq != null) || code == 'num' || code == 'hit';
      final (bg, border) = switch (code) {
        'me' => (const Color(0xFFFEF3C7), const Color(0xFFFBBF24)),
        'goal' => (const Color(0xFFD1FAE5), const Color(0xFF34D399)),
        'wall' || 'rock' => (const Color(0xFF475569), const Color(0xFF64748B)),
        'done' => (const Color(0xFFBAE6FD), const Color(0xFF7DD3FC)),
        _ => (const Color(0xF2FFFFFF), const Color(0x99FFFFFF)),
      };
      final Widget child = switch (code) {
        'type' => Text(tr(_typePt[x['type']] ?? ''), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ink)),
        'mon' => Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (kind != 'silhouette') SizedBox(width: 26, height: 26, child: PokemonSprite((x['mon'] as num).toInt(), fill: 0.9)),
            Flexible(child: Text(_name(x['mon']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _ink))),
          ]),
        'num' => Text('${x['n']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _ink)),
        'sym' => Text(symbols[(x['n'] as num).toInt()], style: const TextStyle(fontSize: 22)),
        _ => Text(skin[code] ?? '', style: const TextStyle(fontSize: 18)),
      };
      return Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: border, width: 2)),
        child: InkWell(
          key: ValueKey('puzzle-cell-$i'),
          borderRadius: BorderRadius.circular(8),
          onTap: off ? null : () => _save(FactoryRun.puzzleAct(run, data, i)),
          child: Container(constraints: BoxConstraints(minHeight: cells.length > 16 ? 26 : 36), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), child: child),
        ),
      );
    }

    return Padding(
      key: const ValueKey('puzzle'),
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Text('🧩 ${tr(info.$1)}', key: const ValueKey('puzzle-title'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.text)),
        Text(tr(info.$2), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.muted)),
        Text(status, key: const ValueKey('puzzle-status'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
        if (question != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (prompt!['q'] == 'who')
                SizedBox(
                  key: const ValueKey('puzzle-silhouette'),
                  width: 64,
                  height: 64,
                  child: done
                      ? PokemonSprite((prompt['mon'] as num).toInt(), fill: 0.9)
                      : ColorFiltered(colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn), child: PokemonSprite((prompt['mon'] as num).toInt(), fill: 0.9)),
                ),
              if (prompt['q'] == 'typeOf') SizedBox(width: 48, height: 48, child: PokemonSprite((prompt['mon'] as num).toInt(), fill: 0.9)),
              Flexible(child: Text(question, key: const ValueKey('puzzle-question'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c.text))),
            ]),
          ),
        if (kind == 'memory')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(seq != null ? [for (final n in seq) symbols[(n as num).toInt()]].join(' ') : List.filled((v['total'] as num).toInt(), '❔').join(' '),
                key: const ValueKey('puzzle-seq'), style: const TextStyle(fontSize: 24, letterSpacing: 2)),
          ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var r = 0; r * cols < cells.length; r++)
              Padding(
                padding: EdgeInsets.only(bottom: cells.length > 16 ? 3 : 4),
                child: Row(children: [
                  for (var k = 0; k < cols; k++) ...[
                    if (k > 0) const SizedBox(width: 4),
                    Expanded(child: r * cols + k < cells.length ? cell(r * cols + k) : const SizedBox()),
                  ],
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  /// O Game Corner: fichas, caça-níqueis e os prêmios de lá. Igual ao site.
  Widget _cornerPanel(Json run, FactoryData data, VoidCallback close) {
    final corner = FactoryRun.cornerOf(data, run)!;
    final c = SiteColors.of(context);
    final slots = run['slots'] as Map?;
    final reels = (slots?['reels'] as List?) ?? const ['?', '?', '?'];
    final won = ((slots?['won'] as num?) ?? 0).toInt();
    final buy = FactoryRun.buyCoins(run, data), spin = FactoryRun.spinSlots(run, data);
    return Column(key: const ValueKey('corner'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _overlayHeader('🎰 ${corner['name']}', close),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('🪙 ${run['gcCoins'] ?? 0} · 💰 ${run['money']}', key: const ValueKey('corner-coins'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.text)),
          const SizedBox(height: 4),
          Row(key: const ValueKey('corner-reels'), mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final r in reels)
              Container(
                width: 56,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFFBBF24), width: 2), borderRadius: BorderRadius.circular(8)),
                child: Text('$r', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
              slots == null
                  ? tr('Três iguais pagam: 7 paga 100, BAR paga 30, 🍒 paga 6.')
                  : won > 0
                      ? '🎉 ${tr('Ganhou {0} fichas!').replaceAll('{0}', '$won')}'
                      : tr('Não foi desta vez.'),
              key: const ValueKey('corner-result'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.text)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: FilledButton(
                key: const ValueKey('corner-buy'),
                onPressed: widget.busy || buy == null ? null : () => _save(buy),
                child: Text(tr('{0} fichas por 💰{1}').replaceAll('{0}', '${FactoryRun.cornerPack}').replaceAll('{1}', '${FactoryRun.cornerPackPrice}'), textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const ValueKey('corner-spin'),
                onPressed: widget.busy || spin == null ? null : () => _save(spin),
                child: Text(tr('JOGAR ({0} fichas)').replaceAll('{0}', '${FactoryRun.cornerSpin}'), textAlign: TextAlign.center),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(tr('Os prêmios daqui (as fichas ficam com você a corrida toda):'), style: TextStyle(fontSize: 12, color: c.muted)),
          for (final row in corner['prizes'] as List)
            Builder(builder: (context) {
              final Object prize = (row as List)[0] as Object;
              final got = FactoryRun.cornerPrize(run, data, prize);
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  if (prize is num) SizedBox(width: 36, height: 36, child: PokemonSprite(prize.toInt(), fill: 0.9)) else const Text('💿', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(prize is num ? _name(prize) : _itemName('$prize'), style: TextStyle(fontWeight: FontWeight.bold, color: c.text))),
                  FilledButton(
                    key: ValueKey('corner-prize-$prize'),
                    onPressed: widget.busy || got == null ? null : () => _save(got),
                    child: Text('🪙${row[1]}'),
                  ),
                ]),
              );
            }),
        ]),
      ),
    ]);
  }

  /// O Move Deleter: quem esquece e qual golpe (fica com pelo menos um). Igual ao site.
  Widget _deleterPanel(Json run, FactoryData data, VoidCallback close) {
    final team = FactoryRun.teamOf(run);
    final index = _panel!.startsWith('deleter:') ? int.tryParse(_panel!.substring(8)) : null;
    if (index == null || index < 0 || index >= team.length) {
      return BwParty(
        testKey: 'deleter',
        title: tr('Move Deleter: quem vai esquecer um golpe?'),
        team: _party(run),
        disabled: (i) => ((team[i]['moves'] as List?) ?? const []).length < 2,
        onPick: (i) => setState(() => _panel = 'deleter:$i'),
        onCancel: close,
      );
    }
    final c = SiteColors.of(context);
    final moves = (team[index]['moves'] as List?) ?? const [];
    return Column(key: const ValueKey('deleter-moves'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _overlayHeader('🧓 Move Deleter · ${_name(team[index]['id'])}', () => setState(() => _panel = 'deleter')),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Qual golpe ele esquece? (Até uma MO; não dá para voltar atrás.)'), style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var k = 0; k < moves.length; k++)
              FilledButton(
                key: ValueKey('deleter-move-$k'),
                onPressed: widget.busy || FactoryRun.forgetMove(run, data, index, k) == null
                    ? null
                    : () {
                        _panel = null;
                        _save(FactoryRun.forgetMove(run, data, index, k));
                      },
                child: Text(prettySlug('${moves[k]}')),
              ),
          ]),
        ]),
      ),
    ]);
  }

  /// Safari Zone: sem batalha; em cada Pokémon, a Safari Ball, a isca ou a pedra. Igual ao site.
  Widget _safariFrame(Json run, Json p, Map? lead, FactoryData data) {
    final s = p['safari'] as Map;
    final mon = s['mon'] as Map?;
    final rates = FactoryRun.safariRates(data, s);
    String pct(double v) => '${(v * 100).round()}%';
    final lastName = s['lastId'] == null ? '' : _name(s['lastId']);
    // Uma linha para o que aconteceu e outra para as chances (a caixa de texto tem duas linhas).
    const last = {
      'broke': 'Ah, não! {0} escapou da Safari Ball!',
      'bait': '{0} está comendo a isca.',
      'rock': '{0} ficou bravo!',
      'fled': '{0} fugiu! Apareceu um {1}!',
      'left': 'Você deixou {0} para lá. Apareceu um {1}!',
    };
    final shown = mon == null ? '' : '${mon['shiny'] == true ? '✨ ' : ''}${_name(mon['id'])}';
    void act(String action) => _save(FactoryRun.safariAct(run, data, action));
    final busy = widget.busy;
    return _frame(
      run: run,
      field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-safari'), (w, h) => [if (mon != null) _fieldMon(mon, w, h), if (lead != null) _fieldMon(lead, w, h, back: true)]),
      text: mon != null
          ? [
              Text(
                  '🦒 ${last[s['last']] != null ? tr(last[s['last']]!).replaceAll('{0}', lastName).replaceAll('{1}', shown) : tr('Um {0} selvagem apareceu!').replaceAll('{0}', shown)} Nv. ${mon['level']}',
                  key: const ValueKey('safari-last')),
              KeyedSubtree(
                  key: const ValueKey('safari-info'),
                  child: _small(tr('Pegar: {0} · Fugir: {1} · Ainda aparecem: {2}').replaceAll('{0}', pct(rates.catchRate)).replaceAll('{1}', pct(rates.flee)).replaceAll('{2}', '${s['left']}'))),
            ]
          : [
              if (s['last'] == 'fled') _small(tr('{0} fugiu!').replaceAll('{0}', lastName)),
              Text('🦒 ${tr('O Safari acabou! Você pegou {0} Pokémon.').replaceAll('{0}', '${s['caught'] ?? 0}')}', key: const ValueKey('safari-over')),
            ],
      // Os botões cabem numa página só: a bola, a isca e a pedra em cima; procurar outro e sair embaixo.
      menu: mon != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _MenuRow(
                  child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(child: _menuButton('🟢 ${tr('BOLA')} ×${s['balls']}', busy ? null : () => act('ball'), key: const ValueKey('safari-ball'))),
                        const SizedBox(width: 4),
                        Expanded(child: _menuButton('🍖 ${tr('ISCA')}', busy ? null : () => act('bait'), key: const ValueKey('safari-bait'))),
                        const SizedBox(width: 4),
                        Expanded(child: _menuButton('🪨 ${tr('PEDRA')}', busy ? null : () => act('rock'), key: const ValueKey('safari-rock'))),
                      ]))),
              _menuGrid([
                _menuButton('🔎 ${tr('PROCURAR OUTRO')}', busy ? null : () => act('run'), key: const ValueKey('safari-next')),
                _menuButton('🚪 ${tr('SAIR')}', busy ? null : () => _save(FactoryRun.leaveSafari(run)), key: const ValueKey('safari-leave')),
              ]),
            ])
          : _menuGrid([_menuButton(tr('CONTINUAR'), busy ? null : () => _save(FactoryRun.leaveSafari(run)), key: const ValueKey('safari-leave'))]),
    );
  }

  /// Troca: escolhe quem dar; o oferecido vem tradeLevels níveis acima, com o item de quem foi.
  Widget _tradeFrame(Json run, Json p, Map? lead, FactoryData data) {
    final team = FactoryRun.teamOf(run);
    final offer = p['trade'] as Map;
    final shiny = offer['shiny'] == true;
    // Quem dar: a tela do time, por cima do campo.
    if (_panel == 'trade') {
      _framePanel = BwParty(
        testKey: 'trade',
        title: tr('Quem você dá em troca do {0}?').replaceAll('{0}', _name(offer['id'])),
        team: [
          for (final (i, m) in _party(run).indexed)
            PartySlot(id: m.id, shiny: m.shiny, name: m.name, level: m.level, hp: m.hp, sub: 'Lv${m.level} → Lv${(team[i]['level'] as num).toInt() + FactoryRun.tradeLevels}'),
        ],
        onPick: (i) {
          _panel = null;
          _save(FactoryRun.tradeMon(run, i, data));
        },
        onCancel: () => setState(() => _panel = null),
      );
    }
    return _frame(
      run: run,
      field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-trade'), (w, h) => [_fieldMon(offer, w, h), if (lead != null) _fieldMon(lead, w, h, back: true)]),
      text: [
        Text('🔁 ${tr('Um treinador quer trocar o {0} dele com você!').replaceAll('{0}', '${shiny ? '✨ ' : ''}${_name(offer['id'])}')}'),
        _small('${tr('Quem você der vai embora; o {0} vem {1} níveis acima, com o item de quem foi.').replaceAll('{0}', _name(offer['id'])).replaceAll('{1}', '${FactoryRun.tradeLevels}')} ${tr('Trocado ganha mais XP.')}'),
      ],
      menu: _menuGrid([
        _menuButton(tr('TROCAR'), () => setState(() => _panel = _panel == 'trade' ? null : 'trade'), active: _panel == 'trade', key: const ValueKey('trade-open')),
        _menuButton(tr('NÃO TROCAR'), () => _save(FactoryRun.skipTrade(run)), key: const ValueKey('trade-skip')),
      ]),
    );
  }

  /// A Creche (na cidade): deixar um Pokémon ou buscar o que ficou (com o ovo). Igual ao site.
  Widget _daycarePanel(Json run, FactoryData data, VoidCallback close) {
    final care = run['daycare'] as Map?;
    // Sem vaga (o ovo pronto também precisa de uma): não dá para buscar.
    final full = care != null && FactoryRun.takeDaycare(run, data) == null;
    if (care == null) {
      return BwParty(
        testKey: 'daycare',
        title: tr('Creche: quem fica? Ganha um nível por andar e, depois de {0} andares, aparece um ovo.').replaceAll('{0}', '${FactoryRun.daycareEgg}'),
        team: _party(run),
        disabled: (_) => FactoryRun.teamOf(run).length < 2,
        onPick: (i) {
          _panel = null;
          _save(FactoryRun.leaveDaycare(run, i, data));
        },
        onCancel: close,
      );
    }
    final mon = care['mon'] as Map;
    final steps = max(0, (run['floor'] as num).toInt() - (care['floor'] as num).toInt());
    final c = SiteColors.of(context);
    return Column(key: const ValueKey('daycare'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _overlayHeader('🏡 ${tr('Creche')}', close),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          SizedBox(width: 48, height: 48, child: PokemonSprite((mon['id'] as num).toInt(), shiny: mon['shiny'] == true, fill: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_name(mon['id'])} · Nv. ${mon['level']} → ${(mon['level'] as num).toInt() + steps}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
              Text(
                  steps >= FactoryRun.daycareEgg
                      ? tr('Tem um ovo esperando por você! Ele vai no time (ocupa uma vaga) e choca depois de {0} vitórias.').replaceAll('{0}', '${FactoryRun.eggBattles}')
                      : tr('Mais {0} andares e aparece um ovo.').replaceAll('{0}', '${FactoryRun.daycareEgg - steps}'),
                  style: TextStyle(fontSize: 12, color: c.muted)),
              if (full) Text(tr('Time cheio: abra espaço para buscar.'), style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ]),
          ),
          FilledButton(
            key: const ValueKey('daycare-take'),
            onPressed: full
                ? null
                : () {
                    _panel = null;
                    _save(FactoryRun.takeDaycare(run, data));
                  },
            child: Text(tr('BUSCAR')),
          ),
        ]),
      ),
    ]);
  }

  Widget _captureFrame(Json run, Json p, Map? lead, List<Widget> tools) {
    final team = FactoryRun.teamOf(run);
    final foe = p['capture'] as Map;
    final shiny = foe['shiny'] == true;
    // Cada ovo no time ocupa uma vaga.
    final full = team.length >= FactoryRun.teamRoom(run);
    void keep([int? replace]) {
      final next = FactoryRun.capture(run, replace);
      if (identical(next, run)) return;
      final factory = currentFactory();
      final meta = FactoryRun.unlockShiny(factory, _data!, foe);
      if (!identical(meta, factory)) _unlocked = (foe['id'] as num).toInt();
      _save(next, meta);
    }

    // Time cheio: a tela do time do Black & White, por cima do campo, para escolher quem sai.
    if (full && _panel == null) {
      _framePanel = BwParty(
        testKey: 'replace',
        title: tr('Time cheio: escolha quem sai para {0} entrar.').replaceAll('{0}', _name(foe['id'])),
        team: _party(run),
        eggs: [for (final e in FactoryRun.eggsOf(run)) (e['left'] as num).toInt()],
        mystery: {for (final (k, e) in FactoryRun.eggsOf(run).indexed) if (e['mystery'] == true) k},
        onPick: keep,
        onCancel: () => _save(FactoryRun.skipCapture(run)),
        cancelLabel: tr('SOLTAR'),
      );
    }
    final toPc = full && FactoryRun.pcOf(run).length < FactoryRun.pcSize;
    return _frame(
      run: run,
      // Capturado: ele está dentro da Poké Ball (na base dele), não mais no campo. Do ovo da Creche, ele mesmo. Igual ao site.
      field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-capture'), (w, h) => [
            foe['egg'] == true || foe['fossil'] == true ? _fieldMon(foe, w, h) : _far(KeyedSubtree(key: const ValueKey('captured-ball'), child: _itemIcon('${p['ball'] ?? 'poke-ball'}', w * 0.08)), w, h),
            if (lead != null) _fieldMon(lead, w, h, back: true),
          ]),
      text: [
        Text('${shiny ? '✨ ' : ''}${tr(foe['egg'] == true ? (foe['mystery'] == true ? 'O ovo misterioso chocou: é um {0}!' : 'O ovo da Creche chocou: é um {0}!') : foe['fossil'] == true ? 'O museu reviveu um fóssil para você: é um {0}!' : 'Pegou! {0} foi capturado!').replaceAll('{0}', _name(foe['id']))} Nv. ${foe['level']}'),
        if (!FactoryRun.dexOf(run).contains((foe['id'] as num).toInt()))
          Builder(builder: (context) {
            final reward = FactoryRun.dexRewardFor(run, (foe['id'] as num).toInt());
            return Text(
                '📖 ${tr('Novo na Pokédex da corrida ({0})').replaceAll('{0}', '${FactoryRun.dexOf(run).length + 1}')}'
                '${reward != null ? ' · 🎁 ${reward['count']}× ${_itemName('${reward['item']}')} +💰${reward['money']}' : ''}',
                key: const ValueKey('factory-dex-new'),
                style: const TextStyle(fontSize: 13));
          }),
        if (shiny) _small(tr('É shiny! (+25% em todos os atributos)'), color: const Color(0xFFD97706)),
        // Quem entra: o gênero e a Nature (para decidir se fica com ele). Igual ao site.
        if (FactoryRun.capturedMon(run) case final mon?)
          _small(
              '${switch (FactoryRun.genderOf(_data!, mon)) { 'F' => '♀ ', 'M' => '♂ ', _ => '' }}${tr('Nature')}: ${mon['nature']}${FactoryRun.isRegionalForm((mon['id'] as num).toInt()) ? ' · 🌍 ${tr('forma regional')}' : ''}',
              color: const Color(0xFF0369A1)),
        if (full) _small(tr('Time cheio: escolha quem sai ou mande para o PC.')),
      ],
      menu: full
          ? _menuGrid([
              if (toPc) _menuButton('💻 ${tr('PARA O PC')}', () => keep(FactoryRun.toPc), key: const ValueKey('factory-to-pc')),
              _menuButton(tr('SOLTAR'), () => _save(FactoryRun.skipCapture(run)), key: const ValueKey('factory-release')),
            ])
          : _menuGrid([_menuButton(tr('CONTINUAR'), () => keep(), key: const ValueKey('factory-continue')), if (FactoryRun.photoNow(run) != null) _photoButton(run)]),
      tools: full ? tools : null,
    );
  }

  /// O mapa: o lugar de agora no campo (o andar, pequeno, num canto) e os caminhos no menu. Na cidade, o ginásio, o
  /// Poké Mart, o Centro, a Creche e o lugar perto dela; dentro de um lugar, os andares dele até o chefe. Igual ao site.
  Widget _mapFrame(Json run, FactoryData data, Map? lead, List<Widget> tools) {
    // O Pokémon que segue você na cidade, na altura de verdade perto do treinador (followerFit). Igual ao site.
    // A altura dele vem do banco: quando chegar, a tela desenha de novo (o treinador também muda de tamanho).
    if (lead != null) loadBattleHeight((lead['id'] as num).toInt(), () => mounted ? setState(() {}) : null);
    final follow = lead == null
        ? null
        : followerFit(battleHeights[(lead['id'] as num).toInt()], AnimatedSprites.instance.standOf((lead['id'] as num).toInt()));
    final boss = FactoryRun.bossOf(data, run);
    final target = FactoryRun.targetOf(data, run);
    final cities = FactoryRun.routeCities(data, run);
    final route = FactoryRun.routeOf(run)!;
    final options = [for (final o in route['options'] as List) Map<String, dynamic>.from(o as Map)];
    final biome = _biomeInfo[route['biome']] ?? _biomeInfo['grass']!;
    final pos = FactoryRun.routePos(run);
    final down = FactoryRun.teamDown(run);
    final town = route['town'] == true;
    final dungeon = run['dungeon'] as Map?;
    final teamName = _teamNames[FactoryRun.villainTeam(boss['name'])] ?? 'Equipe Rocket';
    final baseName = tr('Base da {0}').replaceAll('{0}', teamName);
    String placeName(Object? id) => tr(FactoryRun.placeInfo(data, run, '$id').name);
    final insideName = dungeon == null ? null : dungeon['place'] == 'base' ? baseName : placeName(dungeon['place']);
    // O lugar no caminho (Mt. Moon...) volta para a rota; o da cidade, para a cidade.
    // Saindo de um lugar, você volta para o andar em que entrou (na rota ou na cidade).
    final entered = dungeon != null ? FactoryRun.routePos({...run, 'floor': dungeon['entry'] ?? dungeon['start']}) : pos;
    final backTo = entered >= FactoryRun.routeLength ? tr('a cidade, no mesmo andar') : tr('a rota, no mesmo andar');
    // O nome da rota do jogo (Route 1 · Route 2...).
    final routeName = FactoryRun.routeInfo(data, run)?.name;
    final meeting = !town && options.length == 1 && options.first['kind'] == 'boss';
    final ambush = meeting && (boss['kind'] == 'rival' || boss['kind'] == 'villain');
    // O rival de surpresa no meio da rota.
    // Ou Jessie e James (Equipe Rocket), de surpresa.
    final rival = options.length == 1 && options.first['kind'] == 'rival' ? (options.first['rocket'] == true ? FactoryRun.rocketBoss(data, run) : FactoryRun.rivalBoss(data, run)) : null;
    final me = Trainers.mine;
    final coach = Trainers.byId('${(rival ?? boss)['trainer'] ?? ''}');
    final region = '${boss['region']}';
    final intro = run['boss']['step'] == 0 && pos == 0 ? FactoryRun.storyLine(data, region, 'intro') : '';
    final legend = FactoryRun.regionLegend(data, run);
    final clock = FactoryRun.clockOf();
    final mission = run['mission'] as Map?;
    Future<void> pick(int k) async {
      // Antes da Elite dos Quatro (como nos jogos): depois dela, as lutas da Liga vêm uma atrás da outra.
      final options = (run['route']?['options'] as List?) ?? const [];
      if (k < options.length && options[k]['kind'] == 'boss' && FactoryRun.leagueAhead(data, run)) {
        final go = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('league-ask'),
            content: Text(tr('A Liga começa aqui: depois da primeira da Elite dos Quatro, as lutas vêm uma atrás da outra, sem Centro Pokémon e sem a Enfermeira Joy; só a Bolsa cura. Sem nenhum desmaio até o Campeão, você ganha uma Master Ball. Quer seguir?')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('NÃO'))),
              FilledButton(key: const ValueKey('league-go'), onPressed: () => Navigator.pop(context, true), child: Text(tr('SIM'))),
            ],
          ),
        );
        if (go != true || !mounted) return;
      }
      final next = FactoryRun.chooseNode(run, data, k, FactoryRun.clockOf());
      if (identical(next, run)) return;
      setState(() => saveFactory({...currentFactory(), 'run': next}));
      if (next['encounter'] != null) widget.onBattle(next);
    }

    Widget sign(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
          child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _ink)),
        );
    final fork = !town && options.length > 1;
    // A entrada de um lugar: a base vilã (na cidade), os lugares da cidade, o lugar no caminho ou o próximo da água.
    Widget placeButton(int k) {
      final node = options[k];
      final base = node['place'] == 'base';
      return _menuButton('${FactoryRun.rarePlaces.containsKey(node['place']) ? '✨' : '🕳️'} ${(_biomeInfo[node['scene']] ?? biome).$2} ${base ? baseName : placeName(node['place'])}', widget.busy || down || FactoryRun.nodeBlocked(run, node) ? null : () => pick(k),
          sub: FactoryRun.nodeBlocked(run, node)
              ? _hmHint(run, node)
              : base
                  ? tr('A equipe vilã está na cidade: {0} andares e o chefe dela no fim.').replaceAll('{0}', '${FactoryRun.dungeonLength}')
                  : node['deeper'] == true
                      ? tr('Mais {0} andares e um chefe.').replaceAll('{0}', '${FactoryRun.dungeonLength}')
                      : town
                          ? tr('{0} andares e um chefe; depois volta para a cidade, no mesmo andar.').replaceAll('{0}', '${FactoryRun.dungeonLength}')
                          : tr('{0} andares e um chefe; depois volta para a rota, no mesmo andar.').replaceAll('{0}', '${FactoryRun.dungeonLength}'),
          key: ValueKey('map-node-$k'));
    }
    // Sem o Mapa: nada do mapa e, na bifurcação, segue às cegas.
    final hasMap = run['townMap'] == true || (FactoryRun.hasHm(run, 'flash') && FactoryRun.darkBiomes.contains(route['biome']));
    final cut = !meeting && !town ? FactoryRun.cutPath(run) : null;
    final smash = !meeting && !town ? FactoryRun.smashPath(run) : null;
    final strength = !meeting && !town ? FactoryRun.strengthPath(run) : null;
    final forecast = town ? '' : FactoryRun.weatherOf(run, FactoryRun.shownScene(run, '${route['biome']}', data), clock.season, data);
    final burst = FactoryRun.outbreakOf(data, clock.day);
    // O andar (pequeno, num canto): na rota, até a cidade; num lugar, até o chefe dele.
    final floorTag = dungeon != null
        ? '${min(FactoryRun.dungeonLength, FactoryRun.dungeonPos(run) + 1)}/${FactoryRun.dungeonLength}'
        : town
            ? '${min(FactoryRun.cityLength, pos - FactoryRun.routeLength + 1)}/${FactoryRun.cityLength}'
            : '${pos + 1}/${FactoryRun.routeLength}';
    // O HUD do mapa: hora, clima, efeito do lugar, estação, o lendário que foge e o plano vilão.
    final hud = _mapHud(run, data, FactoryRun.shownScene(run, town ? 'city' : '${route['biome']}', data), clock);
    final scene = town
        ? 'city'
        : meeting && _cityKinds.contains(boss['kind'])
            ? FactoryRun.bossScene(data, boss, '${route['biome']}')
            : '${route['biome']}';
    // As falas (uma por vez, tocando para passar, como nos jogos).
    final lines = <String>[
      if (intro.isNotEmpty) '📖 $intro',
      if (town && pos == FactoryRun.routeLength)
        for (final k in ((run['town'] as Map?)?['got'] as List?) ?? const [])
          '${_keyInfo[k]?.$1 ?? '🔑'} ${tr('Em {0} te deram {1}!').replaceAll('{0}', cities.to).replaceAll('{1}', FactoryRun.keyItems[k] ?? '$k')} ${tr(_keyInfo[k]?.$2 ?? '')}',
      if (!town && dungeon == null && pos == 0 && !meeting)
        '🧭 ${tr('Você sai de {0} e entra em {1}, rumo a {2}.').replaceAll('{0}', cities.from ?? tr('casa')).replaceAll('{1}', tr(biome.$1)).replaceAll('{2}', cities.to)} '
            '${tr(_routeFlavor['${route['biome']}'] ?? _routeFlavor['grass']!)}',
      if (!town && dungeon == null && pos == 0 && !meeting && legend != null)
        '🌟 ${tr(_legendClues[target['kind'] == 'elite' ? _legendClues.length - 1 : min(_legendClues.length - 2, ((run['badges'] as num?) ?? 0).toInt())])}',
      if (dungeon != null && FactoryRun.dungeonPos(run) == 0)
        '🕳️ ${tr('Você entrou em {0}: {1} andares, sem desvios, e um chefe no fim. Depois, de volta para {2}.').replaceAll('{0}', insideName ?? '').replaceAll('{1}', '${FactoryRun.dungeonLength}').replaceAll('{2}', backTo)}',
      if (meeting && boss['kind'] == 'rival')
        '💬 ${boss['name']}: ${tr(_rivalLines[min(_rivalLines.length - 1, ((run['rivalWins'] as num?) ?? 0).toInt())])}'
        '${((run['rivalWins'] as num?) ?? 0) > 0 ? ' ${tr('(Você já me venceu {0} vezes. Meu time ficou mais forte!)').replaceAll('{0}', '${run['rivalWins']}')}' : ''}',
      if (meeting && boss['kind'] == 'villain') ...[
        '💬 ${boss['name']}: ${tr(_villainLines[((run['floor'] as num).toInt() + (run['seed'] as num).toInt()) % _villainLines.length])}',
        '💬 ${tr(_villainPlans[FactoryRun.villainTeam(boss['name'])] ?? _villainPlans['rocket']!)}',
      ],
      if (meeting && boss['kind'] == 'gym') '💬 ${boss['name']}: ${tr(_leaderLines[FactoryRun.leaderType(data, boss)] ?? _leaderLines['normal']!)}',
      if (ambush) tr('{0} apareceu no caminho!').replaceAll('{0}', '${boss['name']}'),
      if (meeting && !ambush) tr('O chefe espera'),
      if (meeting) FactoryRun.storyLine(data, region, '${boss['kind']}', '${boss['name']}'),
      if (rival != null) ...[
        '💬 ${rival['name']}: ${tr((rival['pair'] == true ? _rocketLines : _rivalRaceLines)[((run['rivalRaces'] as num?) ?? 0).toInt() % (rival['pair'] == true ? _rocketLines : _rivalRaceLines).length])}',
        tr('{0} apareceu no caminho!').replaceAll('{0}', '${rival['name']}'),
      ],
      if (options.length == 1 && options.first['meteor'] == true) '☄️ ${tr('Uma chuva de meteoros! Algo caiu bem perto daqui...')}',
      if (options.length == 1 && options.first['mythic'] == true) '✨ ${tr('Uma presença misteriosa... um Pokémon mítico está aqui!')}',
      if (town && boss['kind'] == 'villain') '💬 ${tr('A {0} tomou conta da cidade! O líder do ginásio só volta quando ela for embora.').replaceAll('{0}', teamName)}',
      if (town && pos == FactoryRun.routeLength && boss['kind'] != 'villain')
        tr(FactoryRun.daycareHere(data, run) ? 'Bem-vindo a {0}! O Poké Mart, o Centro Pokémon e a Creche ficam aqui; o líder espera no último andar da cidade.' : 'Bem-vindo a {0}! O Poké Mart e o Centro Pokémon ficam aqui; o líder espera no último andar da cidade.').replaceAll('{0}', cities.to),
      if (dungeon != null && dungeon['cleared'] == true) '🌊 ${tr('Você venceu o chefe daqui! Dá para seguir mais fundo ou voltar.')}',
      for (final o in options)
        if (o['roam'] == true)
          '🐾 ${tr('{0} passou correndo por aqui! Ele foge depois do primeiro turno (dormindo ou congelado, não foge).').replaceAll('{0}', _name(o['legend']))}',
      for (final o in options)
        if (o['plot'] != null)
          '🚨 ${tr('Um capanga da {0} está agindo nesta cidade! Derrote-o para atrapalhar o plano.').replaceAll('{0}', _teamNames[o['grunt']] ?? 'Equipe Rocket')}',
      if (options.any((o) => o['hidden'] != null)) '📡 ${tr('A Dowsing Machine apita: tem um item escondido num dos caminhos!')}',
    ];
    return _frame(
      run: run,
      field: fork && hasMap
          ? _townMap(route, options, pos % FactoryRun.routeLength, cities.from, cities.to, '${boss['region']} · ${boss['game']}', me,
              widget.busy ? null : pick, (node) => (FactoryRun.isBattleNode(node) && down) || FactoryRun.nodeBlocked(run, node), placeName, hud)
          // O líder espera no ginásio da cidade; a Elite dos Quatro e o Campeão, na Liga (nunca no meio da rota).
          : _field(FactoryRun.shownScene(run, scene, data), key: const ValueKey('factory-map'), (w, h) {
              return [
                // O nome do lugar e, logo abaixo, o HUD (hora, clima, efeito, estação, lendário que foge, plano vilão).
                Positioned(
                    left: 8,
                    top: 6,
                    right: 48,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      sign(town
                          ? '🏙️ ${cities.to}'
                          : insideName != null
                              ? '${biome.$2} $insideName'
                              : '${boss['region']} · ${boss['game']} · ${biome.$2} ${routeName != null ? '$routeName → ${cities.to}' : tr('Rota para {0}').replaceAll('{0}', cities.to)}'),
                      const SizedBox(height: 4),
                      hud,
                    ])),
                Positioned(
                    right: 8,
                    top: 6,
                    child: Container(
                      key: const ValueKey('route-floor'),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xB30F172A), borderRadius: BorderRadius.circular(4)),
                      child: Text(floorTag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                if (coach != null && (meeting || rival != null)) _far(TrainerSprite(coach, height: farPerson(w)), w, h),
                if (town && me != null) Positioned(left: w * 0.02, bottom: h * 0.23, child: TrainerSprite(me, height: nearPerson(w) * (follow?.k ?? 1))),
                // Quem vai na frente acompanha você na cidade (como o Pokémon que segue o treinador). Igual ao site.
                if (town && lead != null)
                  Positioned(
                      key: const ValueKey('follower'),
                      // Do tamanho dele perto de você (a mesma escala da batalha).
                      left: w * 0.42,
                      bottom: h * 0.23,
                      width: w * 0.58,
                      height: w * 0.58,
                      child: StageMon(id: (lead['id'] as num).toInt(), shiny: lead['shiny'] == true, base: false, scene: _scene, scale: follow?.scale)),
                if (!town && lead != null) _fieldMon(lead, w, h, back: true),
              ];
            }),
      text: [
        _Dialogue(
          key: ValueKey('dlg-${run['floor']}-${dungeon?['place'] ?? ''}-${options.map((o) => o['kind']).join()}'),
          lines: lines,
          fallback: town
              ? null
              : !fork
                  ? tr('O caminho segue.')
                  : hasMap
                      ? tr('O caminho se divide: escolha por onde ir')
                      : tr('O caminho se divide! Sem o Mapa, você não sabe aonde cada caminho leva.'),
          sub: _dlgSub,
        ),
        if (mission != null && mission['leg'] == (run['leg'] ?? 1))
          Text(
              '📋 ${tr('Missão')}: ${_mission(mission)} (${mission['done']}/${mission['need']})${(mission['done'] as num) >= (mission['need'] as num) ? ' ✔' : ''}',
              key: const ValueKey('factory-mission'),
              style: const TextStyle(fontSize: 13)),
        Text(
            '${tr(_seasonLabel[clock.season] ?? '')} · ${clock.night ? '🌙 ${tr('Noite: mais Fantasma e Sombrio')}' : '🌤️ ${tr('Dia')}'} · '
            '${tr('Chefe em {0}:').replaceAll('{0}', cities.to)} ${target['name']}'
            '${forecast.isNotEmpty ? ' · ${tr('Clima: {0}').replaceAll('{0}', tr(_weatherLabel[forecast] ?? forecast))}${_weatherPull[forecast] != null ? ' (${tr(_weatherPull[forecast]!)})' : ''}' : ''}',
            key: const ValueKey('factory-clock'),
            style: TextStyle(fontSize: 11, color: _dlgSub)),
        if (burst != null)
          Text(
              '📣 ${tr('Surto do dia: {0} aparece muito onde vive (mais chance de shiny).').replaceAll('{0}', _name(burst))}'
              '${((data.species[burst]?.elementAtOrNull(6) as List?) ?? const []).contains(route['biome']) ? ' ${tr('Aqui também!')}' : ''}',
              key: const ValueKey('factory-outbreak'),
              style: TextStyle(fontSize: 11, color: _dlgSub)),
        if (down) _small(tr('O time todo está desmaiado: use um Revive ou desista.'), color: const Color(0xFFDC2626)),
      ],
      menu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _menuGrid(wide: true, [
          // Sem o Mapa: dá para seguir em frente ou pegar outro caminho, sem saber aonde ele leva. Igual ao site.
          if (fork && !hasMap)
            for (var k = 0; k < options.length; k++)
              if (options[k]['kind'] == 'dungeon')
                placeButton(k)
              // O caminho aberto com uma MO (Cut, Rock Smash, Strength): você sabe o que tem nele, mesmo sem o Mapa.
              // A entrada da Safari Zone dá para ver, mesmo sem o Mapa.
              else if (options[k]['kind'] == 'safari')
                _menuButton('${_nodeInfo['safari']!.$1} ${options[k]['name'] ?? 'Safari Zone'}', widget.busy || FactoryRun.nodeBlocked(run, options[k]) ? null : () => pick(k),
                    sub: FactoryRun.nodeBlocked(run, options[k]) ? _hmHint(run, options[k] as Map?) : tr(_nodeInfo['safari']!.$3), key: ValueKey('map-node-$k'))
              else if (_hmPathInfo(options[k]) != null)
                _menuButton('${_hmPathInfo(options[k])!.$1} ${tr(_hmPathInfo(options[k])!.$2).replaceAll('{0}', options[k]['blocker'] != null ? _name(options[k]['legend']) : '')}',
                    widget.busy || FactoryRun.nodeBlocked(run, options[k]) || (FactoryRun.isBattleNode(options[k]) && down) ? null : () => pick(k),
                    sub: FactoryRun.nodeBlocked(run, options[k]) ? _hmHint(run, options[k] as Map?) : tr(_hmPathInfo(options[k])!.$3), key: ValueKey('map-node-$k'))
              else
                _menuButton(k == 0 ? '➡️ ${tr('SEGUIR EM FRENTE')}' : '↗️ ${tr('OUTRO CAMINHO')}${options.length > 2 ? ' $k' : ''}',
                  widget.busy || FactoryRun.nodeBlocked(run, options[k]) || (FactoryRun.isBattleNode(options[k]) && down) ? null : () => pick(k),
                  sub: FactoryRun.nodeBlocked(run, options[k])
                      ? _hmHint(run, options[k] as Map?)
                      : k == 0
                          ? tr('Continuar por onde você está')
                          : tr('Não dá para saber aonde ele leva (o Mapa mostra)'),
                  key: ValueKey('map-node-$k')),
          if (hasMap || !fork)
            for (var k = 0; k < options.length; k++)
              Builder(builder: (context) {
                final node = options[k];
                if (node['kind'] == 'dungeon') return placeButton(k);
                final info = node['area'] == true
                    ? _nodeInfo['area']!
                    : node['mythic'] == true
                    ? _nodeInfo['mythic']!
                    : node['meteor'] == true
                        ? _nodeInfo['meteor']!
                        : node['roam'] == true
                            ? _roamInfo
                            : node['plot'] != null
                            ? _plotInfo
                            : _hmPathInfo(node) ?? (node['legend'] != null ? _legendInfo : _nodeInfo[node['kind']] ?? _nodeInfo['wild']!);
                final placeLegend = node['placeLegend'] == true || node['routeLegend'] == true;
                final b = _hmPathInfo(node) != null ? null : _biomeInfo[node['biome']];
                final isBoss = node['kind'] == 'boss';
                final foeName = isBoss ? '${boss['name']}' : node['kind'] == 'rival' && rival != null ? '${rival['name']}' : null;
                final noSurf = FactoryRun.nodeBlocked(run, node);
                return _menuButton(
                  '${options.length == 1 && foeName == null && node['kind'] != 'dboss' ? '${tr('SEGUIR')}: ' : ''}${node['biome'] == 'underwater' && route['biome'] != 'underwater' ? '🤿 ${tr('MERGULHAR')}: ' : ''}${town && isBoss ? '🏟️' : b?.$2 ?? info.$1} ${foeName ?? tr(info.$2).replaceAll('{0}', node['blocker'] != null ? _name(node['legend']) : '')}${node['roam'] == true || placeLegend ? ' · ${node['forceShiny'] == true ? '✨ ' : ''}${_name(node['legend'])}' : ''}${b != null ? ' · ${tr(b.$1)}' : ''}${node['hidden'] != null ? ' 📡' : ''}',
                  widget.busy || (FactoryRun.isBattleNode(node) && down) || noSurf ? null : () => pick(k),
                  sub: noSurf
                      ? _hmHint(run, node)
                      : isBoss
                          ? '${_bossKind(boss['kind'])}${ambush ? '' : ' · ${cities.to}'}'
                          : node['kind'] == 'dboss'
                              ? dungeon != null
                                  ? tr('O chefe do lugar: vencendo, volta para {0}.').replaceAll('{0}', backTo)
                                  : tr('O chefe da rota: vencendo, você chega em {0}.').replaceAll('{0}', cities.to)
                              : node['hidden'] != null
                                  ? '📡 ${tr('A Dowsing Machine apita: tem um item escondido aqui!')}'
                                  : tr(placeLegend ? _placeLegendHelp : info.$3).replaceAll('{0}', '${FactoryRun.roamTurns}'),
                  key: ValueKey('map-node-$k'),
                );
              }),
          // O desafio do ginásio (antes do líder): vencendo, o time dele vem mais fraco.
          if (town && FactoryRun.gymPuzzleOf(data, run) != null)
            _menuButton('🧩 ${tr('DESAFIO DO GINÁSIO')}: ${tr(_puzzleInfo[FactoryRun.gymPuzzleOf(data, run)!.type]!.$1)}', widget.busy ? null : () => _save(FactoryRun.startPuzzle(run, data)),
                sub: tr('Uma tentativa: vencendo, o time do líder vem {0} níveis abaixo e você ganha um prêmio.').replaceAll('{0}', '${FactoryRun.gymEdgeLevels}'), key: const ValueKey('town-puzzle')),
          if (town && (run['gymEdge'] as Map?)?['leg'] == FactoryRun.legOf(run))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('🧩 ${tr((run['gymEdge'] as Map)['won'] == true ? 'Desafio vencido: o time do líder vem mais fraco.' : 'Desafio perdido: o líder luta com tudo.')}',
                  key: const ValueKey('town-puzzle-done'), style: TextStyle(fontSize: 11, color: _dlgSub)),
            ),
          // As ações da rota, numa grade: pescar, sacudir a árvore, o mel, o vaso de frutas, a bicicleta e o álbum.
          ..._routeActions(run, data, meeting, town),
          if (cut != null)
            _menuButton('✂️ ${tr('USAR {0}').replaceAll('{0}', 'Cut')}', widget.busy ? null : () => _save(cut),
                sub: tr(_hmInfo['cut']!.$3), key: const ValueKey('factory-cut')),
          if (smash != null)
            _menuButton('🪨 ${tr('USAR {0}').replaceAll('{0}', 'Rock Smash')}', widget.busy ? null : () => _save(smash),
                sub: tr(_hmInfo['rock-smash']!.$3), key: const ValueKey('factory-smash')),
          if (strength != null)
            _menuButton('💪 ${tr('USAR {0}').replaceAll('{0}', 'Strength')}', widget.busy ? null : () => _save(strength),
                sub: tr(_hmInfo['strength']!.$3), key: const ValueKey('factory-strength')),
          if (((run['rerolls'] as num?) ?? 0) > 0 && !meeting && !town && hasMap)
            _menuButton('🎲 ${tr('SORTEAR O CAMINHO DE NOVO')}', widget.busy ? null : () => _save(FactoryRun.rerollRoute(run, data)),
                sub: tr('Restam {0} nesta corrida').replaceAll('{0}', '${run['rerolls']}'), key: const ValueKey('factory-reroll')),
        ]),
        // Na cidade: o Poké Mart, o Centro Pokémon e a Creche (cada um no seu lugar). Igual ao site.
        if (town)
          _menuGrid([
            _menuButton('🛒 Poké Mart', widget.busy ? null : () => _save(FactoryRun.townShop(run)), key: const ValueKey('town-mart')),
            _menuButton('🏥 ${tr('CENTRO')}', widget.busy ? null : () => _save(FactoryRun.townCenter(run)), key: const ValueKey('town-center')),
            if (FactoryRun.daycareOpen(data, run))
              _menuButton('🏡 ${tr('CRECHE')}', widget.busy ? null : () => setState(() => _panel = _panel == 'daycare' ? null : 'daycare'),
                active: _panel == 'daycare', key: const ValueKey('town-daycare')),
            // A troca do morador (uma por cidade).
            if ((run['town'] as Map?)?['trade'] case final Map trade)
              trade['done'] == true
                  ? _menuButton('🔁 ${tr('Troca feita: chegou {0}!').replaceAll('{0}', _name(trade['got'] ?? trade['give']))}', null, key: const ValueKey('town-trade'))
                  : _menuButton(
                      '🔁 ${tr('Um morador troca {0} por um {1}').replaceAll('{0}', '${trade['shiny'] == true ? '✨ ' : ''}${_name(trade['give'])}').replaceAll('{1}', _name(trade['want']))}',
                      widget.busy || FactoryRun.townTradeable(run, data).isEmpty ? null : () => setState(() => _panel = _panel == 'towntrade' ? null : 'towntrade'),
                      sub: FactoryRun.townTradeable(run, data).isEmpty
                          ? tr('Você não tem um {0} no time.').replaceAll('{0}', _name(trade['want']))
                          : tr('Uma troca por cidade: o que vem chega {0} níveis acima, ganha mais XP e, se evolui por troca, já chega evoluído.').replaceAll('{0}', '${FactoryRun.tradeLevels}'),
                      active: _panel == 'towntrade',
                      key: const ValueKey('town-trade')),
            // O que só esta cidade tem (como nos jogos): a Department Store, o Game Corner, o Move Deleter e o Move Reminder.
            if (FactoryRun.storeOf(data, run) case final Map store)
              _menuButton('🏬 ${store['name']}', widget.busy ? null : () => _save(FactoryRun.enterStore(run, data)), key: const ValueKey('town-store')),
            if (FactoryRun.cornerOf(data, run) case final Map corner)
              _menuButton('🎰 ${corner['name']}', widget.busy ? null : () => setState(() => _panel = _panel == 'corner' ? null : 'corner'),
                  active: _panel == 'corner', key: const ValueKey('town-corner')),
            if (FactoryRun.tutorsOf(data, run).contains('deleter'))
              _menuButton('🧓 Move Deleter', widget.busy ? null : () => setState(() => _panel = (_panel ?? '').startsWith('deleter') ? null : 'deleter'),
                  active: (_panel ?? '').startsWith('deleter'), key: const ValueKey('town-deleter')),
            if (FactoryRun.tutorsOf(data, run).contains('reminder'))
              _menuButton(
                  '💭 Move Reminder${(run['town'] as Map?)?['reminded'] == true ? ' ✓' : FactoryRun.reminderCost(data, run) > 0 ? ' · 💰${FactoryRun.reminderCost(data, run)}' : ''}',
                  widget.busy || FactoryRun.townReminder(run, data) == null ? null : () => _save(FactoryRun.townReminder(run, data)),
                  key: const ValueKey('town-reminder')),
            // O ovo misterioso: um morador te dá um ovo sem dizer de quem é.
            if (FactoryRun.mysteryEgg(data, run) != null)
              _menuButton('❔ ${tr('RECEBER O OVO MISTERIOSO')}', widget.busy ? null : () => _save(FactoryRun.takeMysteryEgg(run, data)),
                  sub: tr('Um morador quer que você cuide de um ovo. De quem será? Choca depois de {0} vitórias.').replaceAll('{0}', '${FactoryRun.eggBattles}'),
                  key: const ValueKey('town-mystery-egg')),
            // Os presentes da cidade (o Eevee de Celadon, o Lapras da Silph Co., o ovo de Togepi...).
            for (final g in FactoryRun.townGifts(data, run))
              for (final id in (g['choose'] as List?) ?? [g['id']])
                Builder(builder: (context) {
                  final got = FactoryRun.takeGift(run, data, g['k'] as int, (id as num).toInt());
                  final egg = g['egg'] == true;
                  return _menuButton(
                      '${egg ? '🥚' : '🎁'} ${tr(egg ? 'RECEBER O OVO DE {0}' : 'RECEBER {0}').replaceAll('{0}', _name(id))}',
                      widget.busy || got == null ? null : () => _save(got),
                      sub: got == null
                          ? tr('Sem vaga no time para o ovo.')
                          : g['choose'] != null
                              ? tr('Um presente daqui: escolha só um dos dois.')
                              : egg
                                  ? tr('Vai no time como ovo e choca depois de {0} vitórias.').replaceAll('{0}', '${FactoryRun.eggBattles}')
                                  : tr('Um presente daqui: entra no time (ou vai para o PC).'),
                      key: ValueKey('town-gift-${g['k']}-$id'));
                }),
          ]),
      ]),
      tools: tools,
    );
  }

  /// O mapa da cidade (como o Town Map do Black & White) na bifurcação: a rota da cidade de onde veio até a do chefe,
  /// você no andar de agora e os caminhos abrindo na frente; toque num caminho para ir por ele. Igual ao site (TownMap).
  /// O HUD do mapa (como a faixa do tempo nos jogos): a hora (dia ou noite), o clima e o efeito do lugar (fixos na
  /// rota), a estação, onde o lendário que foge foi visto e o plano da equipe vilã. Igual ao site.
  Widget _mapHud(Json run, FactoryData data, String scene, ({bool night, String season, int? day}) clock) {
    final sky = FactoryRun.weatherOf(run, scene, clock.season, data);
    final field = FactoryRun.fieldOf(run, scene, data);
    final roam = FactoryRun.roamerSeen(data, run);
    final plot = FactoryRun.villainPlot(data, run);
    Widget chip(String text, [String? key]) => Container(
          key: key == null ? null : ValueKey(key),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: const Color(0xCC0F172A), borderRadius: BorderRadius.circular(4)),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        );
    final chapters = (plot?['chapters'] as List?) ?? const [];
    return IgnorePointer(
      child: KeyedSubtree(
        key: const ValueKey('map-hud'),
        child: Wrap(spacing: 3, runSpacing: 3, children: [
            chip(clock.night ? '🌙 ${tr('Noite')}' : '☀️ ${tr('Dia')}', 'hud-time'),
            chip(sky.isNotEmpty ? tr(_weatherLabel[sky] ?? sky) : '🌤️ ${tr('Tempo bom')}', 'hud-weather'),
            if (_fieldHud[field] != null) chip('${_fieldHud[field]!.$1} ${tr(_fieldHud[field]!.$2)}', 'hud-field'),
            chip(tr(_seasonLabel[clock.season] ?? '')),
            if (roam != null) chip('🐾 ${_roamName(_name(roam['id']))}: ${roam['here'] == true ? tr('nesta rota!') : '${roam['city'] ?? ''}'}', 'hud-roamer'),
          if (chapters.isNotEmpty) chip('🚨 ${plot!['foiled']}/${chapters.length}', 'hud-plot'),
        ]),
      ),
    );
  }

  Widget _townMap(Json route, List<Json> options, int pos, String? from, String to, String title, Trainer? me, void Function(int)? onPick,
      bool Function(Json) blocked, String Function(Object?) placeName, [Widget? hud]) {
    const end = FactoryRun.routeLength + 1;
    final here = pos + 1;
    return ClipRRect(
      key: const ValueKey('factory-map'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: _border, width: 4), color: const Color(0xFF1D3F8F)),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            // Em unidades de 160 × 120, como o site.
            final sx = w / 160, sy = h / 120;
            const y0 = 64.0, left = 14.0;
            final hx = left + here / end * 70, ox = hx + 30;
            double x(int k) => k <= here ? left + k / end * 70 : ox + 14 + (k - here - 1) / max(1, end - here - 1) * (160 - 14 - ox - 14);
            final n = options.length;
            final ys = [for (var k = 0; k < n; k++) y0 + (k - (n - 1) / 2) * min(30.0, 84 / n)];
            Widget sign(String text) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(4)),
                  child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _ink)),
                );
            return Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: CustomPaint(painter: _TownMapPainter(here: here, end: end, x: x, y0: y0, ox: ox, ys: ys, sx: sx, sy: sy))),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  color: const Color(0xCC0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('🗺️ $title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
                    Text(tr('O caminho se divide'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ]),
                ),
              ),
              Positioned(left: x(0) * sx - 14, top: (y0 + 8) * sy, child: sign('🏠 ${from ?? tr('Início')}')),
              Positioned(right: w - x(end) * sx - 14, top: (y0 + 8) * sy, child: sign('👑 $to')),
              if (me != null) Positioned(left: x(here) * sx - w * 0.085, top: (y0 + 2) * sy - w * 0.17, child: TrainerSprite(me, box: w * 0.17)),
              // Os caminhos: botões no próprio mapa.
              for (var k = 0; k < n; k++)
                Positioned(
                  left: ox * sx,
                  top: ys[k] * sy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Builder(builder: (context) {
                      final node = options[k];
                      final info = node['kind'] == 'dungeon'
                          ? ((_biomeInfo[node['scene']] ?? _biomeInfo['cave']!).$2, placeName(node['place']), '')
                          : node['roam'] == true
                              ? _roamInfo
                              : node['plot'] != null
                              ? _plotInfo
                              : _hmPathInfo(node) ?? (node['legend'] != null ? _legendInfo : _nodeInfo[node['kind']] ?? _nodeInfo['wild']!);
                      final b = _hmPathInfo(node) != null ? null : _biomeInfo[node['biome']];
                      final off = onPick == null || blocked(node);
                      return Opacity(
                        opacity: off ? 0.5 : 1,
                        child: Material(
                          key: ValueKey('map-pin-$k'),
                          color: const Color(0xE61E3A8A),
                          shape: const StadiumBorder(side: BorderSide(color: Colors.white, width: 2)),
                          elevation: 4,
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: off ? null : () => onPick(k),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Text(b?.$2 ?? info.$1, style: const TextStyle(fontSize: 13))),
                                const SizedBox(width: 4),
                                Text('${node['placeLegend'] == true || node['routeLegend'] == true ? _name(node['legend']) : tr(info.$2).replaceAll('{0}', node['blocker'] != null ? _name(node['legend']) : '')}${node['hidden'] != null ? ' 📡' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              if (hud != null) Positioned(left: 8, right: 8, top: 30, child: hud),
            ]);
          }),
        ),
      ),
    );
  }
}

/// As linhas do mapa: a rota (o que já passou mais claro), os caminhos da bifurcação, os andares e as cidades.
class _TownMapPainter extends CustomPainter {
  _TownMapPainter({required this.here, required this.end, required this.x, required this.y0, required this.ox, required this.ys, required this.sx, required this.sy});
  final int here, end;
  final double Function(int) x;
  final double y0, ox, sx, sy;
  final List<double> ys;

  @override
  void paint(Canvas canvas, Size size) {
    // A grade do Town Map.
    final grid = Paint()..color = const Color(0x14FFFFFF);
    for (var gx = 0.0; gx < size.width; gx += 12) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), grid);
    }
    for (var gy = 0.0; gy < size.height; gy += 12) {
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }
    Offset at(double px, double py) => Offset(px * sx, py * sy);
    final done = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = 3 * sy
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at(x(0), y0), at(x(here), y0), done);
    final ahead = Paint()
      ..color = const Color(0xFF93C5FD)
      ..strokeWidth = 3 * sy;
    // Tracejado até a cidade do chefe.
    for (var px = ox + 14; px < x(end); px += 5) {
      canvas.drawLine(at(px, y0), at(min(px + 3, x(end)), y0), ahead);
    }
    final branch = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 2 * sy
      ..style = PaintingStyle.stroke;
    for (final y in ys) {
      final path = Path()
        ..moveTo(x(here) * sx, y0 * sy)
        ..cubicTo((x(here) + 12) * sx, y0 * sy, (ox - 12) * sx, y * sy, ox * sx, y * sy)
        ..cubicTo((ox + 8) * sx, y * sy, (ox + 6) * sx, y0 * sy, (ox + 14) * sx, y0 * sy);
      canvas.drawPath(path, branch);
    }
    for (var k = 0; k <= end; k++) {
      final c = at(x(k), y0);
      if (k == 0 || k == end) {
        final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 10 * sx, height: 10 * sy), const Radius.circular(3));
        canvas.drawRRect(r, Paint()..color = const Color(0xFFEF4444));
        canvas.drawRRect(r, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(c, 2.4 * sy, Paint()..color = k < here ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE));
        canvas.drawCircle(c, 2.4 * sy, Paint()
          ..color = const Color(0xFF1E3A8A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TownMapPainter old) => old.here != here || old.ys.length != ys.length || old.sx != sx;
}

/// Chefes que esperam na cidade (ginásio) ou na Liga.
const _cityKinds = {'gym', 'elite', 'champion'};

/// Ao entrar na rota: uma frase do lugar. Igual ao site.
const _routeFlavor = {
  'grass': 'O vento balança o mato alto: tem Pokémon por toda parte.',
  'forest': 'As árvores fecham o céu; algo se mexe entre as folhas.',
  'water': 'As ondas batem forte; os Pokémon de Água estão agitados.',
  'beach': 'A areia esquenta os pés e o mar brilha ao longe.',
  'underwater': 'Tudo fica azul e silencioso lá embaixo.',
  'swamp': 'O pântano cheira a veneno e a lama prende os passos.',
  'sewer': 'Canos pingando e olhos brilhando no escuro.',
  'cave': 'Está escuro e frio; ecos vêm do fundo da caverna.',
  'icecave': 'O gelo estala sob os pés; cuidado para não escorregar.',
  'lavacave': 'O calor sobe do chão e rios de lava iluminam as paredes.',
  'poisoncave': 'Uma névoa roxa cobre o chão; melhor não respirar fundo.',
  'seacave': 'A água bate nas pedras e ecoa por toda a caverna.',
  'waterfall': 'O barulho da cachoeira enche a gruta; a névoa molha tudo.',
  'mountain': 'O caminho sobe pelas pedras; o ar fica mais fino.',
  'desert': 'O sol queima e a areia apaga as pegadas.',
  'volcano': 'O chão treme e a lava borbulha por perto.',
  'snow': 'A neve cai sem parar e cobre o caminho.',
  'city': 'Ruas cheias de treinadores querendo um desafio.',
  'sky': 'Nuvens por todo lado: só os que voam passam por aqui.',
  'tower': 'Velas acesas e um frio estranho: dizem que a torre é assombrada.',
  'ruins': 'Colunas quebradas e inscrições antigas: dizem que algo dorme aqui.',
  'flowers': 'Um mar de flores balança com o vento; o pólen deixa tudo sonolento.',
  'plant': 'Máquinas zumbem e faíscas pulam dos cabos: cuidado com os raios.',
  'crystal': 'Cristais brilham nas paredes da mina; às vezes eles caem do teto.',
  'dunes': 'A lua ilumina as dunas e a areia engole os passos.',
  'bamboo': 'Os bambus estalam ao vento e a luz entra em faixas.',
  'temple': 'Incenso e silêncio: o templo guarda Pokémon antigos.',
};

/// O rival e os vilões antes da luta. Igual ao site.
/// O rival de surpresa na rota (fora os da história). Igual ao site.
/// Jessie e James de surpresa na rota (falas originais). Igual ao site.
const _rocketLines = [
  'Achamos você! Esses Pokémon vão direto para o chefe!',
  'Desta vez o plano não tem como dar errado!',
  'A Equipe Rocket nunca desiste. Passa esses Pokémon pra cá!',
];
const _rivalRaceLines = [
  'Ei! Te alcancei! Vamos ver quem treinou mais desde a última vez!',
  'Você de novo? Ótimo, eu estava te procurando!',
  'Não vou deixar você chegar no próximo ginásio sem uma revanche!',
];
const _rivalLines = [
  'Achou que ia passar sem me enfrentar? Mostre o que aprendeu!',
  'Treinei sem parar desde a última vez. Agora é a minha vez de ganhar!',
  'O seu time melhorou... mas o meu também!',
  'Só um de nós vai chegar ao Campeão. Vamos decidir aqui!',
];
const _villainLines = [
  'Os seus Pokémon seriam muito úteis para os nossos planos...',
  'Saia do caminho, criança! Não temos tempo para heróis.',
  'Ninguém atrapalha a nossa equipe e sai ileso!',
];

/// A evolução, como nos jogos: o Pokémon fica branco e pisca alternando com a forma nova, cada vez mais rápido, até ela
/// aparecer com brilho. Igual ao site (EvolutionFx).
class _EvolutionFx extends StatefulWidget {
  const _EvolutionFx({required this.from, required this.to});
  final int from, to;

  @override
  State<_EvolutionFx> createState() => _EvolutionFxState();
}

class _EvolutionFxState extends State<_EvolutionFx> with SingleTickerProviderStateMixin {
  // 2,6 s da evolução (frações até 0,62) e mais um pouco mostrando a forma nova antes de a tela voltar.
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..forward();

  /// As trocas (fração do tempo): cada vez mais perto uma da outra; a partir de 0.8, só a nova.
  static const _flips = [0.2, 0.25, 0.35, 0.42, 0.5, 0.55, 0.61, 0.65, 0.7, 0.73, 0.77, 0.8];

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        key: const ValueKey('evolution-fx'),
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final all = _clock.value;
            // v: o andamento da evolução (0 a 1 nos primeiros 2,6 s).
            final v = (all / 0.62).clamp(0.0, 1.0);
            final showNew = _flips.where((f) => v >= f).length.isOdd || v >= 0.8;
            const white = ColorFilter.matrix([0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0, 0, 0, 1, 0]);
            final glow = v < 0.8 ? v / 0.8 : 1 - (v - 0.8) / 0.2;
            // A tela escurece (entra rápido e sai no fim) e o Pokémon gira no meio, cada vez mais rápido.
            final stage = all < 0.08 ? all / 0.08 : all > 0.82 ? 1 - (all - 0.82) / 0.18 : 1.0;
            final spin = v < 0.8 ? Curves.easeIn.transform(v / 0.8) * 10 * pi : 0.0;
            final sprite = v >= 1
                ? PokemonSprite(widget.to, fill: 0.9, battle: true)
                : ColorFiltered(colorFilter: white, child: PokemonSprite(showNew ? widget.to : widget.from, fill: 0.9, battle: true));
            return Opacity(
              opacity: stage.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: const BoxDecoration(gradient: RadialGradient(colors: [Color(0xBF1E293B), Color(0xF2020617)])),
                child: LayoutBuilder(builder: (context, box) {
                  final size = box.maxWidth * 0.55;
                  return Center(
                    child: SizedBox.square(
                      dimension: size,
                      child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
                        Transform.scale(
                          scale: 1.3,
                          child: Opacity(
                            opacity: glow.clamp(0, 1),
                            child: const DecoratedBox(
                                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xE6FFFFFF), Color(0x66FDE047), Colors.transparent]))),
                          ),
                        ),
                        Transform(alignment: Alignment.center, transform: Matrix4.rotationY(spin), child: sprite),
                      ]),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      );
}

/// O nome de cada equipe vilã (nomes dos jogos). Igual ao site.
const _teamNames = {
  'yell': 'Equipe Yell', 'macro': 'Macro Cosmos',
  'rocket': 'Equipe Rocket', 'aqua': 'Equipe Aqua', 'magma': 'Equipe Magma', 'galactic': 'Equipe Galáctica', 'plasma': 'Equipe Plasma',
  'flare': 'Equipe Flare', 'skull': 'Equipe Skull', 'aether': 'Fundação Aether', 'star': 'Equipe Star',
};

/// As falas uma de cada vez, no mesmo lugar (a caixa não cresce), como nos jogos: tocar passa para a próxima (▼). Sem
/// falas, o texto de fallback. Igual ao site.
class _Dialogue extends StatefulWidget {
  const _Dialogue({super.key, required this.lines, this.fallback, required this.sub});
  final List<String> lines;
  final String? fallback;
  final Color sub;

  @override
  State<_Dialogue> createState() => _DialogueState();
}

class _DialogueState extends State<_Dialogue> {
  int _k = 0;

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    if (lines.isEmpty) return widget.fallback == null ? const SizedBox.shrink() : Text(widget.fallback!);
    final last = _k >= lines.length - 1;
    return GestureDetector(
      key: const ValueKey('factory-dialogue'),
      behavior: HitTestBehavior.opaque,
      onTap: last ? null : () => setState(() => _k++),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Text(lines[min(_k, lines.length - 1)])),
        if (!last) Text('▼ ${_k + 1}/${lines.length}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: widget.sub)),
      ]),
    );
  }
}

/// A ajuda para quem está começando (igual ao site).
const _helpTopics = [
  ('🔥', 'Tipos', 'Cada golpe tem um tipo. Contra um tipo fraco a ele, causa o dobro (super efetivo); contra um que resiste, a metade. Alguns tipos são imunes (Normal não acerta Fantasma). A tabela de tipos fica na Enciclopédia.'),
  ('🌦️', 'Clima', 'Sol fortalece Fogo e enfraquece Água; chuva faz o contrário; areia e neve machucam quem não é do tipo certo a cada turno. Alguns lugares já têm clima.'),
  ('🌿', 'Terrenos e efeitos do lugar', 'Terrenos (Grassy, Electric, Psychic, Misty) mudam o poder de alguns golpes. Alguns lugares têm efeitos próprios, como ventos fortes ou névoa tóxica.'),
  ('💤', 'Status', 'Queimado perde HP e bate mais fraco; envenenado perde HP; paralisado fica lento e às vezes não se mexe; dormindo e congelado não atacam. Status ajuda a capturar.'),
  ('✨', 'Mega, Z, Dynamax e Tera', 'Com o item certo, o botão no meio dos golpes ativa a mecânica uma vez por batalha: Mega Evolução, Movimento Z (só em Alola), Dynamax (Dynamax Band) e Terastal (Tera Orb).'),
  ('🎯', 'Captura', 'Quanto menos HP e com status, mais fácil. Selvagens de nível baixo são mais fáceis; de nível acima do seu Pokémon, bem mais difíceis. Bolas melhores ajudam.'),
  ('🏙️', 'Cidades e lugares', 'A cada rota de 10 andares você chega numa cidade: ginásio, Poké Mart, Centro Pokémon e Creche. Perto dela há um lugar com 10 andares e um chefe; depois, de volta à cidade.'),
  ('💞', 'Amizade e habilidades', 'Quem fica no time ganha amizade e alguns evoluem por ela. Pickup acha itens, Intimidate espanta selvagens e Synchronize passa a Nature para o capturado.'),
];

/// O símbolo de cada melhoria (no círculo da árvore). Igual ao site.
const _upgradeIcons = {
  'level': '🎓', 'ivs': '🧬', 'balls': '⚪', 'potions': '🧪', 'revive': '💖', 'money': '💰', 'shop': '🏷️', 'exp': '✨',
  'expShare': '📡', 'reroll': '🎲', 'cards': '🃏', 'shiny': '🌟', 'greatBalls': '🔵', 'rope': '🪢', 'coins': '🪙', 'map': '🗺️',
  'dmax': '🔴', 'tera': '💎', 'superPotions': '💧', 'hyperPotions': '🧴', 'maxPotions': '🍶', 'sitrus': '🍋', 'lum': '🫐', 'leftovers': '🍎',
  'sash': '🎗️', 'ultraBalls': '🟡', 'masterBall': '🟣', 'quickBalls': '🎯', 'netBalls': '🫳', 'timerBalls': '⏳', 'duskBalls': '🍓', 'expPlus': '🌠',
  'luckyEgg': '🥚', 'hpBoost': '❤️', 'speBoost': '💨', 'tutor': '📜', 'reminder': '🧠', 'atk': '⚔️', 'spa': '🔮', 'def': '🛡️',
  'spd': '🔰', 'allStats': '👑', 'band': '🎀', 'scarf': '🧣', 'specs': '👓', 'lifeOrb': '🟠', 'vest': '🦺', 'helmet': '⛑️',
  'quickClaw': '🦅', 'balloon': '🎈', 'brightPowder': '💫', 'boots': '👢', 'kingsRock': '🪨', 'loot': '💵', 'expertBelt': '🥋', 'bonusCoins': '🏆',
  'policy': '📋', 'muscleBand': '💪', 'wiseGlasses': '🤓', 'shellBell': '🐚', 'scopeLens': '🔭', 'eviolite': '💠', 'victoryHeal': '💚',
};

/// A cor de cada ramo (as linhas e os círculos comprados), na ordem de upgradeBranches. Igual ao site.
const _branchColors = [Color(0xFF22C55E), Color(0xFF38BDF8), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFA855F7), Color(0xFFEAB308), Color(0xFFEC4899)];

/// A árvore em círculo (como as árvores de habilidade dos jogos): os ramos saem do centro para todos os lados. Igual ao site.
const _treeFirst = 190.0, _treeStep = 70.0, _treePad = 230.0, _treeFrom = 90.0, _treeTo = -270.0;

/// A distância mínima entre os centros de dois nós vizinhos do mesmo anel (o maior círculo, com o brilho e o selo).
const _treeGap = 66.0;

/// A melhoria grande que dá nome e símbolo (os nós pequenos usam os da melhoria do mesmo efeito).
String _upgradeKey(String id) {
  if (!FactoryRun.isMinor(id)) return id;
  final fx = FactoryRun.upgradeFx[id]!;
  return FactoryRun.minorBase['${fx.$1}:${fx.$2}']!;
}

typedef _TreeBranch = ({String icon, String name, List<String> ids, Color color, List<({String id, String? parent, Offset pos})> nodes, double mid});

/// As posições (árvore radial): cada ramo ganha um pedaço do círculo do tamanho das pontas dele; cada melhoria fica no
/// meio do pedaço do pai, mais longe do centro a cada nível. Igual ao site (skillTreeLayout).
final _treeLayout = _skillTreeLayout();
({List<_TreeBranch> branches, double size, double radius}) _skillTreeLayout() {
  String? parentOf(String id) => FactoryRun.upgradeTree[id]?.needs?.$1;
  final kidsOf = <String, List<String>>{};
  for (final b in FactoryRun.upgradeBranches) {
    for (final id in b.$3) {
      final p = parentOf(id);
      if (p != null) (kidsOf[p] ??= []).add(id);
    }
  }
  final tipsMemo = <String, int>{};
  int tips(String id) => tipsMemo[id] ??= () {
        final n = (kidsOf[id] ?? const []).fold(0, (n, k) => n + tips(k));
        return n == 0 ? 1 : n;
      }();
  double rad(double d) => d * pi / 180;
  final total = FactoryRun.upgradeBranches.fold(0, (n, b) => n + tips(b.$3.first));
  // 1º: o ângulo de cada um (o meio do pedaço do pai) e o nível (a distância do centro).
  final angles = <({int branch, String id, String? parent, double angle, int depth})>[];
  final mids = <double>[];
  var start = rad(_treeFrom);
  for (final (b, branch) in FactoryRun.upgradeBranches.indexed) {
    final ids = branch.$3;
    void place(String id, double a, double z, int depth, String? parent) {
      angles.add((branch: b, id: id, parent: parent, angle: (a + z) / 2, depth: depth));
      var x = a;
      for (final k in kidsOf[id] ?? const <String>[]) {
        final span = (z - a) * tips(k) / tips(id);
        place(k, x, x + span, depth + 1, id);
        x += span;
      }
    }

    final span = (rad(_treeTo) - rad(_treeFrom)) * tips(ids.first) / total;
    place(ids.first, start, start + span, 0, null);
    mids.add(start + span / 2);
    start += span;
  }
  // 2º: o raio de cada anel, grande o bastante para os vizinhos do mesmo anel não encostarem (nada um em cima do outro).
  final maxDepth = angles.map((n) => n.depth).reduce(max);
  final radii = <double>[];
  for (var d = 0; d <= maxDepth; d++) {
    final ring = [for (final n in angles) if (n.depth == d) n.angle]..sort();
    var gap = 2 * pi;
    for (var k = 0; k < ring.length; k++) {
      final next = k + 1 < ring.length ? ring[k + 1] : ring.first + 2 * pi;
      if (ring.length > 1) gap = min(gap, (next - ring[k]).abs());
    }
    final need = ring.length > 1 ? _treeGap / (2 * sin(min(gap, pi) / 2)) : 0.0;
    radii.add(max(d == 0 ? _treeFirst : radii[d - 1] + _treeStep, need));
  }
  final radius = radii.last;
  final size = 2 * (radius + _treePad);
  final c = size / 2;
  final out = <_TreeBranch>[];
  for (final (b, branch) in FactoryRun.upgradeBranches.indexed) {
    final (icon, name, ids) = branch;
    out.add((
      icon: icon,
      name: name,
      ids: ids,
      color: _branchColors[b % _branchColors.length],
      nodes: [
        for (final n in angles)
          if (n.branch == b) (id: n.id, parent: n.parent, pos: Offset(c + cos(n.angle) * radii[n.depth], c - sin(n.angle) * radii[n.depth])),
      ],
      mid: mids[b],
    ));
  }
  return (branches: out, size: size, radius: radius);
}

/// A árvore de melhorias em leque (como as árvores de habilidade dos jogos): os ramos saem do centro e se dividem;
/// cada círculo é uma melhoria (comprada: colorida; para comprar: contorno do ramo; bloqueada: cinza com cadeado).
/// Arraste para andar e use pinça (ou + e −) para o zoom. Tocando, abre o que ela faz, o que falta e o botão de
/// comprar. Igual ao site (SkillTree).
class _SkillTree extends StatefulWidget {
  final Json factory;
  final void Function(Json) onBuy;

  /// Em tela cheia (a árvore ocupa a tela toda; o botão ✕ fecha).
  final bool full;
  const _SkillTree({required this.factory, required this.onBuy, this.full = false});

  @override
  State<_SkillTree> createState() => _SkillTreeState();
}

class _SkillTreeState extends State<_SkillTree> {
  String? _picked;
  // O filtro da lista embaixo da árvore: 'buy' (dá para comprar), um ramo ou 'need:<item>' (falta o item). Igual ao site.
  String _filter = 'buy';
  final _view = TransformationController();
  double? _width;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  Size _box = Size.zero;

  /// Leva a árvore até o nó (no zoom de agora), para quem escolhe pela lista.
  void _focus(String id) {
    final pos = {for (final b in _treeLayout.branches) for (final n in b.nodes) n.id: n.pos}[id];
    if (pos == null || _box.isEmpty) return;
    final s = _view.value.getMaxScaleOnAxis();
    _view.value = Matrix4.identity()
      ..translateByDouble(_box.width / 2 - pos.dx * s, _box.height / 2 - pos.dy * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  /// Começa no centro da árvore, num zoom em que se vê bastante dela.
  void _fit(double width, double height) {
    _box = Size(width, height);
    if (_width == width) return;
    _width = width;
    final size = _treeLayout.size;
    const s = 0.4;
    _view.value = Matrix4.identity()
      ..translateByDouble(-(size * s - width) / 2, -(size * s - height) / 2, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  /// A árvore em tela cheia (as compras feitas nela valem aqui também).
  void _openFull() {
    Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => _FullSkillTree(factory: widget.factory, onBuy: widget.onBuy)));
  }

  void _zoom(double by) {
    final m = _view.value.clone();
    final s = m.getMaxScaleOnAxis();
    final next = (s * by).clamp(0.15, 2.0);
    _view.value = m..scaleByDouble(next / s, next / s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final f = widget.factory;
    final layout = _treeLayout.branches;
    final size = _treeLayout.size, center = Offset(size / 2, size / 2);
    final posOf = {for (final b in layout) for (final n in b.nodes) n.id: n.pos};
    String state(String id) => FactoryRun.upgradeLevel(f, id) > 0
        ? 'have'
        : FactoryRun.upgradeNeeds(f, id).any((n) => n['kind'] == 'up')
            ? 'locked'
            : 'open';
    final firstOpen = layout.expand((b) => b.ids).where((id) => FactoryRun.upgradePrice(f, id) != null && FactoryRun.upgradeNeeds(f, id).isEmpty).firstOrNull;
    final id = _picked ?? firstOpen ?? 'level';
    final up = FactoryRun.upgrades[id]!;
    final level = FactoryRun.upgradeLevel(f, id);
    final price = FactoryRun.upgradePrice(f, id);
    final value = up.offset + (price == null ? FactoryRun.upgradeValue(f, id) : (level + 1) * up.per);
    final needs = price == null ? const <Json>[] : FactoryRun.upgradeNeeds(f, id);
    final coins = ((f['coins'] as num?) ?? 0).toInt();
    String needText(Json n) => switch (n['kind']) {
          'up' => tr('{0} no nível {1}').replaceAll('{0}', tr(_upgradeNames[_upgradeKey('${n['id']}')] ?? '')).replaceAll('{1}', '${n['level']}'),
          'best' => tr('Chegar ao andar {0} (recorde: {1})').replaceAll('{0}', '${n['floor']}').replaceAll('{1}', '${f['best'] ?? 0}'),
          'pieces' => tr('{0} {1} (tem {2}; cai de {3})')
              .replaceAll('{0}', '${n['count']}')
              .replaceAll('{1}', '${pieceInfo[n['item']]!.$1} ${pieceInfo[n['item']]!.$2}')
              .replaceAll('{2}', '${FactoryRun.piecesOf(f)[n['item']]}')
              .replaceAll('{3}', tr(pieceInfo[n['item']]!.$3)),
          _ => tr('Ter {0} Pokémon para começar (tem {1})').replaceAll('{0}', '${n['count']}').replaceAll('{1}', '${((f['owned'] as List?) ?? const []).length}'),
        };
    final spent = ((f['upgrades'] as Map?) ?? const {}).values.fold(0, (n, v) => n + (v as num).toInt());
    final buyable = [
      for (final k in layout.expand((b) => b.ids))
        if (FactoryRun.upgradePrice(f, k) case final p? when p <= coins && FactoryRun.upgradeNeeds(f, k).isEmpty) (k, p),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final branchIds = {for (final (_, branch, ids) in FactoryRun.upgradeBranches) branch: ids};
    final filtered = _filter == 'buy'
        ? buyable
        : ([
            for (final k in layout.expand((b) => b.ids))
              if (FactoryRun.upgradePrice(f, k) case final p?)
                if (_filter.startsWith('need:')
                    ? FactoryRun.upgradeNeeds(f, k).any((n) => n['kind'] == 'pieces' && n['item'] == _filter.substring(5))
                    : (branchIds[_filter] ?? const []).contains(k))
                  (k, p),
          ]..sort((a, b) => a.$2.compareTo(b.$2)));
    final all = FactoryRun.upgrades.values.fold(0, (n, u) => n + u.max);
    // A árvore toda num desenho só (rápido de arrastar e dar zoom; antes eram centenas de widgets). Tocar escolhe o nó
    // mais perto do dedo.
    final nodes = [
      for (final b in layout)
        for (final n in b.nodes)
          (
            id: n.id,
            pos: n.pos,
            from: n.parent == null ? center : posOf[n.parent]!,
            color: b.color,
            state: state(n.id),
            minor: FactoryRun.isMinor(n.id),
            keystone: FactoryRun.isKeystone(n.id),
            icon: _upgradeIcons[_upgradeKey(n.id)] ?? '⬆️',
            badge: FactoryRun.isMinor(n.id) ? '' : '${FactoryRun.upgradeLevel(f, n.id)}/${FactoryRun.upgrades[n.id]!.max}',
          ),
    ];
    final labels = [
      for (final b in layout)
        (
          pos: Offset(center.dx + cos(b.mid) * (_treeLayout.radius + 55), center.dy - sin(b.mid) * (_treeLayout.radius + 55)),
          text: '${b.icon} ${tr(b.name)} · ${b.ids.fold(0, (n, k) => n + FactoryRun.upgradeLevel(f, k))}/${b.ids.fold(0, (n, k) => n + FactoryRun.upgrades[k]!.max)}',
          color: b.color,
        ),
    ];
    final tree = GestureDetector(
      key: const ValueKey('skill-tree-canvas'),
      onTapUp: (d) {
        final hit = nodes.map((n) => (n.id, (n.pos - d.localPosition).distance)).reduce((a, b) => a.$2 <= b.$2 ? a : b);
        if (hit.$2 <= 34) setState(() => _picked = hit.$1);
      },
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(size, size),
          painter: _TreePainter(nodes: nodes, labels: labels, center: center, radius: _treeLayout.radius, picked: id, spent: '$spent/$all'),
        ),
      ),
    );
    Widget sized(Widget child) => widget.full ? Expanded(child: child) : SizedBox(height: 440, child: child);
    return Column(key: ValueKey(widget.full ? 'skill-tree-full' : 'skill-tree'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      sized(ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: const BoxDecoration(
                gradient: RadialGradient(colors: [Color(0xFF1E1B4B), Color(0xFF0B1020), Color(0xFF05070D)], stops: [0, 0.55, 1])),
            child: LayoutBuilder(builder: (context, box) {
              _fit(box.maxWidth, box.maxHeight);
              return Stack(children: [
                InteractiveViewer(
                  transformationController: _view,
                  constrained: false,
                  minScale: 0.15,
                  maxScale: 2,
                  boundaryMargin: const EdgeInsets.all(300),
                  child: tree,
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Row(children: [
                    for (final (label, by) in [('−', 1 / 1.25), ('+', 1.25)])
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Material(
                          color: const Color(0xFF1E293B),
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: ValueKey('tree-zoom-$label'),
                            customBorder: const CircleBorder(),
                            onTap: () => _zoom(by),
                            child: SizedBox(width: 32, height: 32, child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
                          ),
                        ),
                      ),
                    // Tela cheia (abre a árvore na tela toda; nela, fecha).
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Material(
                        color: const Color(0xFF1E293B),
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: ValueKey(widget.full ? 'tree-full-close' : 'tree-full'),
                          customBorder: const CircleBorder(),
                          onTap: widget.full ? () => Navigator.of(context).pop() : _openFull,
                          child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(widget.full ? Icons.close : Icons.fullscreen, color: Colors.white, size: 20, semanticLabel: tr(widget.full ? 'Fechar' : 'Tela cheia'))),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]);
            }),
          ),
        ),
      ),
      const SizedBox(height: 8),
      // O filtro: o que dá para comprar, um ramo ou o que falta um item (sem procurar na árvore).
      SizedBox(
        height: 34,
        child: ListView(key: const ValueKey('upgrade-filters'), scrollDirection: Axis.horizontal, children: [
          for (final (key, label) in [
            ('buy', '💰 ${tr('Dá para comprar')}'),
            for (final (icon, branch, _) in FactoryRun.upgradeBranches) (branch, '$icon ${tr(branch)}'),
            for (final i in FactoryRun.pieceItems) ('need:$i', '${tr('Falta')} ${pieceInfo[i]!.$1}'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                key: ValueKey('upgrade-filter-$key'),
                visualDensity: VisualDensity.compact,
                label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                selected: _filter == key,
                onSelected: (_) => setState(() => _filter = key),
              ),
            ),
        ]),
      ),
      // Prático: a lista do filtro (do mais barato); tocar leva até ele.
      if (filtered.isNotEmpty) ...[
        SizedBox(
          height: 36,
          child: ListView(key: const ValueKey('upgrade-buyable'), scrollDirection: Axis.horizontal, children: [
            for (final (k, p) in filtered)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  key: ValueKey('buyable-$k'),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                      '${FactoryRun.upgradeNeeds(f, k).isEmpty && p <= coins ? '' : '🔒 '}${_upgradeIcons[_upgradeKey(k)] ?? '⬆️'} ${tr(_upgradeNames[_upgradeKey(k)] ?? k)} · 🪙$p',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () {
                    setState(() => _picked = k);
                    _focus(k);
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
      ],
      // O que a melhoria escolhida faz, o que falta e o botão de comprar.
      Container(
        key: const ValueKey('upgrade-detail'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.card, border: Border.all(color: const Color(0x99FBBF24), width: 2), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(_upgradeIcons[_upgradeKey(id)] ?? '⬆️', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr(_upgradeNames[_upgradeKey(id)] ?? id)}${FactoryRun.isKeystone(id) ? ' · ${tr('nó-chave')}' : FactoryRun.isMinor(id) ? ' · ${tr('nó pequeno')}' : ''}',
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 13)),
              Text(tr(up.label).replaceAll('{0}', '$value'), style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('${'★' * min(level, 10)}${'☆' * min(up.max - level, 10)} · ${price == null ? tr('No máximo') : '🪙 $price${FactoryRun.upgradePieces(f, id) > 0 ? ' · ${pieceInfo[FactoryRun.pieceOf(id)]!.$1} ${FactoryRun.upgradePieces(f, id)}' : ''}'}', style: TextStyle(color: c.muted, fontSize: 12)),
              for (final n in needs) Text('✖ ${needText(n)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
            ]),
          ),
          if (price != null)
            TextButton(
              key: const ValueKey('upgrade-buy'),
              onPressed: coins < price || needs.isNotEmpty
                  ? null
                  : () {
                      final next = FactoryRun.buyUpgrade(f, id);
                      if (next != null) widget.onBuy(next);
                    },
              child: Text(tr('Comprar')),
            ),
        ]),
      ),
    ]);
  }
}

/// A árvore de melhorias na tela toda.
class _FullSkillTree extends StatefulWidget {
  final Json factory;
  final void Function(Json) onBuy;
  const _FullSkillTree({required this.factory, required this.onBuy});

  @override
  State<_FullSkillTree> createState() => _FullSkillTreeState();
}

class _FullSkillTreeState extends State<_FullSkillTree> {
  late Json _factory = widget.factory;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF05070D),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _SkillTree(
              factory: _factory,
              full: true,
              onBuy: (next) {
                setState(() => _factory = next);
                widget.onBuy(next);
              },
            ),
          ),
        ),
      );
}

typedef _TreeNode = ({String id, Offset pos, Offset from, Color color, String state, bool minor, bool keystone, String icon, String badge});

/// A árvore inteira num desenho só: os anéis, as linhas (acesas na cor do ramo quando compradas), o centro, os nomes
/// dos ramos e os nós (comprado: aceso; para comprar: contorno claro; bloqueado: apagado com cadeado; nó-chave dourado).
class _TreePainter extends CustomPainter {
  _TreePainter({required this.nodes, required this.labels, required this.center, required this.radius, required this.picked, required this.spent});
  final List<_TreeNode> nodes;
  final List<({Offset pos, String text, Color color})> labels;
  final Offset center;
  final double radius;
  final String picked, spent;

  /// Os símbolos já medidos (o mesmo emoji em vários nós).
  static final _icons = <String, TextPainter>{};
  static TextPainter _text(String text, double size, {Color color = Colors.white, FontWeight weight = FontWeight.normal}) => _icons.putIfAbsent(
      '$text|$size|${color.toARGB32()}|${weight.value}',
      () => TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: weight)), textDirection: TextDirection.ltr)..layout());

  void _centered(Canvas canvas, TextPainter t, Offset at) => t.paint(canvas, at - Offset(t.width / 2, t.height / 2));

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var k = 1; k <= 5; k++) {
      canvas.drawCircle(center, radius * k / 5, ring);
    }
    for (final n in nodes) {
      final lit = n.state == 'have';
      canvas.drawLine(n.from, n.pos, Paint()
        ..color = lit ? n.color : const Color(0xB3334155)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = lit ? 5 : n.minor ? 2 : 3);
    }
    // O centro: os pontos gastos na árvore toda.
    canvas.drawCircle(center, 54, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(center, 54, Paint()
      ..color = const Color(0xFFFDE047)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    _centered(canvas, _text('⭐', 28), center - const Offset(0, 12));
    _centered(canvas, _text(spent, 14, color: const Color(0xFFFDE047), weight: FontWeight.w900), center + const Offset(0, 22));
    for (final l in labels) {
      final t = TextPainter(
          text: TextSpan(text: l.text, style: TextStyle(color: l.color, fontSize: 30, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Color(0xFF05070D), blurRadius: 6)])),
          textDirection: TextDirection.ltr)
        ..layout();
      _centered(canvas, t, l.pos);
    }
    for (final n in nodes) {
      final sel = n.id == picked;
      final base = n.keystone ? 17.0 : n.minor ? 11.0 : 24.0;
      final r = sel ? base + 4 : base;
      final locked = n.state == 'locked';
      final alpha = locked ? 0.55 : 1.0;
      if (n.state == 'have') canvas.drawCircle(n.pos, r + 7, Paint()..color = n.color.withValues(alpha: 0.25));
      canvas.drawCircle(n.pos, r, Paint()..color = (n.state == 'have' ? n.color : const Color(0xFF111827)).withValues(alpha: alpha));
      final border = sel
          ? const Color(0xFFFDE047)
          : n.keystone
              ? const Color(0xFFF59E0B)
              : locked
                  ? const Color(0xFF334155)
                  : n.state == 'open'
                      ? const Color(0xFFF8FAFC)
                      : n.color;
      canvas.drawCircle(n.pos, r, Paint()
        ..color = border.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 5 : n.keystone ? 4 : n.minor ? 2 : 3);
      _centered(canvas, _text(locked && !n.minor ? '🔒' : n.icon, n.keystone ? 14 : n.minor ? 10 : 19), n.pos);
      // O nível (comprado/máximo), num selo embaixo (só nas melhorias grandes).
      if (n.badge.isNotEmpty) {
        final t = _text(n.badge, 10, weight: FontWeight.w900);
        final box = Rect.fromCenter(center: n.pos + Offset(0, r + 4 + t.height / 2), width: t.width + 10, height: t.height + 2);
        final rr = RRect.fromRectAndRadius(box, const Radius.circular(8));
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF0F172A));
        canvas.drawRRect(rr, Paint()
          ..color = n.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        _centered(canvas, t, box.center);
      }
    }
  }

  @override
  bool shouldRepaint(_TreePainter old) => old.picked != picked || old.spent != spent || !identical(old.nodes, nodes);
}


/// A caixa de texto da corrida (a mesma da batalha): sempre do mesmo tamanho; o que não cabe vem em partes (tocar passa
/// para a próxima parte, com a setinha ▼ no canto, como nos jogos).
class _PagedText extends StatefulWidget {
  const _PagedText({super.key, required this.children, required this.decoration, required this.style});
  final List<Widget> children;
  final BoxDecoration decoration;
  final TextStyle style;

  @override
  State<_PagedText> createState() => _PagedTextState();
}

class _PagedTextState extends State<_PagedText> {
  final _scroll = ScrollController();
  bool _more = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _check() {
    if (!mounted || !_scroll.hasClients) return;
    final more = _scroll.offset < _scroll.position.maxScrollExtent - 1;
    if (more != _more) setState(() => _more = more);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!_scroll.hasClients || !_more) return;
        // A próxima parte: uma "página" (as linhas inteiras que cabem na caixa).
        final line = MediaQuery.textScalerOf(context).scale(widget.style.fontSize ?? 14) * (widget.style.height ?? 1.25);
        final page = max(line, (_scroll.position.viewportDimension / line).floor() * line);
        _scroll.animateTo(min(_scroll.offset + page, _scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: Curves.easeOut).then((_) => _check());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: widget.decoration,
        child: Stack(children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const NeverScrollableScrollPhysics(),
              child: DefaultTextStyle.merge(style: widget.style, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.children)),
            ),
          ),
          if (_more) Positioned(right: 0, bottom: 0, child: Text('▼', key: const ValueKey('factory-text-more'), style: TextStyle(fontSize: 12, color: widget.style.color))),
        ]),
      ),
    );
  }
}


/// Uma fileira de botões do menu de baixo: fica inteira numa página do [_PagedMenu] (nunca cortada no meio).
class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.child});
  final Widget child;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  _PagedMenuState? _menu;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final menu = context.findAncestorStateOfType<_PagedMenuState>();
    if (menu != _menu) {
      _menu?._rows.remove(this);
      _menu = menu?.._rows.add(this);
    }
  }

  @override
  void dispose() {
    _menu?._rows.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Os botões de baixo da corrida como os da batalha: cada um sempre no mesmo lugar, sem rolar. O que não cabe na
/// caixa vai para a página seguinte (◀ 1/2 ▶ embaixo), com as fileiras ([_MenuRow]) inteiras. Igual ao site.
class _PagedMenu extends StatefulWidget {
  const _PagedMenu({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  State<_PagedMenu> createState() => _PagedMenuState();
}

class _PagedMenuState extends State<_PagedMenu> {
  final _rows = <_MenuRowState>{};
  final _content = GlobalKey();
  List<(double, double)> _pages = const [];
  int _page = 0;
  double _limit = 0;
  static const _nav = 30.0;

  /// Mede as fileiras e divide em páginas que cabem na caixa (o resto fica para a próxima).
  void _measure() {
    if (!mounted) return;
    final content = _content.currentContext?.findRenderObject() as RenderBox?;
    if (content == null || !content.hasSize) return;
    final total = content.size.height;
    // Só as fileiras de dentro (uma fileira que tem outras dentro não conta).
    final parents = {for (final row in _rows) row.context.findAncestorStateOfType<_MenuRowState>()};
    final rows = <(double, double)>[
      for (final row in _rows)
        if (!parents.contains(row) && row.mounted)
          if (row.context.findRenderObject() case final RenderBox box when box.attached && box.hasSize)
            () {
            final top = box.localToGlobal(Offset.zero, ancestor: content).dy;
            return (top, top + box.size.height);
          }(),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final pages = <(double, double)>[];
    if (total <= _limit + _nav + 0.5 || rows.isEmpty) {
      pages.add((0, total));
    } else {
      var start = 0.0, end = 0.0;
      for (final (top, bottom) in rows) {
        if (bottom - start > _limit + 0.5 && end > start) {
          pages.add((start, end));
          start = top;
        }
        end = max(end, bottom);
      }
      pages.add((start, max(end, start)));
    }
    bool same(List<(double, double)> a, List<(double, double)> b) =>
        a.length == b.length && [for (var i = 0; i < a.length; i++) (a[i].$1 - b[i].$1).abs() < 0.5 && (a[i].$2 - b[i].$2).abs() < 0.5].every((x) => x);
    if (!same(pages, _pages)) setState(() => _pages = pages);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return LayoutBuilder(builder: (context, box) {
      _limit = box.maxHeight - _nav;
      final paged = _pages.length > 1;
      final page = paged ? _pages[min(_page, _pages.length - 1)] : null;
      final content = KeyedSubtree(key: _content, child: widget.child);
      final arrow = TextStyle(color: widget.color, fontWeight: FontWeight.w900, fontSize: 16);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Só a página de agora (o resto fica cortado e não dá para tocar).
        SizedBox(
          height: page == null ? box.maxHeight : min(page.$2 - page.$1, _limit),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Transform.translate(offset: Offset(0, -(page?.$1 ?? 0)), child: content),
            ),
          ),
        ),
        if (paged) ...[
          const Spacer(),
          SizedBox(
            height: _nav,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: tr('Página anterior'), 
                key: const ValueKey('factory-menu-prev'),
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                padding: EdgeInsets.zero,
                icon: Text('◀', style: arrow.copyWith(color: _page > 0 ? widget.color : widget.color.withValues(alpha: 0.3))),
              ),
              Text('${min(_page, _pages.length - 1) + 1}/${_pages.length}', key: const ValueKey('factory-menu-page'), style: arrow.copyWith(fontSize: 12)),
              IconButton(tooltip: tr('Próxima página'), 
                key: const ValueKey('factory-menu-next'),
                onPressed: _page < _pages.length - 1 ? () => setState(() => _page++) : null,
                padding: EdgeInsets.zero,
                icon: Text('▶', style: arrow.copyWith(color: _page < _pages.length - 1 ? widget.color : widget.color.withValues(alpha: 0.3))),
              ),
            ]),
          ),
        ],
      ]);
    });
  }
}

/// O PC do Centro Pokémon (Pokelike), como nos jogos: à esquerda o seu time (só os sprites), à direita a caixa de 6×6
/// (com nome; ◀ ▶ troca de caixa). Arraste um Pokémon para outra vaga: com alguém nela, pergunta se quer trocar (com os
/// dois nomes); vazia, ele vai para lá. Segurando em cima de ◀ ▶ durante o arrasto, muda de caixa. Tocar num e depois
/// em outra vaga também funciona. Igual ao site (PcPanel.jsx).
class _PcPanel extends StatefulWidget {
  const _PcPanel({super.key, required this.run, required this.data, required this.nameOf, required this.onSave});
  final Json run;
  final FactoryData data;
  final String Function(Object? id) nameOf;
  final void Function(Json next) onSave;

  @override
  State<_PcPanel> createState() => _PcPanelState();
}

typedef _PcLoc = ({String where, int index});

/// O fundo de cada caixa (como nos jogos). Igual ao site.
const _wallColors = {
  'classic': [Color(0xFF2B8A9E), Color(0xFF1F6F80)],
  'forest': [Color(0xFF4D9A4F), Color(0xFF2F6B33)],
  'cave': [Color(0xFF8A6A4C), Color(0xFF5A4330)],
  'sea': [Color(0xFF3A7FD1), Color(0xFF1F4F99)],
  'desert': [Color(0xFFE0B765), Color(0xFFB8873A)],
  'snow': [Color(0xFFB9D9EF), Color(0xFF7FA9CC)],
  'volcano': [Color(0xFFC9502F), Color(0xFF7D2A18)],
  'night': [Color(0xFF4B3C8F), Color(0xFF251C52)],
};

/// O nome do golpe ou do item como no jogo (inglês, sem traduzir).
String _prettySlug(Object? slug) => '${slug ?? ''}'.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

class _PcPanelState extends State<_PcPanel> {
  int _box = 0;
  _PcLoc? _picked;
  Timer? _nav;

  Json get run => widget.run;

  /// O memorial do Nuzlocke: uma página a mais, depois das caixas (só para ver).
  List get _memorial => (run['memorial'] as List?) ?? const [];
  int get _pages => FactoryRun.pcBoxes + (_memorial.isEmpty ? 0 : 1);
  bool get _inMemorial => _box >= FactoryRun.pcBoxes;
  String _label(Map m) => (m['nick'] as String?) ?? widget.nameOf(m['id']);

  @override
  void dispose() {
    _nav?.cancel();
    super.dispose();
  }

  Json? _monAt(_PcLoc l) {
    if (l.where == 'team') {
      final team = FactoryRun.teamOf(run);
      return l.index < team.length ? team[l.index] : null;
    }
    return FactoryRun.pcSlots(run)[l.index];
  }

  /// Soltou (ou tocou no destino): com alguém lá, pergunta; vazia, já move.
  Future<void> _drop(_PcLoc from, _PcLoc to) async {
    if (from == to) return;
    final a = _monAt(from), b = _monAt(to);
    if (a == null) return;
    if (b != null) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('pc-ask'),
          content: Text(tr('Trocar {0} por {1}?').replaceAll('{0}', _label(a)).replaceAll('{1}', _label(b)),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            TextButton(key: const ValueKey('pc-ask-no'), onPressed: () => Navigator.pop(context, false), child: Text(tr('NÃO'))),
            FilledButton(key: const ValueKey('pc-ask-yes'), onPressed: () => Navigator.pop(context, true), child: Text(tr('SIM'))),
          ],
        ),
      );
      if (yes != true) return;
    }
    final next = FactoryRun.pcMove(run, from, to);
    if (next != null) widget.onSave(next);
  }

  void _tap(_PcLoc l) {
    final picked = _picked;
    if (picked != null && picked != l) {
      setState(() => _picked = null);
      _drop(picked, l);
    } else if (_monAt(l) != null) {
      setState(() => _picked = picked == l ? null : l);
    }
  }

  Widget _cell(_PcLoc l, {bool small = false}) {
    final mon = _monAt(l);
    final picked = _picked == l;
    Widget sprite(Json m, {double opacity = 1}) => Opacity(
          opacity: opacity,
          child: PokemonSprite((m['id'] as num).toInt(), shiny: m['shiny'] == true, fill: 0.85),
        );
    return DragTarget<_PcLoc>(
      onWillAcceptWithDetails: (d) => d.data != l,
      onAcceptWithDetails: (d) => _drop(d.data, l),
      builder: (context, candidates, _) {
        final hover = candidates.isNotEmpty;
        final box = Container(
          key: ValueKey('pc-slot-${l.where}-${l.index}'),
          decoration: BoxDecoration(
            color: picked || hover ? const Color(0xAAFDE68A) : mon != null ? const Color(0xCCE0F2FE) : const Color(0x26FFFFFF),
            border: Border.all(color: picked ? const Color(0xFFFBBF24) : const Color(0x660F3D5C), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          // O sprite fica dentro do quadrado (não sai pelas bordas).
          clipBehavior: Clip.hardEdge,
          child: mon == null
              ? null
              : Stack(fit: StackFit.expand, children: [
                  // O Pokémon inteiro no quadrado (num quadrado centralizado, sem cortar).
                  Padding(padding: const EdgeInsets.all(2), child: Center(child: AspectRatio(aspectRatio: 1, child: sprite(mon)))),
                  if (!small)
                    Positioned(right: 2, bottom: 0, child: Text('${mon['level']}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)))),
                ]),
        );
        return GestureDetector(
          onTap: () => _tap(l),
          child: mon == null
              ? box
              : Draggable<_PcLoc>(
                  data: l,
                  feedback: SizedBox(width: 56, height: 56, child: sprite(mon)),
                  childWhenDragging: Opacity(opacity: 0.35, child: box),
                  child: box,
                ),
        );
      },
    );
  }

  /// Quem caiu (Nuzlocke): em cinza, só para ver.
  Widget _memorialCell(int k) {
    final m = k < _memorial.length ? _memorial[k] as Map : null;
    return Container(
      decoration: BoxDecoration(color: const Color(0x33000000), border: Border.all(color: const Color(0x33FFFFFF), width: 2), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.hardEdge,
      child: m == null
          ? null
          : Tooltip(
              message: '${_label(m)} · Nv. ${m['level']} · ${tr('andar')} ${m['floor']}',
              child: Stack(fit: StackFit.expand, children: [
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                        child: PokemonSprite((m['id'] as num).toInt(), shiny: m['shiny'] == true, fill: 0.85),
                      ),
                    ),
                  ),
                ),
                Positioned(right: 2, bottom: 0, child: Text('${m['level']}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white))),
              ]),
            ),
    );
  }

  /// ◀ ▶: tocar muda de caixa; segurando um Pokémon em cima deles, também (como nos jogos).
  Widget _navButton(int step, String label, String key) => DragTarget<_PcLoc>(
        onWillAcceptWithDetails: (_) {
          _nav ??= Timer(const Duration(milliseconds: 500), () {
            _nav = null;
            if (mounted) setState(() => _box = (_box + step + FactoryRun.pcBoxes) % FactoryRun.pcBoxes);
          });
          return false;
        },
        onLeave: (_) {
          _nav?.cancel();
          _nav = null;
        },
        builder: (context, _, __) => _title(label, key: key, onTap: () => setState(() => _box = (_box + step + _pages) % _pages)),
      );

  Widget _title(String text, {String? key, VoidCallback? onTap}) => Material(
        color: const Color(0xFF0F3D44),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: key == null ? null : ValueKey(key),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ),
      );

  Future<void> _nickname() async {
    final at = _picked;
    final mon = at == null ? null : _monAt(at);
    if (at == null || mon == null) return;
    final controller = TextEditingController(text: '${mon['nick'] ?? ''}');
    final nick = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Apelido (vazio tira)')),
        content: TextField(key: const ValueKey('pc-nick-field'), controller: controller, autofocus: true, maxLength: 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('NÃO'))),
          FilledButton(key: const ValueKey('pc-nick-ok'), onPressed: () => Navigator.pop(context, controller.text), child: Text(tr('OK'))),
        ],
      ),
    );
    if (nick != null) widget.onSave(FactoryRun.setNick(run, at, nick));
  }

  /// Os dados de quem foi tocado (sem tirar do PC) e o apelido.
  Widget _info(Json mon) => Container(
        key: const ValueKey('pc-info'),
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E293B), width: 3)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('${mon['shiny'] == true ? '✨ ' : ''}${_label(mon)}${mon['nick'] != null ? ' (${widget.nameOf(mon['id'])})' : ''} · Nv. ${mon['level']}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          Text('${tr('Nature')}: ${mon['nature'] ?? '—'}${mon['item'] != null ? ' · ${_prettySlug(mon['item'])}' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
          if (((mon['moves'] as List?) ?? const []).isNotEmpty)
            Text([for (final m in mon['moves'] as List) _prettySlug(m)].join(' · '), style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(key: const ValueKey('pc-nick'), onPressed: _nickname, child: Text('✏️ ${tr('APELIDO')}')),
            TextButton(onPressed: () => setState(() => _picked = null), child: Text(tr('FECHAR'))),
          ]),
        ]),
      );

  Future<void> _rename() async {
    final controller = TextEditingController(text: FactoryRun.boxName(run, _box));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Nome da caixa')),
        content: TextField(key: const ValueKey('pc-box-name-field'), controller: controller, autofocus: true, maxLength: 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('NÃO'))),
          FilledButton(key: const ValueKey('pc-box-name-ok'), onPressed: () => Navigator.pop(context, controller.text), child: Text(tr('OK'))),
        ],
      ),
    );
    if (name != null) widget.onSave(FactoryRun.renameBox(run, _box, name));
  }

  @override
  Widget build(BuildContext context) {
    final room = FactoryRun.teamRoom(run);
    if (_box >= _pages) _box = 0;
    final info = _picked == null ? null : _monAt(_picked!);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _wallColors[_inMemorial ? 'night' : FactoryRun.boxWall(run, _box)]!, begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: LayoutBuilder(builder: (context, size) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // O seu time: pequeno, só os sprites.
          SizedBox(
            width: size.maxWidth * 0.16,
            child: Column(key: const ValueKey('pc-team'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _title(tr('Time')),
              for (var i = 0; i < room; i++)
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: _cell((where: 'team', index: i), small: true))),
            ]),
          ),
          const SizedBox(width: 6),
          // A caixa: 6×6, com o nome (toque para mudar) e ◀ ▶.
          Expanded(
            child: Column(key: const ValueKey('pc-box'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                _navButton(-1, '◀', 'pc-box-prev'),
                const SizedBox(width: 4),
                Expanded(
                  child: _inMemorial
                      ? _title('🕯️ ${tr('Memorial')}', key: 'pc-box-name')
                      : _title('💻 ${FactoryRun.boxName(run, _box)} ✏️', key: 'pc-box-name', onTap: _rename),
                ),
                if (!_inMemorial) ...[
                  const SizedBox(width: 4),
                  // Ordenar a caixa (Nº da Pokédex, nível ou tipo).
                  PopupMenuButton<String>(
                    key: const ValueKey('pc-box-sort'),
                    tooltip: tr('Ordenar a caixa'),
                    onSelected: (by) => widget.onSave(FactoryRun.sortBox(run, _box, by, widget.data)),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'dex', child: Text(tr('Nº da Pokédex'))),
                      PopupMenuItem(value: 'level', child: Text(tr('Nível'))),
                      PopupMenuItem(value: 'type', child: Text(tr('Tipo'))),
                    ],
                    child: _title('🔃'),
                  ),
                  const SizedBox(width: 4),
                  _title('🎨', key: 'pc-box-wall', onTap: () => widget.onSave(FactoryRun.nextWall(run, _box))),
                ],
                const SizedBox(width: 4),
                _navButton(1, '▶', 'pc-box-next'),
              ]),
              for (var r = 0; r < 6; r++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      for (var c = 0; c < 6; c++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: c == 0 ? 0 : 4),
                            child: _inMemorial ? _memorialCell(r * 6 + c) : _cell((where: 'pc', index: _box * FactoryRun.pcBox + r * 6 + c)),
                          ),
                        ),
                    ]),
                  ),
                ),
              if (info != null)
                _info(info)
              else
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(_inMemorial ? tr('Quem caiu nesta corrida (Nuzlocke).') : tr('Arraste um Pokémon para outra vaga para trocar.'), textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ]);
      }),
    );
  }
}
