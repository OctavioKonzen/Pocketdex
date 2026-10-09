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
import '../services/battle_log.dart';
import '../services/factory_run.dart';
import '../services/league.dart';
import '../services/local_database.dart';
import '../services/team_battle.dart';
import '../services/team_sets.dart';
import '../services/trainers.dart';
import '../services/turn_battle.dart';
import '../services/user_data.dart';
import '../utils/site_ui.dart';
import '../widgets/battle_scene.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/trainer_sprite.dart';
import 'turn_battle_screen.dart' show battleMonName;

/// A Factory da conta (meta e corrida).
Json currentFactory() => FactoryRun.of(UserData.instance.league);

/// Salva a Factory na conta.
void saveFactory(Json factory) => UserData.instance.update({'league': {...UserData.instance.league, 'factory': factory}});

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
  final battle = TurnBattle(a, b, League.seededRandom(seed), startBags: FactoryRun.bagsFor(run), healPct: true, capture: FactoryRun.captureFor(run, data))
    ..ai = 'normal'
    ..seed = seed
    ..members = (mine: BattleLog.toRecord(mine), theirs: BattleLog.toRecord(theirs))
    // O cenário: o lugar do andar (cidade, floresta, caverna, mar...).
    ..scene = '${run['encounter']?['scene'] ?? run['encounter']?['biome'] ?? 'grass'}';
  return (battle, order);
}

/// Como o time terminou a batalha (para winFloor): a parte do HP de cada um, na ordem da corrida, a Bolsa e se capturou o selvagem.
({List<double> hp, Map<String, int> bag, bool captured}) factoryAfter(TurnBattle battle, List<int> order, Json run) {
  final hp = [for (final m in FactoryRun.teamOf(run)) FactoryRun.hpOf(m)];
  for (var slot = 0; slot < order.length && slot < battle.teams[0].length; slot++) {
    final mon = battle.teams[0][slot];
    hp[order[slot]] = mon.maxHp > 0 ? ((mon.hp < 0 ? 0 : mon.hp) / mon.maxHp * 1000).round() / 1000 : 0;
  }
  return (hp: hp, bag: {for (final id in FactoryRun.bagItems) id: battle.bags[0][id] ?? 0}, captured: battle.captured != null);
}

