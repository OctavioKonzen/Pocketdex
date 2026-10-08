// lib/screens/factory_panels.dart
//
// As telas da Battle Factory (lib/services/factory_run.dart): o começo
// (escolher o inicial, comprar Pokémon com as moedas, continuar a corrida), o
// que vem depois de vencer um andar (XP, captura, carta de bônus e loja) e a
// batalha de cada andar. Igual ao site (web-site/src/components/FactoryPanels.jsx
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

/// A batalha do andar atual da corrida.
Future<TurnBattle> factoryBattle(Json run) async {
  final mine = <Member>[for (final m in FactoryRun.teamOf(run)) FactoryRun.memberOf(run, m, await _movesFor((m['id'] as num).toInt(), (m['level'] as num).toInt()))];
  final theirs = <Member>[for (final f in FactoryRun.foesOf(run)) FactoryRun.foeMember(f, await _movesFor((f['id'] as num).toInt(), (f['level'] as num).toInt()))];
  final a = await TurnBattleSetup.mons(mine, battleMonName);
  final b = await TurnBattleSetup.mons(theirs, battleMonName);
  if (a.isEmpty || b.isEmpty) throw StateError('Não foi possível montar a batalha do andar.');
  final seed = ((run['seed'] as num).toInt() ^ ((run['floor'] as num).toInt() * 2654435761)) & 0xFFFFFFFF;
  return TurnBattle(a, b, League.seededRandom(seed), startBags: FactoryRun.bagsFor(run))
    ..ai = 'normal'
    ..seed = seed
    ..members = (mine: BattleLog.toRecord(mine), theirs: BattleLog.toRecord(theirs));
}

