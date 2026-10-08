// lib/screens/factory_panels.dart
//
// As telas da Battle Factory (lib/services/factory_run.dart): o começo
// (escolher o inicial, comprar Pokémon e shiny com as moedas, continuar a
// corrida), o que vem depois de vencer um andar (XP, Enfermeira Joy, captura
// com Poké Ball, carta de bônus, loja, Bolsa e itens) e a batalha de cada andar. Igual ao site (web-site/src/components/FactoryPanels.jsx
// e web-site/src/lib/factoryBattle.js).

import 'dart:math';

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../services/battle_log.dart';
import '../services/factory_run.dart';
import '../services/league.dart';
import '../services/local_database.dart';
import '../services/team_battle.dart';
import '../services/team_sets.dart';
import '../services/turn_battle.dart';
import '../services/user_data.dart';
import '../utils/site_ui.dart';
import '../widgets/pokemon_sprite.dart';
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
  final battle = TurnBattle(a, b, League.seededRandom(seed), startBags: FactoryRun.bagsFor(run), healPct: true)
    ..ai = 'normal'
    ..seed = seed
    ..members = (mine: BattleLog.toRecord(mine), theirs: BattleLog.toRecord(theirs));
  return (battle, order);
}

/// Como o time terminou a batalha (para winFloor): a parte do HP de cada um, na ordem da corrida, e a Bolsa.
({List<double> hp, Map<String, int> bag}) factoryAfter(TurnBattle battle, List<int> order, Json run) {
  final hp = [for (final m in FactoryRun.teamOf(run)) FactoryRun.hpOf(m)];
  for (var slot = 0; slot < order.length && slot < battle.teams[0].length; slot++) {
    final mon = battle.teams[0][slot];
    hp[order[slot]] = mon.maxHp > 0 ? ((mon.hp < 0 ? 0 : mon.hp) / mon.maxHp * 1000).round() / 1000 : 0;
  }
  return (hp: hp, bag: {for (final id in FactoryRun.bagItems) id: battle.bags[0][id] ?? 0});
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

/// Poké Balls, dinheiro e a Bolsa da corrida.
Widget _runStatus(BuildContext context, Json run) {
  final c = SiteColors.of(context);
  final bag = FactoryRun.bagOf(run);
  final style = TextStyle(fontWeight: FontWeight.bold, color: c.text);
  return Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
    Text('💰 ${run['money']}', style: style),
    Row(mainAxisSize: MainAxisSize.min, children: [_itemIcon('poke-ball', 22), Text('×${run['balls'] ?? 0}', style: style)]),
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
  const _BagAndItems({required this.run, required this.data, required this.names, required this.onSave});

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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (usable.isNotEmpty)
        ExpansionTile(
          key: const ValueKey('factory-bag'),
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
      ExpansionTile(
        key: const ValueKey('factory-items'),
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

/// O começo: corrida em andamento, ou escolher o inicial; e comprar Pokémon (e shiny) com as moedas.
class FactoryHub extends StatefulWidget {
  final Future<void> Function(Json run) onBattle;
  final bool busy;
  const FactoryHub({super.key, required this.onBattle, this.busy = false});

  @override
  State<FactoryHub> createState() => _FactoryHubState();
}

class _FactoryHubState extends State<FactoryHub> {
  FactoryData? _data;
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
    final down = run != null && FactoryRun.teamDown(run);
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
              'Um roguelike sem fim com a história de cada região: escolha um inicial no nível 5 e suba andares contra Pokémon selvagens (capture com Poké Ball: você começa com 5) e treinadores. A cada 10 andares vem um chefe da história: líderes de ginásio, rival e vilões (com times cada vez maiores), a Elite Four e o Campeão; nos andares 5, 15, 25... pode aparecer uma Mega, um Gigantamax ou um lendário. Acabou a história, começa a de outra região. O time não é curado entre os andares (só com a Bolsa, a loja ou, com 5% de chance, a Enfermeira Joy). Sem limite de nível, IVs, EVs ou itens; shiny é 1 em 4096. Perdeu: a pontuação vira moedas para comprar Pokémon e começar com eles.',
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
          if (run['pending'] != null)
            FactoryAfter(run: run, data: data, onNext: widget.onBattle, onChanged: () => setState(() {}))
          else ...[
            _BagAndItems(run: run, data: data, names: _names, onSave: (next) => _save({...factory, 'run': next})),
            if (down)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tr('O time todo está desmaiado: use um Revive ou desista.'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PillButton(
                  key: const ValueKey('factory-fight'),
                  label: '⚔️ ${tr('Lutar no andar {0}').replaceAll('{0}', '${run['floor']}')}',
                  onPressed: widget.busy || down ? null : () => widget.onBattle(run)),
              PillButton(label: tr('Desistir (recebe as moedas)'), color: const Color(0xFF64748B), onPressed: () => _save(FactoryRun.endRun(factory, run))),
            ]),
          ],
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
                    widget.onBattle(next);
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

/// O próximo chefe (a cada 10 andares).
Widget _nextBoss(BuildContext context, FactoryData data, Json run) {
  if (data.bosses.isEmpty) return const SizedBox.shrink();
  final boss = FactoryRun.bossOf(data, run);
  final floor = ((run['floor'] as num).toInt() / FactoryRun.bossEvery).ceil() * FactoryRun.bossEvery;
  final kind = {'gym': tr('Líder de ginásio'), 'rival': tr('Rival'), 'villain': tr('Vilão'), 'elite': tr('Elite Four'), 'champion': tr('Campeão')}[boss['kind']] ?? '';
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text('👑 ${tr('Próximo chefe (andar {0}):').replaceAll('{0}', '$floor')} ${boss['name']} · $kind · ${boss['region']} (${boss['game']})',
        style: TextStyle(color: SiteColors.of(context).muted, fontSize: 12)),
  );
}

/// A loja: os vendedores atrás do balcão.
class _ShopCounter extends StatelessWidget {
  final int money;
  const _ShopCounter({super.key, required this.money});

  @override
  Widget build(BuildContext context) {
    Widget clerk(String id) => Image.asset('assets/database/sprites/trainers/$id.png',
        width: 120, height: 120, fit: BoxFit.contain, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => const SizedBox(width: 120));
    Widget tag(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 13)),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7DD3FC), Color(0xFFE0F2FE)])),
        height: 160,
        child: Stack(children: [
          // Os vendedores atrás do balcão (o balcão cobre a parte de baixo deles).
          Positioned(
            left: 0, right: 0, bottom: 10,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [clerk('sd-clerk'), const SizedBox(width: 4), clerk('sd-clerkf')]),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0, height: 50,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFFBBF24), width: 6)),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD97706), Color(0xFF92400E)]),
              ),
              alignment: Alignment.center,
              child: Text(tr('Bem-vindo! Do que você precisa?'), style: const TextStyle(color: Color(0xFFFFFBEB), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          Positioned(left: 10, top: 6, child: tag('🛒 Poké Mart')),
          Positioned(right: 10, top: 6, child: tag('💰 $money')),
        ]),
      ),
    );
  }
}

