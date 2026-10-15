// lib/screens/factory_panels.dart
//
// As telas da Battle Factory (lib/services/factory_run.dart): o começo
// (escolher o inicial, comprar Pokémon e shiny com as moedas, continuar a
// corrida), a corrida em tela cheia no lugar da batalha (FactoryScreen: o
// resultado do andar, o capturado, a carta de bônus, a loja com "Continuar" e
// o mapa com os caminhos de cada andar) e a batalha de cada andar. Igual ao
// site (web-site/src/components/FactoryPanels.jsx e web-site/src/lib/factoryBattle.js).

import 'dart:math';

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../services/account_sync.dart';
import '../services/battle_log.dart';
import '../services/factory_run.dart';
import '../services/league.dart';
import '../services/local_database.dart';
import '../services/team_battle.dart';
import '../services/team_sets.dart';
import '../services/trainers.dart';
import '../services/turn_battle.dart';
import '../services/user_data.dart';
import '../utils/pokemon_colors.dart';
import '../utils/site_ui.dart';
import '../widgets/battle_scene.dart';
import '../widgets/bw_bag.dart';
import '../widgets/bw_party.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/trainer_sprite.dart';
import 'turn_battle_screen.dart' show battleMonName, battleBarHeight, battleBottomHeight;

/// A Factory da conta (meta e corrida).
Json currentFactory() => FactoryRun.of(UserData.instance.league);

/// Salva a Factory na conta.
void saveFactory(Json factory) {
  // Acabou a corrida da semana: o andar vai para o ranking dela (uma vez, com a conta conectada). Igual ao site.
  final last = factory['last'] as Map?;
  if (last?['weekly'] != null && last?['posted'] != true) {
    factory = {...factory, 'last': {...last!, 'posted': true}};
    final floor = (last['floor'] as num?)?.toInt() ?? 0;
    if (floor > 0) AccountSync.instance.saveWeekly('${last['weekly']}', floor, 'factory');
  }
  UserData.instance.update({'league': {...UserData.instance.league, 'factory': factory}});
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
  // Líder de ginásio no ginásio, Elite Four e Campeão na Liga.
  // O líder no ginásio do tipo dele, a Elite Four na Liga, o Campeão na sala dele e o vilão na base da equipe.
  final scene = FactoryRun.bossScene(data, run['encounter']?['boss'] as Map?, '${run['encounter']?['scene'] ?? run['encounter']?['biome'] ?? 'grass'}');
  // E o clima do lugar (sol no deserto, chuva no mar, neve na caverna de gelo...).
  // E o efeito do lugar (terreno, chuva de diamantes, aura sombria...; no céu, ventos fortes).
  final place = FactoryRun.fieldOf(run, scene);
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
      startWeather: FactoryRun.weatherOf(run, scene, FactoryRun.clockOf().season).isNotEmpty
          ? FactoryRun.weatherOf(run, scene, FactoryRun.clockOf().season)
          : (place == 'wind' ? 'wind' : ''),
      startField: place == 'wind' ? '' : place,
      startExp: {
        'mons': [for (final m in expBar.mons) {'level': m.level, 'exp': m.exp}],
        'table': expBar.table,
        'share': expBar.share,
      })
    ..ai = 'normal'
    ..seed = seed
    ..members = (mine: BattleLog.toRecord(mine), theirs: BattleLog.toRecord(theirs))
    ..scene = scene;
  battle.expBar = expBar;
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
({List<double> hp, Map<String, int> bag, bool captured, List<List<int>> fought, List<int>? gained, String? ball}) factoryAfter(TurnBattle battle, List<int> order, Json run) {
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
  return (hp: hp, bag: {for (final id in FactoryRun.bagItems) id: battle.bags[0][id] ?? 0}, captured: battle.captured != null, fought: fought, gained: gained, ball: battle.capturedBall);
}

