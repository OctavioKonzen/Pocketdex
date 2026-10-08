// lib/screens/battle_history_screen.dart
//
// Histórico das batalhas contra o computador: vitórias, o seu MVP, cada
// Pokémon e o replay de cada batalha (igual ao site, BattleHistoryPage.jsx).
// O replay refaz a batalha com a mesma semente e as suas jogadas
// (battle_log.dart) e mostra na mesma tela da batalha.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../services/battle_log.dart';
import '../services/damage_calc.dart';
import 'package:share_plus/share_plus.dart';

import '../services/league.dart';
import '../services/replay_link.dart';
import '../services/trainers.dart';
import '../services/turn_battle.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/trainer_sprite.dart';
import 'turn_battle_screen.dart';

class BattleHistoryScreen extends StatelessWidget {
  const BattleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de batalhas')),
      body: ReadableWidth(
        child: ListenableBuilder(
          listenable: UserData.instance,
          builder: (context, _) {
            final battles = UserData.instance.battles;
            final hall = _HallOfFame.shown ? const _HallOfFame() : null;
            if (battles.isEmpty && hall != null) return ListView(padding: const EdgeInsets.all(12), children: [hall]);
            if (battles.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Nenhuma batalha ainda. Batalhe contra o computador e ela aparece aqui.',
                      textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
                ),
              );
            }
            final stats = BattleLog.stats(battles);
            Widget number(String value, String label, [Color? color]) => Expanded(
                  child: Column(children: [
                    Text(value, style: TextStyle(color: color ?? c.text, fontSize: 28, fontWeight: FontWeight.w900)),
                    Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
                  ]),
                );
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ?hall,
                Card(
                  key: const ValueKey('battle-stats'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      number('${stats.battles}', 'Batalhas'),
                      number('${stats.wins}', 'Vitórias', const Color(0xFF22C55E)),
                      number('${stats.rate}%', 'Aproveitamento'),
                    ]),
                  ),
                ),
                if (stats.mons.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Seus Pokémon', style: TextStyle(color: c.text, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          for (final (i, m) in stats.mons.take(12).indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                SizedBox.square(dimension: 40, child: PokemonSprite(m.id, fill: 0.95)),
                                const SizedBox(width: 8),
                                if (i == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(6)),
                                    child: const Text('MVP', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                                  ),
                                const Spacer(),
                                Text('${m.battles} ${tr('batalhas')} · ${m.wins} ${tr('vitórias')} · ${m.kos} ${tr('derrubados')}',
                                    style: TextStyle(color: c.muted, fontSize: 12)),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ),
                for (final b in battles) _BattleTile(b),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Hall da Fama (gym_challenge.dart): cada Liga vencida, com o time campeão.
class _HallOfFame extends StatelessWidget {
  const _HallOfFame();