/// Quem é o adversário do andar: o chefe (nome, treinador e música) ou um selvagem (sem treinador).
({String foeName, String? foeTrainer, Json challenge}) factoryFoe(Json run) {
  final encounter = run['encounter'] as Map;
  final boss = encounter['boss'] as Map?;
  final kind = encounter['kind'];
  return (
    foeName: '${boss?['name'] ?? ''}',
    foeTrainer: (boss?['trainer'] as String?)?.isNotEmpty == true ? boss!['trainer'] as String : null,
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
  const _BagAndItems({required this.run, required this.data, required this.names, required this.onSave, this.only});

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

  @override
  Widget build(BuildContext context) {
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
                if (team[i]['item'] != null) Chip(label: Text('★ ${_itemName('${team[i]['item']}')}'), backgroundColor: const Color(0x33F59E0B)),
                for (var k = 0; k < ((team[i]['extras'] as List?) ?? const []).length; k++)
                  ActionChip(label: Text(_itemName('${(team[i]['extras'] as List)[k]}')), onPressed: () => widget.onSave(FactoryRun.setMainItem(run, i, k))),
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
    final factory = currentFactory();
    final run = factory['run'] == null ? null : Map<String, dynamic>.from(factory['run'] as Map);
    final owned = [for (final x in factory['owned'] as List) (x as num).toInt()];
    final shinies = FactoryRun.shiniesOf(factory);
    final q = _query.trim().toLowerCase();
    final shopList = ([
      for (final e in data.species.entries)
        if (!owned.contains(e.key) && (q.isEmpty || (_names[e.key] ?? '').contains(q)))
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
            Text('🏭 Battle Factory', style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
            Text(
              'Um roguelike sem fim com a história de cada região: escolha um inicial no nível 5 e siga o mapa de cidade em cidade. Em cada andar você escolhe o caminho: Pokémon selvagem do bioma da rota (capture jogando a bola na batalha, antes de ele desmaiar; cada bola tem a sua chance), treinador, treinador forte (sempre deixa um item), Poké Mart, Centro Pokémon (raro) ou um evento. A cada 10 andares, na cidade, vem um chefe da história: líderes de ginásio, rival e vilões (com times cada vez maiores), a Elite Four e o Campeão; nos andares 5, 15, 25... pode aparecer uma Mega, um Gigantamax ou um lendário. O time não é curado entre os andares (só com a Bolsa, a loja, o Centro Pokémon ou, com 5% de chance, a Enfermeira Joy). Sem limite de nível, IVs, EVs ou itens; shiny é 1 em 4096. Perdeu: a pontuação vira moedas para comprar Pokémon e começar com eles.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text('${tr('Recorde: andar {0}').replaceAll('{0}', '${factory['best']}')} · 🪙 $coins ${tr('moedas')}',
                style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
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
          const SizedBox(height: 8),
          PillButton(
            key: const ValueKey('factory-start'),
            label: '🏭 ${tr('Começar a corrida')}',
            onPressed: widget.busy || _pick == null
                ? null
                : () {
                    final meta = FactoryRun.claimStarter(factory, data, _pick!.id);
                    final next = FactoryRun.startRun(meta, data, _pick!.id, Random().nextInt(1 << 31), _pick!.shiny);
                    if (next == null) return;
                    saveFactory({...meta, 'run': next});
                    widget.onContinue();
                  },
          ),
        ],
        const SizedBox(height: 12),
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
            Text(tr('Os mais fortes custam mais. Comprado, ele aparece entre os iniciais (sempre no nível 5). Tem 1 chance em 4096 de vir shiny.'),
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
};

/// Cada ponto do mapa: símbolo, nome e o que tem nele.
const _nodeInfo = <String, (String, String, String)>{
  'wild': ('🌿', 'Pokémon selvagem', 'Dá para capturar: jogue a bola antes de ele desmaiar.'),
  'trainer': ('🧢', 'Treinador', 'Dinheiro em dobro.'),
  'ace': ('💪', 'Treinador forte', 'Um Pokémon a mais e mais forte; sempre deixa um item.'),
  'mart': ('🛒', 'Poké Mart', 'Uma loja maior (sem batalha, sem XP).'),
  'center': ('🏥', 'Centro Pokémon', 'Cura o time todo, até quem desmaiou (sem batalha).'),
  'event': ('❓', 'Evento', 'Itens, dinheiro, frutas ou uma ficha de Move Tutor (sem batalha).'),
  'wildboss': ('🐉', 'Chefe sem treinador', 'Uma Mega, um Gigantamax ou um lendário. Dá para capturar.'),
  'boss': ('👑', 'Chefe', ''),
};
const _eventText = {
  'items': 'Você achou {1}× {0} no caminho!',
  'money': 'Um treinador perdeu 💰{0} e não voltou para buscar.',
  'berries': 'Frutas no caminho: o time recuperou 30% do HP.',
  'tutor': 'Um velho professor te deu uma ficha de Move Tutor.',
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
    {'gym': tr('Líder de ginásio'), 'rival': tr('Rival'), 'villain': tr('Vilão'), 'elite': tr('Elite Four'), 'champion': tr('Campeão')}[kind] ?? '';

/// O passo da tela depois do andar: o que ainda falta ver ou escolher (ou nada: o mapa). Igual ao site.
String? _stepOf(Map? p) {
  if (p == null) return null;
  if (p['seen'] != true && (p['exp'] != null || p['center'] == true || p['event'] != null)) return 'result';
  if (p['capture'] != null) return 'capture';
  if (p['cards'] != null) return 'cards';
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
      return tr('Segura o item; se já tem um, vira extra ({0})')
          .replaceAll('{0}', [for (final e in boost.entries) '+${(e.value * 100).round()}% ${_statLabel[e.key]}'].join(', '));
    }
    return '';
  }

  // ------------------------------------------------------------ a moldura da batalha

  /// O campo da batalha (as mesmas faixas e as duas bases), nas cores do bioma.
  Widget _field(String biome, List<Widget> Function(double w, double h) children, {Key? key}) => ClipRRect(
        key: key,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: AspectRatio(
          aspectRatio: 16 / 11,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: _border, width: 4)),
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              return Stack(children: [Positioned.fill(child: CustomPaint(painter: BattleScenePainter(scene: biome))), ...children(w, h)]);
            }),
          ),
        ),
      );

  /// Um Pokémon no campo: o seu de costas (embaixo, à esquerda) ou de frente na base de cima.
  Widget _fieldMon(Map mon, double w, double h, {bool back = false}) {
    final sprite = PokemonSprite((mon['id'] as num).toInt(), shiny: mon['shiny'] == true, fill: 0.95, alignBottom: true, back: back);
    return back
        ? Positioned(left: w * 0.06, bottom: h * 0.05, width: w * 0.36, height: w * 0.36, child: sprite)
        : Positioned(right: w * 0.12, bottom: h * 0.53, width: w * 0.26, height: w * 0.26, child: sprite);
  }

  /// Alguém de pé na base de cima (Enfermeira Joy, o chefe, um item...).
  Widget _far(Widget child, double w, double h) =>
      Positioned(right: w * 0.06, bottom: h * 0.53, width: w * 0.36, height: w * 0.36, child: Align(alignment: Alignment.bottomCenter, child: child));

  Widget _trainerImage(String id, double size) => Image.asset('assets/database/sprites/trainers/$id.png',
      height: size, fit: BoxFit.contain, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => const SizedBox());

  /// A barra da corrida (como a do campo na batalha): andar, dinheiro, Bolsa e o time.
  Widget _bar(Json run) {
    final bag = FactoryRun.bagOf(run);
    const style = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      key: const ValueKey('factory-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(color: Color(0xFF334155), border: Border.symmetric(vertical: BorderSide(color: _border, width: 4))),
      child: Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('🏭 ${tr('Andar {0}').replaceAll('{0}', '${run['floor']}')}', style: style),
        Text('💰 ${run['money']}', style: style),
        for (final id in FactoryRun.bagItems)
          if ((bag[id] ?? 0) > 0) Row(mainAxisSize: MainAxisSize.min, children: [_itemIcon(id, 18), Text('×${bag[id]}', style: style)]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final m in FactoryRun.teamOf(run))
            Column(mainAxisSize: MainAxisSize.min, children: [
              Opacity(opacity: FactoryRun.hpOf(m) > 0 ? 1 : 0.4, child: SizedBox(width: 26, height: 26, child: PokemonSprite((m['id'] as num).toInt(), shiny: m['shiny'] == true, fill: 0.9))),
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

  /// Um botão do menu, como os da batalha ("▸ LUTAR"); sub: uma linha menor embaixo.
  Widget _menuButton(String label, VoidCallback? onTap, {String? sub, Key? key, bool active = false}) => Material(
        key: key,
        color: active ? const Color(0xFFFEF3C7) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('▸ $label', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
                if (sub != null && sub.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(left: 12), child: Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600))),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Para quem é a compra (bolas e itens da Bolsa vão para a Bolsa):'), style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < team.length; i++) _mon(context, team[i], name: _name(team[i]['id']), selected: target == i, onTap: () => setState(() => _target = i)),
          ]),
          for (final id in p['shop'] as List)
            ListTile(
              key: ValueKey('shop-$id'),
              contentPadding: EdgeInsets.zero,
              leading: _itemIcon('$id', 32),
              title: Text(_itemName('$id'), style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
              subtitle: Text(FactoryRun.shopOwned(run, '$id') ? tr('Você já tem') : _help('$id'), style: TextStyle(color: c.muted, fontSize: 12)),
              trailing: TextButton(
                key: ValueKey('buy-$id'),
                onPressed: (run['money'] as num) < FactoryRun.shopPrice(run, '$id') ||
                        FactoryRun.shopOwned(run, '$id') ||
                        ('$id'.startsWith('evo:') && FactoryRun.canEvolveWith(data, team[target], '$id'.substring(4)).isEmpty)
                    ? null
                    : () => _save(FactoryRun.buyItem(run, '$id', target, data)),
                child: Text('💰${FactoryRun.shopPrice(run, '$id')}'),
              ),
            ),
        ]);
  }

  /// A moldura: o campo, a barra e a caixa de texto com o menu (igual à batalha).
  Widget _frame({required Widget field, Json? run, required List<Widget> text, Widget? menu}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        field,
        if (run != null) _bar(run),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: _border, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              key: const ValueKey('factory-text'),
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD97706), width: 4), borderRadius: BorderRadius.circular(12)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: text),
              ),
            ),
            if (menu != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF475569), width: 4), borderRadius: BorderRadius.circular(12)),
                child: menu,
              ),
            ],
            // A loja, a Bolsa e o time abrem aqui dentro (a mesma tela).
            if (_framePanel != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('factory-panel'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: SiteColors.of(context).card, border: Border.all(color: const Color(0xFF475569), width: 4), borderRadius: BorderRadius.circular(12)),
                child: _framePanel,
              ),
            ],
          ]),
        ),
      ]);

  Widget _small(String text, {Color color = _ink}) => Text(text, style: TextStyle(fontSize: 13, color: color));

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    final factory = currentFactory();
    if (factory['run'] == null) return _over(factory);
    final run = Map<String, dynamic>.from(factory['run'] as Map);
    final team = FactoryRun.teamOf(run);
    final lead = team.where((m) => FactoryRun.hpOf(m) > 0).firstOrNull ?? team.firstOrNull;
    final p = FactoryRun.pendingOf(run);
    final step = _stepOf(p);
    final tools = [
      _menuButton(tr('BOLSA'), () => setState(() => _panel = _panel == 'bag' ? null : 'bag'), key: const ValueKey('factory-menu-bag'), active: _panel == 'bag'),
      _menuButton(tr('TIME'), () => setState(() => _panel = _panel == 'team' ? null : 'team'), key: const ValueKey('factory-menu-team'), active: _panel == 'team'),
    ];
    Widget frame;
    _framePanel = _panel == 'bag' || _panel == 'team'
        ? _BagAndItems(run: run, data: data, names: _names, onSave: _save, only: _panel)
        : step == 'shop'
            ? _shopList(context, run, p!, data)
            : null;
    if (step == 'result') {
      frame = _resultFrame(run, p!, lead);
    } else if (step == 'capture') {
      frame = _captureFrame(run, p!, lead);
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
    } else if (step == 'shop') {
      frame = _frame(
        run: run,
        field: _field('city', key: const ValueKey('factory-shop'), (w, h) => [
              Positioned(
                left: 0,
                right: 0,
                bottom: h * 0.22,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _trainerImage('sd-clerk', w * 0.34),
                  _trainerImage('sd-clerkf', w * 0.34),
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
          _menuButton(tr('COMPRAR'), () => setState(() => _panel = null), active: _panel == null),
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
    final eventIcon = {'money': '💰', 'berries': '🍒', 'tutor': '📀'}[event?['kind']] ?? '🎁';
    return _frame(
      run: run,
      field: _field(p['center'] == true ? 'center' : '${run['scene'] ?? 'grass'}', key: const ValueKey('factory-result'), (w, h) => [
            if (p['center'] == true || p['joy'] == true)
              _far(_trainerImage('sd-nurse', w * 0.32), w, h)
            else if (items.isNotEmpty)
              _far(_itemIcon(items.first, w * 0.16), w, h)
            else if (event != null)
              _far(Text(eventIcon, style: TextStyle(fontSize: w * 0.12)), w, h),
            if (lead != null) _fieldMon(lead, w, h, back: true),
          ]),
      text: [
        if (p['center'] == true)
          Text('🏥 ${tr('Centro Pokémon: o seu time foi curado!')}', key: const ValueKey('factory-center'))
        else if (event != null)
          Text(
              tr(_eventText['${event['kind']}'] ?? '')
                  .replaceAll('{0}', event['kind'] == 'money' ? '${event['money']}' : _itemName('${event['item'] ?? ''}'))
                  .replaceAll('{1}', '${event['count'] ?? ''}'),
              key: const ValueKey('factory-event'))
        else ...[
          Text('🏆 ${tr('Andar vencido!')} +${p['exp']} XP · +💰${p['money']}'),
          for (final l in (p['levels'] as List? ?? const []))
            if ((l['index'] as num).toInt() < team.length)
              _small('${_name(team[(l['index'] as num).toInt()]['id'])}: Nv. ${l['from']} → ${l['to']}${l['evolved'] != null ? ' · ${tr('evoluiu!')}' : ''}'),
        ],
        if (p['joy'] == true) Text('💗 ${tr('A Enfermeira Joy apareceu e curou o time todo!')}', key: const ValueKey('factory-joy'), style: const TextStyle(fontSize: 13)),
        for (final id in items) Text('🎁 ${tr('Ganhou {0}!').replaceAll('{0}', _itemName(id))}', key: ValueKey('factory-drop-$id'), style: const TextStyle(fontSize: 13)),
        if (p['story'] != null)
          for (final line in '${p['story']}'.split('\n\n')) Text('📖 $line', key: const ValueKey('factory-story-end'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
      menu: _menuButton(tr('CONTINUAR'), () => _save({...run, 'pending': {...p, 'seen': true}}), key: const ValueKey('factory-continue')),
    );
  }

  /// Capturou na batalha: entra no time (com o time cheio, escolhe quem sai ou solta).
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

    return _frame(
      run: run,
      field: _field('${run['scene'] ?? 'grass'}', key: const ValueKey('factory-capture'), (w, h) => [_fieldMon(foe, w, h), if (lead != null) _fieldMon(lead, w, h, back: true)]),
      text: [
        Text('${shiny ? '✨ ' : ''}${tr('Pegou! {0} foi capturado!').replaceAll('{0}', _name(foe['id']))} Nv. ${foe['level']}'),
        if (shiny) _small(tr('É shiny! (+10% em todos os atributos)'), color: const Color(0xFFD97706)),
        if (full) _small(tr('Time cheio: escolha quem sai.')),
      ],
      menu: full
          ? _menuGrid([
              for (var i = 0; i < team.length; i++) _menuButton(_name(team[i]['id']), () => keep(i), sub: 'Nv. ${team[i]['level']}', key: ValueKey('replace-$i')),
              _menuButton(tr('SOLTAR'), () => _save(FactoryRun.skipCapture(run))),
            ])
          : _menuButton(tr('CONTINUAR'), () => keep(), key: const ValueKey('factory-continue')),
    );
  }

  /// O mapa: a rota no campo (da cidade de onde veio até a do chefe; você no andar de agora) e os caminhos no menu.
  Widget _mapFrame(Json run, FactoryData data, Map? lead, List<Widget> tools) {
    final boss = FactoryRun.bossOf(data, run);
    final target = FactoryRun.targetOf(data, run);
    final cities = FactoryRun.routeCities(data, run);
    final route = FactoryRun.routeOf(run)!;
    final options = [for (final o in route['options'] as List) Map<String, dynamic>.from(o as Map)];
    final biome = _biomeInfo[route['biome']] ?? _biomeInfo['grass']!;
    final pos = min(FactoryRun.routeLength, FactoryRun.routePos(run));
    final down = FactoryRun.teamDown(run);
    final meeting = options.length == 1 && options.first['kind'] == 'boss';
    final ambush = meeting && (boss['kind'] == 'rival' || boss['kind'] == 'villain');
    final me = Trainers.mine;
    final coach = Trainers.byId('${boss['trainer'] ?? ''}');
    final region = '${boss['region']}';
    final intro = run['boss']['step'] == 0 && pos == 0 ? FactoryRun.storyLine(data, region, 'intro') : '';
    const end = FactoryRun.routeLength + 1;
    void pick(int k) {
      final next = FactoryRun.chooseNode(run, data, k);
      if (identical(next, run)) return;
      setState(() => saveFactory({...currentFactory(), 'run': next}));
      if (next['encounter'] != null) widget.onBattle(next);
    }

    Widget sign(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
          child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _ink)),
        );
    return _frame(
      run: run,
      field: _field('${route['biome']}', key: const ValueKey('factory-map'), (w, h) {
        double x(int k) => w * (0.08 + k / end * 0.84);
        final y = h * 0.34;
        return [
          Positioned(left: 8, top: 6, right: 8, child: Align(alignment: Alignment.topLeft, child: sign('${boss['region']} · ${boss['game']} · ${biome.$2} ${tr('Rota para {0}').replaceAll('{0}', cities.to)}'))),
          Positioned(left: x(0), width: x(end) - x(0), top: y - 3, height: 6, child: Container(decoration: BoxDecoration(color: const Color(0x998B4513), borderRadius: BorderRadius.circular(3)))),
          // As cidades nas pontas; cada andar da rota é um ponto (os das bifurcações em forma de losango).
          for (var k = 0; k <= end; k++)
            Builder(builder: (context) {
              final city = k == 0 || k == end;
              final fork = !city && FactoryRun.forks.contains(k - 1);
              final size = city ? 18.0 : fork ? 13.0 : 12.0;
              final box = Container(
                decoration: BoxDecoration(
                  shape: fork ? BoxShape.rectangle : BoxShape.circle,
                  border: Border.all(color: _border, width: 2),
                  color: city ? const Color(0xFFFBBF24) : k - 1 < pos ? Colors.white : fork ? const Color(0xFF7DD3FC) : Colors.white54,
                ),
              );
              return Positioned(left: x(k) - size / 2, top: y - size / 2, width: size, height: size, child: fork ? Transform.rotate(angle: pi / 4, child: box) : box);
            }),
          Positioned(left: x(0) - 4, top: y + 10, child: sign('🏠 ${cities.from ?? tr('Início')}')),
          Positioned(right: w - x(end) - 4, top: y + 10, child: sign('👑 ${cities.to}')),
          if (me != null) Positioned(left: x(pos + 1) - w * 0.07, top: y - w * 0.14, child: TrainerSprite(me, box: w * 0.14)),
          if (coach != null && meeting) _far(TrainerSprite(coach, box: w * 0.26), w, h),
          if (lead != null) _fieldMon(lead, w, h, back: true),
        ];
      }),
      text: [
        if (intro.isNotEmpty) _small('📖 $intro'),
        if (ambush) ...[
          Text(tr('{0} apareceu no caminho!').replaceAll('{0}', '${boss['name']}')),
          _small(FactoryRun.storyLine(data, region, '${boss['kind']}', '${boss['name']}')),
        ] else if (meeting) ...[
          Text(tr('O chefe espera')),
          _small(FactoryRun.storyLine(data, region, '${boss['kind']}', '${boss['name']}')),
        ] else
          Text(options.length > 1 ? tr('O caminho se divide: escolha por onde ir') : tr('O caminho segue.')),
        _small('${tr('Chefe em {0}:').replaceAll('{0}', cities.to)} ${target['name']} · ${_bossKind(target['kind'])}', color: const Color(0xFF475569)),
        if (down) _small(tr('O time todo está desmaiado: use um Revive ou desista.'), color: const Color(0xFFDC2626)),
      ],
      menu: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _menuGrid(wide: true, [
          for (var k = 0; k < options.length; k++)
            Builder(builder: (context) {
              final node = options[k];
              final info = _nodeInfo[node['kind']] ?? _nodeInfo['wild']!;
              final b = _biomeInfo[node['biome']];
              final isBoss = node['kind'] == 'boss';
              return _menuButton(
                '${options.length == 1 && !isBoss ? '${tr('SEGUIR')}: ' : ''}${b?.$2 ?? info.$1} ${isBoss ? '${boss['name']}' : tr(info.$2)}${b != null ? ' · ${tr(b.$1)}' : ''}',
                widget.busy || (FactoryRun.isBattleNode(node) && down) ? null : () => pick(k),
                sub: isBoss ? '${_bossKind(boss['kind'])}${ambush ? '' : ' · ${cities.to}'}' : tr(info.$3),
                key: ValueKey('map-node-$k'),
              );
            }),
        ]),
        _menuGrid(tools),
      ]),
    );
  }
}