/// Os capangas de cada equipe vilã (homem e mulher). Igual ao site.
const _gruntTrainers = {
  'rocket': ['sd-rocketgrunt', 'sd-rocketgruntf'], 'aqua': ['sd-aquagrunt', 'sd-aquagruntf'], 'magma': ['sd-magmagrunt', 'sd-magmagruntf'],
  'galactic': ['sd-galacticgrunt', 'sd-galacticgruntf'], 'plasma': ['sd-plasmagrunt', 'sd-plasmagruntf'], 'flare': ['sd-flaregrunt', 'sd-flaregruntf'],
  'skull': ['sd-skullgrunt', 'sd-skullgruntf'], 'aether': ['sd-aetheremployee', 'sd-aetheremployeef'], 'star': ['sd-stargrunt-s', 'sd-stargruntf-s'],
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
                : 'generic:${(encounter['trainerSeed'] as num?)?.toInt() ?? 0}',
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
  'Kanto': Color(0xFFB91C1C), 'Johto': Color(0xFFA16207), 'Hoenn': Color(0xFF15803D), 'Sinnoh': Color(0xFF1D4ED8), 'Unova': Color(0xFF3F3F46),
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
  return ExpansionTile(
    key: const ValueKey('factory-cosmetics'),
    tilePadding: EdgeInsets.zero,
    title: Text('🎨 ${tr('Loja de cosméticos')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
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
    'nuzlocke': 'Nuzlocke: quem desmaia vai embora e só um capturado por rota.',
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
  String? _item;
  int? _stash;

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

  @override
  Widget build(BuildContext context) {
    if (widget.only == 'bag') return _bwBag(context);
    final c = SiteColors.of(context);
    final run = widget.run;
    final team = FactoryRun.teamOf(run);
    final bag = FactoryRun.bagOf(run);
    final usable = [
      for (final id in FactoryRun.bagItems)
        if ((bag[id] ?? 0) > 0 && [for (var i = 0; i < team.length; i++) i].any((i) => FactoryRun.applyBagItem(run, id, i) != null)) id
    ];
    final stash = [for (final x in (run['stash'] as List?) ?? const []) '$x'];
    final canTeach = ((run['tms'] as Map?) ?? const {}).values.any((n) => (n as num) > 0) || ((run['tokens'] as Map?) ?? const {}).values.any((n) => (n as num) > 0);
    final only = widget.only;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (only == 'bag' && usable.isEmpty) Text(tr('Nada da Bolsa para usar agora.'), style: TextStyle(color: c.muted)),
      if (usable.isNotEmpty && only != 'team')
        ExpansionTile(
          key: const ValueKey('factory-bag'),
          initiallyExpanded: only == 'bag',
          tilePadding: EdgeInsets.zero,
          title: Text('🎒 ${tr('Usar a Bolsa')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in usable)
                ChoiceChip(
                  avatar: _itemIcon(id, 20),
                  label: Text('${prettySlug(id)} ×${bag[id]}'),
                  selected: _item == id,
                  onSelected: (_) => setState(() => _item = id),
                ),
            ]),
            if (_item != null) ...[
              const SizedBox(height: 6),
              if (_FactoryScreenState._help(_item!).isNotEmpty) Text(_FactoryScreenState._help(_item!), style: TextStyle(color: c.muted, fontSize: 12)),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < team.length; i++)
                  _mon(context, team[i], name: battleMonName({'name': widget.names[(team[i]['id'] as num).toInt()] ?? ''}),
                      onTap: FactoryRun.applyBagItem(run, _item!, i) == null
                          ? null
                          : () {
                              final next = FactoryRun.applyBagItem(run, _item!, i);
                              setState(() => _item = null);
                              if (next != null) widget.onSave(next);
                            }),
              ]),
            ],
          ],
        ),
      if (only != 'bag')
      ExpansionTile(
        key: const ValueKey('factory-items'),
        initiallyExpanded: only == 'team',
        tilePadding: EdgeInsets.zero,
        title: Text('🧩 ${tr('Time: itens, golpes e mecânicas')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
        children: [
          Text(tr('O principal tem o efeito de verdade; os outros dão só uma porcentagem pequena no atributo. Toque num extra para ele virar o principal.'),
              style: TextStyle(color: c.muted, fontSize: 12)),
          if (stash.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('🎁 ${tr('Itens guardados (toque e escolha quem segura)')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text, fontSize: 12)),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (var k = 0; k < stash.length; k++)
                ChoiceChip(avatar: _itemIcon(stash[k], 20), label: Text(_itemName(stash[k])), selected: _stash == k, onSelected: (_) => setState(() => _stash = k)),
            ]),
            if (_stash != null && _FactoryScreenState._help(stash[_stash!]).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_FactoryScreenState._help(stash[_stash!]), key: const ValueKey('stash-help'), style: TextStyle(color: c.muted, fontSize: 12)),
              ),
            if (_stash != null)
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < team.length; i++)
                  _mon(context, team[i], key: ValueKey('equip-$i'), name: battleMonName({'name': widget.names[(team[i]['id'] as num).toInt()] ?? ''}), onTap: () {
                    final next = FactoryRun.equipFromStash(run, _stash!, i);
                    setState(() => _stash = null);
                    widget.onSave(next);
                  }),
              ]),
          ],
          for (var i = 0; i < team.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 32, height: 32, child: PokemonSprite((team[i]['id'] as num).toInt(), shiny: team[i]['shiny'] == true, fill: 0.9)),
                // Quem abre a batalha (para treinar os mais fracos).
                if (i == 0)
                  Chip(label: Text(tr('Abre a batalha')), backgroundColor: const Color(0x3310B981))
                else
                  ActionChip(key: ValueKey('lead-$i'), label: Text('⬆ ${tr('Primeiro na batalha')}'), onPressed: () => widget.onSave(FactoryRun.setLead(run, i))),
                // O item (principal ★ e extras): tocar no extra o deixa principal; ✕ tira e guarda (para equipar em outro).
                if (team[i]['item'] != null)
                  InputChip(
                    key: ValueKey('unequip-$i'),
                    label: Text('★ ${_itemName('${team[i]['item']}')}'),
                    backgroundColor: const Color(0x33F59E0B),
                    deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                    deleteButtonTooltipMessage: tr('Tirar o item'),
                    onDeleted: () => widget.onSave(FactoryRun.unequipItem(run, i)),
                  ),
                for (var k = 0; k < ((team[i]['extras'] as List?) ?? const []).length; k++)
                  InputChip(
                    key: ValueKey('unequip-$i-$k'),
                    label: Text(_itemName('${(team[i]['extras'] as List)[k]}')),
                    onPressed: () => widget.onSave(FactoryRun.setMainItem(run, i, k)),
                    deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                    deleteButtonTooltipMessage: tr('Tirar o item'),
                    onDeleted: () => widget.onSave(FactoryRun.unequipItem(run, i, k)),
                  ),
                if (FactoryRun.gimmicksOf(widget.data, run, team[i]).isNotEmpty)
                  DropdownButton<String>(
                    value: FactoryRun.gimmickOf(widget.data, run, team[i]).isEmpty ? 'none' : FactoryRun.gimmickOf(widget.data, run, team[i]),
                    items: [
                      DropdownMenuItem(value: 'none', child: Text(tr('Sem mecânica'))),
                      for (final g in FactoryRun.gimmicksOf(widget.data, run, team[i])) DropdownMenuItem(value: g, child: Text(_gimmickLabel[g]!)),
                    ],
                    onChanged: (g) => widget.onSave(FactoryRun.setGimmick(run, i, g ?? 'none')),
                  ),
                if (canTeach) TextButton(key: ValueKey('teach-$i'), onPressed: () => _teach(i), child: Text('📀 ${tr('Ensinar golpe')}')),
                // O que o item principal faz (como nos jogos).
                if (team[i]['item'] != null && _FactoryScreenState._help('${team[i]['item']}').isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: Text('★ ${_FactoryScreenState._help('${team[i]['item']}')}', key: ValueKey('item-help-$i'), style: TextStyle(color: c.muted, fontSize: 11)),
                  ),
              ]),
            ),
        ],
      ),
    ]);
  }
}

/// O começo: corrida em andamento (continuar no mapa), ou escolher o inicial; e comprar Pokémon (e shiny) com as moedas.
class FactoryHub extends StatefulWidget {
  final VoidCallback onContinue;
  final bool busy;
  const FactoryHub({super.key, required this.onContinue, this.busy = false});

  @override
  State<FactoryHub> createState() => _FactoryHubState();
}

class _FactoryHubState extends State<FactoryHub> {
  FactoryData? _data = FactoryData.loaded;
  ({int id, bool shiny})? _pick;