  static List<(String, int)> get _records => [
        for (final (name, key) in const [('Torre de Batalha', 'tower'), ('Battle Factory', 'factory')])
          if (((UserData.instance.league[key] as Map?)?['best'] as num? ?? 0) > 0) (name, ((UserData.instance.league[key] as Map)['best'] as num).toInt()),
      ];
  static List<Map> get _hall => [for (final h in UserData.instance.league['hall'] as List) if (h is Map) h];
  static bool get shown => _hall.isNotEmpty || _records.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Card(
      key: const ValueKey('hall-of-fame'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏆 ${tr('Hall da Fama')}', style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final h in _hall)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  if (Trainers.byId('${h['trainer']}') case final t?) TrainerSprite(t, box: 48, still: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                          '${tr('Liga de {0}').replaceAll('{0}', '${h['region']}')} · ${DateTime.fromMillisecondsSinceEpoch((h['at'] as num).toInt()).toLocal().toString().substring(0, 10)}',
                          style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 13)),
                      Wrap(children: [
                        for (final id in h['team'] as List) SizedBox.square(dimension: 36, child: PokemonSprite((id as num).toInt(), fill: 0.95)),
                      ]),
                    ]),
                  ),
                ]),
              ),
            for (final (name, best) in _records)
              Text('${tr(name)}: ${tr('recorde de {0} vitórias seguidas').replaceAll('{0}', '$best')}', style: TextStyle(color: c.text, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BattleTile extends StatelessWidget {
  final Map<String, dynamic> record;
  const _BattleTile(this.record);

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final won = record['result'] == 'win';
    final trainer = Trainers.byId(record['foeTrainer'] as String?);
    final foe = (record['foe'] as String?)?.isNotEmpty == true ? record['foe'] as String : trainer?.name ?? tr('Computador');
    final at = DateTime.fromMillisecondsSinceEpoch((record['at'] as num).toInt());
    Widget team(String key) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (final m in (record[key] as List? ?? const []))
            SizedBox.square(
                dimension: 28,
                child: PokemonSprite(((m as Map)['id'] as num).toInt(), shiny: (m['set'] as Map?)?['shiny'] == true, fill: 0.95)),
        ]);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (trainer != null) TrainerSprite(trainer, box: 48, still: true),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(won ? 'Vitória' : 'Derrota',
                        style: TextStyle(color: won ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontWeight: FontWeight.w900)),
                    Text(' · ', style: TextStyle(color: c.muted)),
                    Flexible(child: Text(foe, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontWeight: FontWeight.w800))),
                  ]),
                  Text(
                      '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} · ${record['turns']} ${tr('turnos')}',
                      style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [team('mine'), Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('vs', style: TextStyle(color: c.muted, fontSize: 11))), team('theirs')]),
                  ),
                ],
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (BattleLog.canReplay(record))
                IconButton.filled(
                  key: ValueKey('replay-${record['id']}'),
                  tooltip: tr('Assistir'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReplayScreen(record))),
                  icon: const Icon(Icons.play_arrow),
                ),
              // Link do replay (abre no site, sem conta): replay_link.dart.
              if (BattleLog.canReplay(record))
                IconButton(
                  key: ValueKey('share-${record['id']}'),
                  tooltip: tr('Compartilhar'),
                  onPressed: () => SharePlus.instance.share(
                      ShareParams(text: '${tr('Replay da minha batalha no PocketDex')}\n${ReplayLink.url(ReplayLink.encode(record))}')),
                  icon: Icon(Icons.share, color: c.muted),
                ),
              IconButton(tooltip: tr('Apagar'), onPressed: () => BattleLog.delete(record['id'] as String), icon: Icon(Icons.delete_outline, color: c.muted)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// O replay: refaz a batalha jogada a jogada e mostra na tela da batalha.
class ReplayScreen extends StatefulWidget {
  final Map<String, dynamic> record;
  const ReplayScreen(this.record, {super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  TurnBattle? _battle;
  BattleHit? _hit;
  double Function(String, List<String>)? _typeEff;
  OnlineBattleControl? _control;
  int _step = 0, _round = 0;
  String _error = '';

  Map<String, dynamic> get _r => widget.record;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    try {
      final data = await DamageData.load();
      final a = await TurnBattleSetup.mons(BattleLog.members(_r['mine'] as List), battleMonName);
      final b = await TurnBattleSetup.mons(BattleLog.members(_r['theirs'] as List), battleMonName);
      final seed = (_r['seed'] as num).toInt();
      final battle = TurnBattle(a, b, League.seededRandom(seed))
        ..ai = _r['ai'] as String? ?? 'normal'
        ..seed = seed;
      if (!mounted) return battle.dispose();
      setState(() {
        _hit = TurnBattleSetup.hitter(data);
        _typeEff = TurnBattleSetup.typeEffect(data);
        _battle = battle;
        _show(battle.start());
      });
    } catch (_) {
      if (mounted) setState(() => _error = tr('Não foi possível abrir este replay.'));
    }
  }

  void _show(List<BattleEvent> events, [List<int>? before]) {
    _control = OnlineBattleControl(
      round: ++_round,
      events: events,
      before: before,
      locked: true,
      waitForSwitch: false,
      message: '',
      replay: true,
      onAction: (_) {},
      onClose: () => Navigator.pop(context),
      onPlayed: _next,
    );
  }

  /// A próxima jogada, depois que a anterior terminou de passar na tela.
  void _next() {
    final battle = _battle, hit = _hit;
    final actions = (_r['actions'] as List?) ?? const [];
    if (!mounted || battle == null || hit == null || _step >= actions.length || battle.winner != null) return;
    final a = (actions[_step++] as Map).cast<String, dynamic>();
    final before = [battle.active(0).id, battle.active(1).id];
    try {
      final events = a['replace'] != null
          ? battle.replace((a['replace'] as num).toInt())
          : battle.playTurn(hit,
              move: (a['move'] as num?)?.toInt(),
              gimmick: a['gimmick'] as String?,
              switchTo: (a['switch'] as num?)?.toInt(),
              item: a['item'] as String?,
              target: (a['target'] as num?)?.toInt());
      setState(() => _show(events, before));
    } catch (_) {
      setState(() => _error = tr('O replay não pôde continuar daqui (os dados mudaram desde a batalha).'));
    }
  }

  @override
  void dispose() {
    _battle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    return Scaffold(
      appBar: AppBar(title: const Text('Replay')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error, style: const TextStyle(color: Colors.redAccent))),
            if (battle != null && _control != null)
              BattleView(
                battle: battle,
                hit: _hit!,
                typeEff: _typeEff!,
                foeName: _r['foe'] as String? ?? '',
                foeTrainer: _r['foeTrainer'] as String?,
                online: _control,
                onAgain: () => Navigator.pop(context),
                onExit: () => Navigator.pop(context),
              )
            else if (_error.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