/// Depois de vencer um andar: XP/níveis, Enfermeira Joy, captura, carta e loja; depois o próximo andar.
class FactoryAfter extends StatefulWidget {
  final Json run;
  final FactoryData data;
  final Future<void> Function(Json run) onNext;
  final VoidCallback? onChanged;
  const FactoryAfter({super.key, required this.run, required this.data, required this.onNext, this.onChanged});

  @override
  State<FactoryAfter> createState() => _FactoryAfterState();
}

class _FactoryAfterState extends State<FactoryAfter> {
  int _target = 0;
  int? _unlocked;
  late Json _run = widget.run;
  Map<int, String> _names = const {};

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.allPokemonRows().then((rows) {
      if (mounted) setState(() => _names = {for (final r in rows) r['id'] as int: '${r['name']}'});
    });
  }

  @override
  void didUpdateWidget(covariant FactoryAfter old) {
    super.didUpdateWidget(old);
    if (!identical(old.run, widget.run)) _run = widget.run;
  }

  String _name(Object? id) => battleMonName({'name': _names[(id as num?)?.toInt()] ?? ''});

  void _save(Json? next, [Json? meta]) {
    if (next == null) return;
    saveFactory({...(meta ?? currentFactory()), 'run': next});
    setState(() => _run = next);
    widget.onChanged?.call();
  }

  /// Captura; se for um inicial shiny, libera o shiny dele para começar as próximas corridas.
  void _catch(Json run, Map foe, [int? replace]) {
    final next = FactoryRun.capture(run, replace);
    if (identical(next, run)) return;
    final factory = currentFactory();
    final meta = FactoryRun.unlockShiny(factory, widget.data, foe);
    if (!identical(meta, factory)) _unlocked = (foe['id'] as num).toInt();
    _save(next, meta);
  }

  static String _help(String id) {
    if (id.startsWith('tm:')) return tr('Ensina o golpe a quem aprende por TM (uma vez)');
    if (id.startsWith('evo:')) return tr('Evolui na hora quem evolui com ela (escolha acima)');
    if (id == 'move-tutor') return tr('Ensina um golpe de tutor ou de ovo (uma vez)');
    if (id == 'move-reminder') return tr('Lembra um golpe do nível (uma vez)');
    if (id == 'dynamax-band') return tr('Libera o Dynamax (e o Gigantamax) para o time');
    if (id == 'tera-orb') return tr('Libera a Terastalização para o time');
    if (id == 'poke-ball') return tr('Para capturar os selvagens');
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

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final run = _run;
    final p = FactoryRun.pendingOf(run);
    if (p == null) return const SizedBox.shrink();
    final team = FactoryRun.teamOf(run);
    final data = widget.data;
    final balls = ((run['balls'] as num?) ?? 0).toInt();
    final down = FactoryRun.teamDown(run);
    String nameAt(int i) => _name(team[i]['id']);
    Widget body;
    if (p['capture'] != null) {
      final foe = p['capture'] as Map;
      final shiny = foe['shiny'] == true;
      body = Column(key: const ValueKey('factory-capture'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${shiny ? '✨ ' : ''}${tr('Capturar {0} (Nv. {1})?').replaceAll('{0}', _name(foe['id'])).replaceAll('{1}', '${foe['level']}')}',
            style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
        if (shiny) Text(tr('É shiny! (+10% em todos os atributos)'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
        SizedBox(width: 64, height: 64, child: PokemonSprite((foe['id'] as num).toInt(), shiny: shiny, fill: 0.9)),
        if (balls <= 0)
          Text(tr('Sem Poké Balls: compre mais na loja.'), style: TextStyle(color: c.muted))
        else if (team.length < FactoryRun.maxTeam)
          PillButton(key: const ValueKey('factory-catch'), label: '🔴 ${tr('Capturar')} (×$balls)', onPressed: () => _catch(run, foe))
        else ...[
          Text(tr('Time cheio: escolha quem sai.'), style: TextStyle(color: c.muted, fontSize: 12)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < team.length; i++) _mon(context, team[i], name: nameAt(i), onTap: () => _catch(run, foe, i), key: ValueKey('replace-$i')),
          ]),
        ],
        const SizedBox(height: 6),
        PillButton(label: tr('Deixar ir'), color: const Color(0xFF64748B), onPressed: () => _save(FactoryRun.skipCapture(run))),
      ]);
    } else if (p['cards'] != null) {
      body = Column(key: const ValueKey('factory-cards'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('🃏 ${tr('Escolha uma carta de bônus')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
        for (final id in p['cards'] as List)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SiteCard(
              key: ValueKey('card-$id'),
              padding: const EdgeInsets.all(12),
              radius: 14,
              onTap: () => _save(FactoryRun.takeCard(run, '$id', data)),
              child: Text(tr(FactoryRun.cards['$id']!.label), style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
            ),
          ),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (p['shop'] != null) ...[
          _ShopCounter(key: const ValueKey('factory-shop'), money: (run['money'] as num).toInt()),
          const SizedBox(height: 6),
          Text(tr('Para quem é a compra (Poké Ball e itens da Bolsa vão para a Bolsa):'), style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < team.length; i++) _mon(context, team[i], name: nameAt(i), selected: _target == i, onTap: () => setState(() => _target = i)),
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
                        ('$id'.startsWith('evo:') && FactoryRun.canEvolveWith(data, team[min(_target, team.length - 1)], '$id'.substring(4)).isEmpty)
                    ? null
                    : () => _save(FactoryRun.buyItem(run, '$id', min(_target, team.length - 1), data)),
                child: Text('💰${FactoryRun.shopPrice(run, '$id')}'),
              ),
            ),
        ],
        _BagAndItems(run: run, data: data, names: _names, onSave: _save),
        if (down)
          Text(tr('O time todo está desmaiado: use um Revive ou desista.'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        PillButton(
          key: const ValueKey('factory-next'),
          expand: true,
          label: '⚔️ ${tr('Próximo andar ({0})').replaceAll('{0}', '${run['floor']}')}',
          gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
          onPressed: down
              ? null
              : () {
                  final next = FactoryRun.nextFloor(run, data);
                  saveFactory({...currentFactory(), 'run': next});
                  widget.onNext(next);
                },
        ),
      ]);
    }
    return Container(
      key: const ValueKey('factory-after'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🏆 ${tr('Andar vencido!')} +${p['exp']} XP · +💰${p['money']}', style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
        for (final l in (p['levels'] as List? ?? const []))
          Text('${nameAt((l['index'] as num).toInt())}: Nv. ${l['from']} → ${l['to']}${l['evolved'] != null ? ' · ${tr('evoluiu!')}' : ''}',
              style: TextStyle(color: c.text, fontSize: 13)),
        if (p['joy'] == true)
          Container(
            key: const ValueKey('factory-joy'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x26EC4899), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Image.asset('assets/database/sprites/trainers/sd-nurse.png', width: 56, height: 56, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => const SizedBox()),
              const SizedBox(width: 8),
              Expanded(child: Text('💗 ${tr('A Enfermeira Joy apareceu e curou o time todo!')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text))),
            ]),
          ),
        if (p['drop'] != null)
          Container(
            key: const ValueKey('factory-drop'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x2610B981), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _itemIcon('${p['drop']}', 32),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('🎁 ${tr('Ganhou {0}! (está nos itens guardados)').replaceAll('{0}', _itemName('${p['drop']}'))}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: c.text))),
            ]),
          ),
        if (p['story'] != null)
          Container(
            key: const ValueKey('factory-story-end'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x1A6366F1), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final line in '${p['story']}'.split('\n\n')) Text('📖 $line', style: TextStyle(color: c.text, fontSize: 13)),
            ]),
          ),
        if (_unlocked != null)
          Container(
            key: const ValueKey('factory-shiny-unlocked'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x26F59E0B), borderRadius: BorderRadius.circular(12)),
            child: Text('✨ ${tr('{0} shiny liberado para começar as próximas corridas!').replaceAll('{0}', _name(_unlocked))}',
                style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          ),
        const SizedBox(height: 6),
        _runStatus(context, run),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (var i = 0; i < team.length; i++) _mon(context, team[i], name: nameAt(i))]),
        const SizedBox(height: 8),
        body,
      ]),
    );
  }
}