Widget _mon(BuildContext context, Map m, {bool selected = false, VoidCallback? onTap, Key? key}) {
  final c = SiteColors.of(context);
  return InkWell(
    key: key,
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 74,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? Colors.amber : Colors.transparent, width: 2),
      ),
      child: Column(children: [
        SizedBox(width: 48, height: 48, child: PokemonSprite((m['id'] as num).toInt(), fill: 0.9)),
        if (m['level'] != null) Text('Nv. ${m['level']}', style: TextStyle(fontSize: 11, color: c.muted)),
        if (m['item'] != null) Text(prettySlug('${m['item']}'), style: TextStyle(fontSize: 10, color: c.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

/// O começo: corrida em andamento, ou escolher o inicial; e comprar Pokémon com as moedas.
class FactoryHub extends StatefulWidget {
  final Future<void> Function(Json run) onBattle;
  final bool busy;
  const FactoryHub({super.key, required this.onBattle, this.busy = false});

  @override
  State<FactoryHub> createState() => _FactoryHubState();
}

class _FactoryHubState extends State<FactoryHub> {
  FactoryData? _data;
  int? _pick;
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

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final data = _data;
    if (data == null) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    final factory = currentFactory();
    final run = factory['run'] as Map<String, dynamic>?;
    final owned = [for (final x in factory['owned'] as List) (x as num).toInt()];
    final q = _query.trim().toLowerCase();
    final shopList = ([
      for (final e in data.species.entries)
        if (!data.starters.contains(e.key) && !owned.contains(e.key) && (q.isEmpty || (_names[e.key] ?? '').contains(q)))
          (id: e.key, price: FactoryRun.pokemonPrice(e.value[1]))
    ]..sort((a, b) => a.price != b.price ? a.price.compareTo(b.price) : a.id.compareTo(b.id)))
        .take(24)
        .toList();
    final last = factory['last'] as Map?;
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
              'Escolha um inicial no nível 5 e suba andares: Pokémon selvagens (dá para capturar até 6), treinadores e, raramente, lendários. Cada Pokémon derrotado dá XP e dinheiro. A loja aparece a cada 5 andares (e com 20% de chance nos outros); a cada 10 andares você escolhe uma carta de bônus. Itens, IVs e EVs sem limite. Perdeu: a pontuação vira moedas para comprar Pokémon e começar com eles.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text('${tr('Recorde: andar {0}').replaceAll('{0}', '${factory['best']}')} · 🪙 ${factory['coins']} ${tr('moedas')}',
                style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
            if (last != null && run == null)
              Text(tr('Última corrida: andar {0}, +{1} moedas.').replaceAll('{0}', '${last['floor']}').replaceAll('{1}', '${last['coins']}'),
                  style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        if (run != null) ...[
          Text(tr('Corrida em andamento: andar {0}').replaceAll('{0}', '${run['floor']}') + ' · 💰 ${run['money']}',
              style: TextStyle(fontWeight: FontWeight.w900, color: c.text)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final m in run['team'] as List) _mon(context, m as Map)]),
          if ((run['cards'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${tr('Cartas')}: ${[for (final id in run['cards'] as List) tr(FactoryRun.cards['$id']!.label)].join(' · ')}',
                  style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          if (run['pending'] != null)
            FactoryAfter(run: run, data: data, onNext: widget.onBattle, onChanged: () => setState(() {}))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              PillButton(
                  key: const ValueKey('factory-fight'),
                  label: '⚔️ ${tr('Lutar no andar {0}').replaceAll('{0}', '${run['floor']}')}',
                  onPressed: widget.busy ? null : () => widget.onBattle(run)),
              PillButton(label: tr('Desistir (recebe as moedas)'), color: const Color(0xFF64748B), onPressed: () => _save(FactoryRun.endRun(factory, run))),
            ]),
        ] else ...[
          Text(tr('Escolha o seu inicial'), style: TextStyle(color: c.muted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in FactoryRun.startersOf(factory, data))
              _mon(context, {'id': id}, selected: _pick == id, onTap: () => setState(() => _pick = id), key: ValueKey('starter-$id')),
          ]),
          const SizedBox(height: 8),
          PillButton(
            key: const ValueKey('factory-start'),
            label: '🏭 ${tr('Começar a corrida')}',
            onPressed: widget.busy || _pick == null
                ? null
                : () {
                    final next = FactoryRun.startRun(factory, data, _pick!, Random().nextInt(1 << 31));
                    if (next == null) return;
                    saveFactory({...factory, 'run': next});
                    widget.onBattle(next);
                  },
          ),
        ],
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('🪙 ${tr('Comprar Pokémon com moedas')}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          children: [
            Text(tr('Os mais fortes custam mais. Comprado, ele aparece entre os iniciais (sempre no nível 5).'), style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 6),
            SiteSearchField(hint: 'Buscar Pokémon', onChanged: (t) => setState(() => _query = t)),
            const SizedBox(height: 6),
            for (final p in shopList)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(width: 40, height: 40, child: PokemonSprite(p.id, fill: 0.9)),
                title: Text(battleMonName({'name': _names[p.id] ?? ''}), style: TextStyle(color: c.text)),
                subtitle: Text('🪙 ${p.price}', style: TextStyle(color: c.muted)),
                trailing: TextButton(
                  onPressed: (factory['coins'] as num) < p.price
                      ? null
                      : () {
                          final next = FactoryRun.buyPokemon(factory, data, p.id);
                          if (next != null) _save(next);
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

/// Depois de vencer um andar: XP/níveis, captura, carta e loja; depois o próximo andar.
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

  void _save(Json? next) {
    if (next == null) return;
    saveFactory({...currentFactory(), 'run': next});
    setState(() => _run = next);
    widget.onChanged?.call();
  }

  static String _help(String id) {
    if (id == 'rare-candy') return tr('+1 nível');
    if (FactoryRun.vitamins.containsKey(id)) return tr('+6 pontos no atributo, sem limite');
    if (id == 'bottle-cap') return tr('+3 pontos em todos os atributos, sem limite');
    if (FactoryRun.heldBonus.containsKey(id)) return tr('Segura o item; se já tem um, vira pontos de atributo');
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
    Widget body;
    if (p['capture'] != null) {
      final foe = p['capture'] as Map;
      body = Column(key: const ValueKey('factory-capture'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Capturar {0} (Nv. {1})?').replaceAll('{0}', _name(foe['id'])).replaceAll('{1}', '${foe['level']}'),
            style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
        SizedBox(width: 64, height: 64, child: PokemonSprite((foe['id'] as num).toInt(), fill: 0.9)),
        if (team.length < FactoryRun.maxTeam)
          PillButton(key: const ValueKey('factory-catch'), label: '🔴 ${tr('Capturar')}', onPressed: () => _save(FactoryRun.capture(run)))
        else ...[
          Text(tr('Time cheio: escolha quem sai.'), style: TextStyle(color: c.muted, fontSize: 12)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < team.length; i++) _mon(context, team[i], onTap: () => _save(FactoryRun.capture(run, i)), key: ValueKey('replace-$i')),
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
          Text('🛒 ${tr('Loja')} · 💰 ${run['money']}', key: const ValueKey('factory-shop'), style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
          Text(tr('Para quem é a compra:'), style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < team.length; i++) _mon(context, team[i], selected: _target == i, onTap: () => setState(() => _target = i)),
          ]),
          for (final id in p['shop'] as List)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(prettySlug('$id'), style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
              subtitle: Text(_help('$id'), style: TextStyle(color: c.muted, fontSize: 12)),
              trailing: TextButton(
                onPressed: (run['money'] as num) < FactoryRun.shopPrice(run, '$id')
                    ? null
                    : () => _save(FactoryRun.buyItem(run, '$id', min(_target, team.length - 1), data)),
                child: Text('💰${FactoryRun.shopPrice(run, '$id')}'),
              ),
            ),
        ],
        const SizedBox(height: 6),
        PillButton(
          key: const ValueKey('factory-next'),
          expand: true,
          label: '⚔️ ${tr('Próximo andar ({0})').replaceAll('{0}', '${run['floor']}')}',
          gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
          onPressed: () {
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
          Text('${_name(team[(l['index'] as num).toInt()]['id'])}: Nv. ${l['from']} → ${l['to']}${l['evolved'] != null ? ' · ${tr('evoluiu!')}' : ''}',
              style: TextStyle(color: c.text, fontSize: 13)),
        const SizedBox(height: 8),
        body,
      ]),
    );
  }
}