  /// Nuzlocke: quem desmaia vai embora e só um capturado por rota.
  bool _nuzlocke = false;
  int? _lucky;
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
            Text('${tr('Recorde: andar {0}').replaceAll('{0}', '${factory['best']}')} · 🪙 $coins ${tr('moedas')}',
                style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
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
          CheckboxListTile(
            key: const ValueKey('factory-nuzlocke'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _nuzlocke,
            onChanged: (v) => setState(() => _nuzlocke = v ?? false),
            title: Text('🕯️ ${tr('Modo Nuzlocke: quem desmaia vai embora e só um capturado por rota')}', style: TextStyle(color: c.text, fontSize: 13)),
          ),
          PillButton(
            key: const ValueKey('factory-start'),
            label: '🎲 ${tr('Começar a corrida')}',
            onPressed: widget.busy || _pick == null
                ? null
                : () {
                    final meta = FactoryRun.claimStarter(factory, data, _pick!.id);
                    final next = FactoryRun.startRun(meta, data, _pick!.id, Random().nextInt(1 << 31), shiny: _pick!.shiny, nuzlocke: _nuzlocke);
                    if (next == null) return;
                    saveFactory({...meta, 'run': next});
                    widget.onContinue();
                  },
          ),
        ],
        if (run == null) ...[const SizedBox(height: 12), _WeeklyCard(factory: factory, data: data, names: _name, onContinue: widget.onContinue)],
        const SizedBox(height: 12),
        _cosmeticsTile(context, factory, (next) => next == null ? null : setState(() => saveFactory(next))),
        ExpansionTile(
          key: const ValueKey('factory-upgrades'),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: run == null,
          title: Text(
              '⬆️ ${tr('Árvore de melhorias')}  ★ ${FactoryRun.upgrades.keys.fold(0, (n, id) => n + FactoryRun.upgradeLevel(factory, id))}/${FactoryRun.upgrades.values.fold(0, (n, u) => n + u.max)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          children: [
            Text(tr('Compradas com moedas, valem em todas as próximas corridas. Cada ramo começa na raiz; para avançar, a anterior, um andar recorde e Pokémon para começar.'),
                style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 6),
            // A árvore em leque: tocando num círculo, abre o que ele faz e o botão de comprar. Igual ao site.
            _SkillTree(factory: factory, onBuy: _save),
          ],
        ),
        ExpansionTile(
          key: const ValueKey('factory-achievements'),
          tilePadding: EdgeInsets.zero,
          title: Text(
              '🏆 ${tr('Conquistas')} (${((factory['achievements'] as List?) ?? const []).length}/${FactoryRun.achievements.length})',
              style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          children: [
            Text(tr('Cada conquista dá moedas uma vez.'), style: TextStyle(color: c.muted, fontSize: 12)),
            for (final e in FactoryRun.achievements.entries)
              () {
                final done = ((factory['achievements'] as List?) ?? const []).contains(e.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${done ? '🏆' : '🔒'} ${tr(e.value.label)} · 🪙${e.value.coins}',
                      style: TextStyle(color: done ? c.text : c.muted, fontWeight: done ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                );
              }(),
          ],
        ),
        if (((factory['hall'] as List?) ?? const []).isNotEmpty)
          ExpansionTile(
            key: const ValueKey('factory-hall'),
            tilePadding: EdgeInsets.zero,
            title: Text('👑 ${tr('Hall da Fama')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
            children: [
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
            Text(tr('Shiny tem +10% em todos os atributos. Capture um inicial shiny na corrida para liberar o shiny dele, ou transforme com moedas (bem caro).'),
                style: TextStyle(color: c.muted, fontSize: 12)),
            for (final id in owned)
              if (!shinies.contains(id))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(width: 40, height: 40, child: PokemonSprite(id, shiny: true, fill: 0.9)),
                  title: Text('✨ ${_name(id)}', style: TextStyle(color: c.text)),
                  subtitle: Text('🪙 ${FactoryRun.shinyPrice(data.bstOf(id))}', style: TextStyle(color: c.muted)),
                  trailing: TextButton(
                    onPressed: coins < FactoryRun.shinyPrice(data.bstOf(id))
                        ? null
                        : () {
                            final next = FactoryRun.buyShiny(factory, data, id);
                            if (next != null) _save(next);
                          },
                    child: const Text('Comprar'),
                  ),
                ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('🪙 ${tr('Comprar Pokémon com moedas')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          children: [
            Text(tr('Só a primeira forma de cada um (a evolução vem jogando). Os mais fortes custam mais. Comprado, ele aparece entre os iniciais. Tem 1 chance em 4096 de vir shiny.'),
                style: TextStyle(color: c.muted, fontSize: 12)),
            if (FactoryRun.freePick(factory))
              Text(tr('Primeiro escolha o seu inicial grátis.'), style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
            if (_lucky != null)
              Text('✨ ${tr('{0} veio shiny!').replaceAll('{0}', _name(_lucky!))}', style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
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
                          final next = FactoryRun.buyPokemon(factory, data, p.id, Random().nextDouble());
                          if (next == null) return;
                          if (FactoryRun.shiniesOf(next).length > shinies.length) _lucky = p.id;
                          _save(next);
                        },
                  child: const Text('Comprar'),
                ),
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
  'base-star': ('Base da Equipe Estrela', '🏴', Color(0xFFDB2777)),
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
  'trade': ('🔁', 'Troca', 'Alguém da rota troca um Pokémon com você: o que vem chega 3 níveis acima (com o item de quem foi).'),
  'wildboss': ('🐉', 'Chefe sem treinador', 'Uma Mega, um Gigantamax ou um lendário. Dá para capturar.'),
  'meteor': ('☄️', 'Chuva de meteoros', 'Um Clefairy apareceu com os meteoros (mais chance de shiny).'),
  'mythic': ('✨', 'Pokémon mítico', 'Um Pokémon mítico, raríssimo. Dá para capturar.'),
  'boss': ('👑', 'Chefe', ''),
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
  'surf': ('Surf', '🌊', 'Deixa mergulhar no mar (o caminho para o fundo do mar).'),
};
const _cutInfo = ('🌳', 'Caminho escondido', 'Aberto com Cut: um selvagem raro do lugar.');
const _eventText = {
  'items': 'Você achou {1}× {0} no caminho!',
  'money': 'Um treinador perdeu 💰{0} e não voltou para buscar.',
  'berries': 'Frutas no caminho: o time recuperou 30% do HP.',
  'tutor': 'Um velho professor te deu uma ficha de Move Tutor.',
  'declined': 'Você seguiu o seu caminho.',
  'helped': 'O treinador agradeceu e te deu {0}!',
  'secretFound': 'Na caverna secreta: {0} e 💰{1}!',
  'secretEmpty': 'A caverna estava vazia... e escura demais para procurar.',
};
const _eventIcon = {'money': '💰', 'berries': '🍒', 'tutor': '📀', 'declined': '👣', 'helped': '🤝', 'secretFound': '💎', 'secretEmpty': '🕳️'};

/// As escolhas da rota: o ícone, o texto e os botões. Igual ao site.
const _choiceInfo = <String, (String, String, String, String)>{
  'help': ('🙋', 'Um treinador perdeu as Poké Balls e pede ajuda: dar 💰{0} para ele?', 'AJUDAR', 'RECUSAR'),
  'follow': ('🐾', 'Um Pokémon ferido foge para dentro do mato. Seguir ele?', 'SEGUIR', 'DEIXAR'),
  'secret': ('🕳️', 'Uma entrada escondida entre as pedras: entrar na caverna secreta?', 'ENTRAR', 'NÃO ENTRAR'),
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
    {'gym': tr('Líder de ginásio'), 'rival': tr('Rival'), 'villain': tr('Vilão'), 'elite': tr('Elite Four'), 'champion': tr('Campeão')}[kind] ?? '';

/// O passo da tela depois do andar: o que ainda falta ver ou escolher (ou nada: o mapa). Igual ao site.
String? _stepOf(Map? p) {
  if (p == null) return null;
  if (p['choice'] != null) return 'choice';
  if (p['seen'] != true && (p['exp'] != null || p['center'] == true || p['event'] != null)) return 'result';
  if (p['capture'] != null) return 'capture';
  if (p['cards'] != null) return 'cards';
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
  FactoryData? _data = FactoryData.loaded;
  Map<int, String> _names = const {};
  int _target = 0;
  int? _unlocked;

  /// Conquistas novas desta tela (com as moedas).
  final List<String> _earned = [];
  String? _panel; // embaixo do menu: 'bag' | 'team' (na loja, a lista de compras)
  Widget? _framePanel; // o que abre dentro da moldura (lista da loja, Bolsa ou time)

  static const _border = Color(0xFF1E293B);
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
        Align(alignment: Alignment.bottomCenter, child: child),
      ]));

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
        color: const Color(0xFF334155),
        gradient: _data == null
            ? null
            : LinearGradient(colors: [
                _regionTheme['${_data!.bosses[(run['boss']['region'] as num).toInt()]['region']}'] ?? const Color(0xFF334155),
                const Color(0xFF334155),
              ], stops: const [0, 0.7]),
        border: const Border.symmetric(vertical: BorderSide(color: _border, width: 4)),
      ),
      // Uma linha só, da altura da faixa da batalha (rola de lado se não couber): nada muda de tamanho.
      height: battleBarHeight(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final w in <Widget>[
        Text('🎲 ${tr('Andar {0}').replaceAll('{0}', '${run['floor']}')}', style: style),
        Text('💰 ${run['money']}', style: style),
        Text('📖 ${FactoryRun.dexOf(run).length}', key: const ValueKey('factory-dex'), style: style),
        if (_data != null) _badges(_data!, run),
        for (final hm in (run['hms'] as List? ?? const [])) Text(_hmInfo[hm]?.$2 ?? '', style: style),
        if (run['daycare'] != null) const Text('🏡', style: style),
        for (final id in FactoryRun.bagItems)
          if ((bag[id] ?? 0) > 0) Row(mainAxisSize: MainAxisSize.min, children: [_itemIcon(id, 18), Text('×${bag[id]}', style: style)]),
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
          ])
            Padding(padding: const EdgeInsets.only(right: 8), child: w),
        ]),
      ),
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
    return Column(key: const ValueKey('region-map'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _overlayHeader('🗺️ ${game['region']} · ${game['game']}', close),
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
                  Expanded(child: Text(cities[i].city, style: TextStyle(fontWeight: FontWeight.bold, color: done ? c.text : c.muted))),
                  if (here) Text('◀ ${tr('você está indo para cá')}', style: const TextStyle(fontSize: 11, color: Color(0xFF0EA5E9))),
                ]),
              );
            }),
        ]),
      ),
    ]);
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

  /// Os botões em duas colunas (ou um embaixo do outro).
  Widget _menuGrid(List<Widget> items, {bool wide = false}) {
    if (wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final i in items) Padding(padding: const EdgeInsets.only(bottom: 4), child: i)]);
    return Column(children: [
      for (var k = 0; k < items.length; k += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Expanded(child: items[k]),
            const SizedBox(width: 4),
            Expanded(child: k + 1 < items.length ? items[k + 1] : const SizedBox()),
          ]),
        ),
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
                      ('$id'.startsWith('evo:') && FactoryRun.canEvolveWith(data, team[target], '$id'.substring(4)).isEmpty)
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
        gradient: _dark ? const LinearGradient(colors: [Color(0xFF4D4D4D), Color(0xFF2E2E2E)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
        border: Border.all(color: _dark ? const Color(0xFF1A1A1A) : const Color(0xFF334155), width: 3),
        borderRadius: BorderRadius.circular(12),
      );

  /// O título e o "fechar" do que abre por cima do campo.
  Widget _overlayHeader(String title, VoidCallback onClose) => Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(children: [
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          IconButton(
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
              name: _name(m['id']),
              level: (m['level'] as num).toInt(),
              hp: FactoryRun.hpOf(m).toDouble(),
              sub: m['item'] != null ? _itemName('${m['item']}') : null),
      ];

  /// A moldura: o campo, a barra e a caixa de texto com o menu (igual à batalha). A Bolsa, o time, a loja e a troca
  /// abrem por cima do campo (a mesma tela, como no jogo; dá para jogar com o celular de lado).
  Widget _frame({required Widget field, Json? run, required List<Widget> text, Widget? menu}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
            if (_framePanel != null)
              Positioned.fill(
                // A Bolsa, o time e a loja aparecem subindo de leve (sem surgir de uma vez).
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('panel-$_panel'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child)),
                  child: ClipRRect(
                    key: const ValueKey('factory-panel'),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      decoration: BoxDecoration(color: SiteColors.of(context).card, border: Border.all(color: _border, width: 4)),
                      child: SingleChildScrollView(child: _framePanel),
                    ),
                  ),
                ),
              ),
          ]);
        }),
        // A faixa (da altura da faixa da batalha) e a tela de baixo (da altura da tela de baixo da batalha).
        if (run != null)
          _bar(run)
        else
          Container(height: battleBarHeight(context), decoration: const BoxDecoration(color: Color(0xFF334155), border: Border.symmetric(vertical: BorderSide(color: _border, width: 4)))),
        Container(
          key: const ValueKey('factory-bottom'),
          height: battleBottomHeight(context),
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: _border, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
          child: menu == null ? null : SingleChildScrollView(child: Container(padding: const EdgeInsets.all(6), decoration: _dlgBox(), child: menu)),
        ),
      ]);

  Widget _small(String text, {Color? color}) => Text(text, style: TextStyle(fontSize: 13, color: color ?? _dlgText));

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    var factory = currentFactory();
    if (factory['run'] == null) return _over(factory);
    // Conquistas novas (com as moedas) e o Hall da Fama, conforme a corrida anda.
    final (progressed, earned) = FactoryRun.progress(factory, Map<String, dynamic>.from(factory['run'] as Map));
    if (!identical(progressed, factory)) {
      factory = progressed;
      _earned.addAll(earned);
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => saveFactory(progressed)) : null);
    }
    final run = Map<String, dynamic>.from(factory['run'] as Map);
    final team = FactoryRun.teamOf(run);
    final lead = team.where((m) => FactoryRun.hpOf(m) > 0).firstOrNull ?? team.firstOrNull;
    final p = FactoryRun.pendingOf(run);
    final step = _stepOf(p);
    final tools = [
      _menuButton(tr('BOLSA'), () => setState(() => _panel = _panel == 'bag' ? null : 'bag'), key: const ValueKey('factory-menu-bag'), active: _panel == 'bag'),
      _menuButton(tr('TIME'), () => setState(() => _panel = _panel == 'team' ? null : 'team'), key: const ValueKey('factory-menu-team'), active: _panel == 'team'),
      _menuButton('🗺️ ${tr('MAPA DA REGIÃO')}', () => setState(() => _panel = _panel == 'region' ? null : 'region'),
          key: const ValueKey('factory-menu-region'), active: _panel == 'region'),
      _menuButton('❓ ${tr('AJUDA')}', () => setState(() => _panel = _panel == 'help' ? null : 'help'), key: const ValueKey('factory-menu-help'), active: _panel == 'help'),
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
                _overlayHeader('🧩 ${tr('Time: itens, golpes e mecânicas')}', close),
                Padding(padding: const EdgeInsets.all(8), child: _BagAndItems(run: run, data: data, names: _names, onSave: _save, only: 'team')),
              ])
            : step == 'shop' && _panel == 'buy'
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _overlayHeader('${p?['mart'] == true ? '🎒 ${tr('Vendedor ambulante')}' : '🛒 Poké Mart'} · 💰${run['money']}', close),
                    Padding(padding: const EdgeInsets.all(8), child: _shopList(context, run, p!, data)),
                  ])
                // A Creche: um lugar da cidade (separado do Poké Mart).
                : p == null && _panel == 'daycare'
                    ? _daycarePanel(run, data, close)
                    : null;
    if (step == 'result') {
      frame = _resultFrame(run, p!, lead);
    } else if (step == 'choice') {
      frame = _choiceFrame(run, p!, lead, data);
    } else if (step == 'capture') {
      frame = _captureFrame(run, p!, lead);
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
                                border: Border.all(color: _border, width: 3),
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFDE68A), Colors.white]),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Text('🃏', style: TextStyle(fontSize: 26)),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: w * 0.26,
                                      child: Text(tr(FactoryRun.cards['$id']!.label), textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12)),
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
        text: [Text('🃏 ${tr('Escolha uma carta de bônus')}')],
      );
    } else if (step == 'shop' && p!['mart'] == true) {
      // Na rota: o vendedor ambulante (vende o mesmo que o Poké Mart), no próprio lugar: o cenário não muda e não tem
      // as bases da batalha. Igual ao site.
      final scene = '${run['scene'] ?? 'grass'}';
      final me = Trainers.mine;
      frame = _frame(
        run: run,
        field: _field(scene, key: const ValueKey('factory-shop'), (w, h) => [
              _far(_trainerImage('sd-backpacker', w * 0.42), w, h, plain: true),
              if (me != null) Positioned(left: w * 0.1, bottom: h * 0.06, child: TrainerSprite(me, box: w * 0.32)),
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
          ...tools,
          _menuButton(tr('CONTINUAR'), () {
            _panel = null;
            _save({...run, 'pending': {...p, 'shop': null}});
          }, key: const ValueKey('factory-continue')),
        ]),
      );
    } else if (step == 'shop') {
      frame = _frame(
        run: run,
        field: _field('city', key: const ValueKey('factory-shop'), (w, h) => [
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
                  child: const Text('🛒 Poké Mart', style: TextStyle(fontWeight: FontWeight.w900, color: _ink, fontSize: 13)),
                ),
              ),
            ]),
        text: [Text('${tr('Bem-vindo! Do que você precisa?')} 💰${run['money']}')],
        menu: _menuGrid([
          _menuButton(tr('COMPRAR'), () => setState(() => _panel = _panel == 'buy' ? null : 'buy'), active: _panel == 'buy', key: const ValueKey('factory-menu-buy')),
          ...tools,
          _menuButton(tr('CONTINUAR'), () {
            _panel = null;
            _save({...run, 'pending': {...p!, 'shop': null}});
          }, key: const ValueKey('factory-continue')),
        ]),
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

  /// Acabou (perdeu ou desistiu): o andar, as moedas e o recorde.
  Widget _over(Json factory) {
    final last = factory['last'] as Map?;
    return Column(key: const ValueKey('factory-over'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _frame(
        field: _field('over', (w, h) => [const Center(child: Text('🏁', style: TextStyle(fontSize: 64)))]),
        text: [
          Text(tr('A corrida acabou')),
          if (last != null) _small(tr('Andar {0} · +{1} moedas').replaceAll('{0}', '${last['floor']}').replaceAll('{1}', '${last['coins']}')),
          _small('${tr('Recorde: andar {0}').replaceAll('{0}', '${factory['best']}')} · 🪙 ${factory['coins']} ${tr('moedas')}', color: const Color(0xFF64748B)),
        ],
        menu: _menuButton(tr('VOLTAR'), widget.onExit, key: const ValueKey('factory-over-exit')),
      ),
    ]);
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
              _far(_trainerImage(healerSprite, w * 0.42), w, h)
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
                  .replaceAll('{0}', event['kind'] == 'money' ? '${event['money']}' : _itemName('${event['item'] ?? ''}'))
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
        for (final x in (p['picked'] as List? ?? const []))
          Text('🎒 ${tr('{0} achou {1} (Pickup)!').replaceAll('{0}', _name(x['id'])).replaceAll('{1}', _itemName('${x['item']}'))}',
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
      menu: _menuButton(tr('CONTINUAR'), () => _save({...run, 'pending': {...p, 'seen': true}}), key: const ValueKey('factory-continue')),
    );
  }

  /// Capturou na batalha: entra no time (com o time cheio, escolhe quem sai ou solta).
  /// Uma escolha na rota: aceitar ou seguir o caminho. Igual ao site.
  Widget _choiceFrame(Json run, Json p, Map? lead, FactoryData data) {
    final choice = p['choice'] as Map;
    final info = _choiceInfo['${choice['kind']}'] ?? _choiceInfo['help']!;
    final poor = choice['kind'] == 'help' && (run['money'] as num) < ((choice['cost'] as num?) ?? 0);
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
            _far(Text(info.$1, style: TextStyle(fontSize: w * 0.12)), w, h),
            if (lead != null) _fieldMon(lead, w, h, back: true),
          ]),
      text: [
        Text('${info.$1} ${tr(info.$2).replaceAll('{0}', '${choice['cost'] ?? ''}')}', key: ValueKey('factory-choice-${choice['kind']}')),
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
        _small(tr('Quem você der vai embora; o {0} vem {1} níveis acima, com o item de quem foi.')
            .replaceAll('{0}', _name(offer['id']))
            .replaceAll('{1}', '${FactoryRun.tradeLevels}')),
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
    final full = FactoryRun.teamOf(run).length >= FactoryRun.maxTeam;
    if (care == null) {
      return BwParty(
        testKey: 'daycare',
        title: tr('Creche: quem fica? Ganha um nível por andar e, depois de {0} andares, aparece um ovo.').replaceAll('{0}', '${FactoryRun.daycareEgg}'),
        team: _party(run),
        disabled: (_) => FactoryRun.teamOf(run).length < 2,
        onPick: (i) {
          _panel = null;
          _save(FactoryRun.leaveDaycare(run, i));
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
                      ? tr('Tem um ovo esperando por você!')
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

  Widget _captureFrame(Json run, Json p, Map? lead) {
    final team = FactoryRun.teamOf(run);
    final foe = p['capture'] as Map;
    final shiny = foe['shiny'] == true;
    final full = team.length >= FactoryRun.maxTeam;
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
        onPick: keep,
        onCancel: () => _save(FactoryRun.skipCapture(run)),
        cancelLabel: tr('SOLTAR'),
      );
    }
    return _frame(
      run: run,
      // Capturado: ele está dentro da Poké Ball (na base dele), não mais no campo. Do ovo da Creche, ele mesmo. Igual ao site.
      field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-capture'), (w, h) => [
            foe['egg'] == true ? _fieldMon(foe, w, h) : _far(KeyedSubtree(key: const ValueKey('captured-ball'), child: _itemIcon('${p['ball'] ?? 'poke-ball'}', w * 0.08)), w, h),
            if (lead != null) _fieldMon(lead, w, h, back: true),
          ]),
      text: [
        Text('${shiny ? '✨ ' : ''}${tr(foe['egg'] == true ? 'O ovo da Creche chocou: é um {0}!' : 'Pegou! {0} foi capturado!').replaceAll('{0}', _name(foe['id']))} Nv. ${foe['level']}'),
        if (!FactoryRun.dexOf(run).contains((foe['id'] as num).toInt()))
          Builder(builder: (context) {
            final reward = FactoryRun.dexRewardFor(run, (foe['id'] as num).toInt());
            return Text(
                '📖 ${tr('Novo na Pokédex da corrida ({0})').replaceAll('{0}', '${FactoryRun.dexOf(run).length + 1}')}'
                '${reward != null ? ' · 🎁 ${reward['count']}× ${_itemName('${reward['item']}')} +💰${reward['money']}' : ''}',
                key: const ValueKey('factory-dex-new'),
                style: const TextStyle(fontSize: 13));
          }),
        if (shiny) _small(tr('É shiny! (+10% em todos os atributos)'), color: const Color(0xFFD97706)),
        if (full) _small(tr('Time cheio: escolha quem sai.')),
      ],
      menu: full
          ? _menuGrid([_menuButton(tr('SOLTAR'), () => _save(FactoryRun.skipCapture(run)), key: const ValueKey('factory-release'))])
          : _menuButton(tr('CONTINUAR'), () => keep(), key: const ValueKey('factory-continue')),
    );
  }

  /// O mapa: o lugar de agora no campo (o andar, pequeno, num canto) e os caminhos no menu. Na cidade, o ginásio, o
  /// Poké Mart, o Centro, a Creche e o lugar perto dela; dentro de um lugar, os andares dele até o chefe. Igual ao site.
  Widget _mapFrame(Json run, FactoryData data, Map? lead, List<Widget> tools) {
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
    final rival = options.length == 1 && options.first['kind'] == 'rival' ? FactoryRun.rivalBoss(data, run) : null;
    final me = Trainers.mine;
    final coach = Trainers.byId('${(rival ?? boss)['trainer'] ?? ''}');
    final region = '${boss['region']}';
    final intro = run['boss']['step'] == 0 && pos == 0 ? FactoryRun.storyLine(data, region, 'intro') : '';
    final legend = FactoryRun.regionLegend(data, run);
    final clock = FactoryRun.clockOf();
    final mission = run['mission'] as Map?;
    void pick(int k) {
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
      return _menuButton('🕳️ ${(_biomeInfo[node['scene']] ?? biome).$2} ${base ? baseName : placeName(node['place'])}', widget.busy || down || FactoryRun.nodeBlocked(run, node) ? null : () => pick(k),
          sub: FactoryRun.nodeBlocked(run, node)
              ? tr('Precisa da MO Surf (3ª insígnia).')
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
    // O andar (pequeno, num canto): na rota, até a cidade; num lugar, até o chefe dele.
    final floorTag = dungeon != null
        ? '${min(FactoryRun.dungeonLength, FactoryRun.dungeonPos(run) + 1)}/${FactoryRun.dungeonLength}'
        : town
            ? '${min(FactoryRun.cityLength, pos - FactoryRun.routeLength + 1)}/${FactoryRun.cityLength}'
            : '${pos + 1}/${FactoryRun.routeLength}';
    final scene = town
        ? 'city'
        : meeting && _cityKinds.contains(boss['kind'])
            ? FactoryRun.bossScene(data, boss, '${route['biome']}')
            : '${route['biome']}';
    // As falas (uma por vez, tocando para passar, como nos jogos).
    final lines = <String>[
      if (intro.isNotEmpty) '📖 $intro',
      if (!town && dungeon == null && pos == 0 && !meeting)
        '🧭 ${tr('Você sai de {0} e entra em {1}, rumo a {2}.').replaceAll('{0}', cities.from ?? tr('casa')).replaceAll('{1}', tr(biome.$1)).replaceAll('{2}', cities.to)} '
            '${tr(_routeFlavor['${route['biome']}'] ?? _routeFlavor['grass']!)}',
      if (!town && dungeon == null && pos == 0 && !meeting && legend != null)
        '🌟 ${tr(_legendClues[target['kind'] == 'elite' ? _legendClues.length - 1 : min(_legendClues.length - 2, ((run['badges'] as num?) ?? 0).toInt())])}',
      if (dungeon != null && FactoryRun.dungeonPos(run) == 0)
        '🕳️ ${tr('Você entrou em {0}: {1} andares, sem desvios, e um chefe no fim. Depois, de volta para {2}.').replaceAll('{0}', insideName ?? '').replaceAll('{1}', '${FactoryRun.dungeonLength}').replaceAll('{2}', backTo)}',
      if (meeting && boss['kind'] == 'rival') '💬 ${boss['name']}: ${tr(_rivalLines[min(_rivalLines.length - 1, ((run['rivalWins'] as num?) ?? 0).toInt())])}',
      if (meeting && boss['kind'] == 'villain') ...[
        '💬 ${boss['name']}: ${tr(_villainLines[((run['floor'] as num).toInt() + (run['seed'] as num).toInt()) % _villainLines.length])}',
        '💬 ${tr(_villainPlans[FactoryRun.villainTeam(boss['name'])] ?? _villainPlans['rocket']!)}',
      ],
      if (meeting && boss['kind'] == 'gym') '💬 ${boss['name']}: ${tr(_leaderLines[FactoryRun.leaderType(data, boss)] ?? _leaderLines['normal']!)}',
      if (ambush) tr('{0} apareceu no caminho!').replaceAll('{0}', '${boss['name']}'),
      if (meeting && !ambush) tr('O chefe espera'),
      if (meeting) FactoryRun.storyLine(data, region, '${boss['kind']}', '${boss['name']}'),
      if (rival != null) ...[
        '💬 ${rival['name']}: ${tr(_rivalRaceLines[((run['rivalRaces'] as num?) ?? 0).toInt() % _rivalRaceLines.length])}',
        tr('{0} apareceu no caminho!').replaceAll('{0}', '${rival['name']}'),
      ],
      if (options.length == 1 && options.first['meteor'] == true) '☄️ ${tr('Uma chuva de meteoros! Algo caiu bem perto daqui...')}',
      if (options.length == 1 && options.first['mythic'] == true) '✨ ${tr('Uma presença misteriosa... um Pokémon mítico está aqui!')}',
      if (town && boss['kind'] == 'villain') '💬 ${tr('A {0} tomou conta da cidade! O líder do ginásio só volta quando ela for embora.').replaceAll('{0}', teamName)}',
      if (town && pos == FactoryRun.routeLength && boss['kind'] != 'villain')
        tr('Bem-vindo a {0}! O Poké Mart, o Centro Pokémon e a Creche ficam aqui; o líder espera no último andar da cidade.').replaceAll('{0}', cities.to),
      if (dungeon != null && dungeon['cleared'] == true) '🌊 ${tr('Você venceu o chefe daqui! Dá para seguir mais fundo ou voltar.')}',
    ];
    return _frame(
      run: run,
      field: fork && hasMap
          ? _townMap(route, options, pos % FactoryRun.routeLength, cities.from, cities.to, '${boss['region']} · ${boss['game']}', me,
              widget.busy ? null : pick, (node) => (FactoryRun.isBattleNode(node) && down) || FactoryRun.nodeBlocked(run, node), placeName)
          // O líder espera no ginásio da cidade; a Elite Four e o Campeão, na Liga (nunca no meio da rota).
          : _field(scene, key: const ValueKey('factory-map'), (w, h) {
              return [
                Positioned(
                    left: 8,
                    top: 6,
                    right: 48,
                    child: Align(
                        alignment: Alignment.topLeft,
                        child: sign(town
                            ? '🏙️ ${cities.to}'
                            : insideName != null
                                ? '${biome.$2} $insideName'
                                : '${boss['region']} · ${boss['game']} · ${biome.$2} ${routeName != null ? '$routeName → ${cities.to}' : tr('Rota para {0}').replaceAll('{0}', cities.to)}'))),
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
                if (coach != null && (meeting || rival != null)) _far(TrainerSprite(coach, box: w * 0.4), w, h),
                if (town && me != null) Positioned(left: w * 0.35, bottom: h * 0.08, child: TrainerSprite(me, box: w * 0.3)),
                // Quem vai na frente acompanha você na cidade (como o Pokémon que segue o treinador). Igual ao site.
                if (town && lead != null)
                  Positioned(
                      key: const ValueKey('follower'),
                      left: w * 0.57,
                      bottom: h * 0.08,
                      width: w * 0.18,
                      height: w * 0.18,
                      child: PokemonSprite((lead['id'] as num).toInt(), shiny: lead['shiny'] == true, fill: 0.95, alignBottom: true)),
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
            '${tr('Chefe em {0}:').replaceAll('{0}', cities.to)} ${target['name']}',
            key: const ValueKey('factory-clock'),
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
              else
                _menuButton(k == 0 ? '➡️ ${tr('SEGUIR EM FRENTE')}' : '↗️ ${tr('OUTRO CAMINHO')}${options.length > 2 ? ' $k' : ''}',
                  widget.busy || FactoryRun.nodeBlocked(run, options[k]) || (FactoryRun.isBattleNode(options[k]) && down) ? null : () => pick(k),
                  sub: FactoryRun.nodeBlocked(run, options[k])
                      ? tr('Precisa da MO Surf (3ª insígnia).')
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
                        : node['legend'] != null
                            ? _legendInfo
                            : node['cut'] == true
                                ? _cutInfo
                                : _nodeInfo[node['kind']] ?? _nodeInfo['wild']!;
                final b = node['cut'] == true ? null : _biomeInfo[node['biome']];
                final isBoss = node['kind'] == 'boss';
                final foeName = isBoss ? '${boss['name']}' : node['kind'] == 'rival' && rival != null ? '${rival['name']}' : null;
                final noSurf = FactoryRun.nodeBlocked(run, node);
                return _menuButton(
                  '${options.length == 1 && foeName == null && node['kind'] != 'dboss' ? '${tr('SEGUIR')}: ' : ''}${node['biome'] == 'underwater' && route['biome'] != 'underwater' ? '🤿 ${tr('MERGULHAR')}: ' : ''}${town && isBoss ? '🏟️' : b?.$2 ?? info.$1} ${foeName ?? tr(info.$2)}${b != null ? ' · ${tr(b.$1)}' : ''}',
                  widget.busy || (FactoryRun.isBattleNode(node) && down) || noSurf ? null : () => pick(k),
                  sub: noSurf
                      ? tr('Precisa da MO Surf (3ª insígnia).')
                      : isBoss
                          ? '${_bossKind(boss['kind'])}${ambush ? '' : ' · ${cities.to}'}'
                          : node['kind'] == 'dboss'
                              ? dungeon != null
                                  ? tr('O chefe do lugar: vencendo, volta para {0}.').replaceAll('{0}', backTo)
                                  : tr('O chefe da rota: vencendo, você chega em {0}.').replaceAll('{0}', cities.to)
                              : tr(info.$3),
                  key: ValueKey('map-node-$k'),
                );
              }),
          if (cut != null && hasMap)
            _menuButton('✂️ ${tr('USAR {0}').replaceAll('{0}', 'Cut')}', widget.busy ? null : () => _save(cut),
                sub: tr(_hmInfo['cut']!.$3), key: const ValueKey('factory-cut')),
          if (((run['rerolls'] as num?) ?? 0) > 0 && !meeting && !town && hasMap)
            _menuButton('🎲 ${tr('SORTEAR O CAMINHO DE NOVO')}', widget.busy ? null : () => _save(FactoryRun.rerollRoute(run, data)),
                sub: tr('Restam {0} nesta corrida').replaceAll('{0}', '${run['rerolls']}'), key: const ValueKey('factory-reroll')),
        ]),
        // Na cidade: o Poké Mart, o Centro Pokémon e a Creche (cada um no seu lugar). Igual ao site.
        if (town)
          _menuGrid([
            _menuButton('🛒 Poké Mart', widget.busy ? null : () => _save(FactoryRun.townShop(run)), key: const ValueKey('town-mart')),
            _menuButton('🏥 ${tr('CENTRO')}', widget.busy ? null : () => _save(FactoryRun.townCenter(run)), key: const ValueKey('town-center')),
            _menuButton('🏡 ${tr('CRECHE')}', widget.busy ? null : () => setState(() => _panel = _panel == 'daycare' ? null : 'daycare'),
                active: _panel == 'daycare', key: const ValueKey('town-daycare')),
          ]),
        _menuGrid(tools),
      ]),
    );
  }

  /// O mapa da cidade (como o Town Map do Black & White) na bifurcação: a rota da cidade de onde veio até a do chefe,
  /// você no andar de agora e os caminhos abrindo na frente; toque num caminho para ir por ele. Igual ao site (TownMap).
  Widget _townMap(Json route, List<Json> options, int pos, String? from, String to, String title, Trainer? me, void Function(int)? onPick,
      bool Function(Json) blocked, String Function(Object?) placeName) {
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
                          : node['legend'] != null
                              ? _legendInfo
                              : node['cut'] == true
                                  ? _cutInfo
                                  : _nodeInfo[node['kind']] ?? _nodeInfo['wild']!;
                      final b = node['cut'] == true ? null : _biomeInfo[node['biome']];
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
                                Text(tr(info.$2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
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
          _ => tr('Ter {0} Pokémon para começar (tem {1})').replaceAll('{0}', '${n['count']}').replaceAll('{1}', '${((f['owned'] as List?) ?? const []).length}'),
        };
    final spent = ((f['upgrades'] as Map?) ?? const {}).values.fold(0, (n, v) => n + (v as num).toInt());
    final buyable = [
      for (final k in layout.expand((b) => b.ids))
        if (FactoryRun.upgradePrice(f, k) case final p? when p <= coins && FactoryRun.upgradeNeeds(f, k).isEmpty) (k, p),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
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
      // Prático: o que dá para comprar agora (do mais barato), sem procurar na árvore; tocar leva até ele.
      if (buyable.isNotEmpty) ...[
        SizedBox(
          height: 36,
          child: ListView(key: const ValueKey('upgrade-buyable'), scrollDirection: Axis.horizontal, children: [
            Center(child: Text('${tr('Dá para comprar')}: ', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.bold))),
            for (final (k, p) in buyable)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  key: ValueKey('buyable-$k'),
                  visualDensity: VisualDensity.compact,
                  label: Text('${_upgradeIcons[_upgradeKey(k)] ?? '⬆️'} ${tr(_upgradeNames[_upgradeKey(k)] ?? k)} · 🪙$p', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
              Text('${'★' * min(level, 10)}${'☆' * min(up.max - level, 10)} · ${price == null ? tr('No máximo') : '🪙 $price'}', style: TextStyle(color: c.muted, fontSize: 12)),
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
