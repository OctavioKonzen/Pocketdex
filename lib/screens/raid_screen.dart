// lib/screens/raid_screen.dart
//
// Raid da semana (lib/services/raid.dart): o chefe gigante, a barra do grupo
// (você e seus amigos), quanto cada um já tirou e a luta (até 3 por dia).
// Igual ao site (web-site/src/pages/RaidPage.jsx).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../i18n/text.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/local_database.dart';
import '../services/raid.dart';
import '../services/team_battle.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/pokemon_sprite.dart';
import 'factory_panels.dart' show currentFactory, saveFactory;
import 'turn_battle_screen.dart';

class RaidScreen extends StatefulWidget {
  const RaidScreen({super.key});

  @override
  State<RaidScreen> createState() => _RaidScreenState();
}

class _RaidScreenState extends State<RaidScreen> {
  Map<String, int>? _hits;
  String _boss = '';
  int _team = 0;

  String? get _uid => AuthService.instance.user?.uid;

  @override
  void initState() {
    super.initState();
    _load();
    LocalDatabase.instance.pokemonRow(Raid.bossOf()).then((r) => mounted ? setState(() => _boss = '${r?['name'] ?? ''}') : null);
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return setState(() => _hits = const {});
    final hits = await Raid.hits([uid, for (final f in FriendsService.instance.friends) f.uid]);
    if (mounted) setState(() => _hits = hits);
  }

  void _fight() {
    final teams = UserData.instance.teams;
    final team = _team < teams.length ? BattleTeam.fromMap(teams[_team]) : null;
    final seed = DateTime.now().millisecondsSinceEpoch;
    final mine = team?.members ?? <Member>[for (var i = 0; i < 3; i++) (1 + (seed * (i + 7) % 1025), null)];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TurnBattleScreen(
          mine: mine,
          theirs: [Raid.member()],
          foeName: '🐉 ${tr('Raid')}: ${_name()}',
          onEnd: (b) async {
            final damage = Raid.damageOf(b);
            saveFactory(Raid.afterFight(currentFactory(), damage));
            final uid = _uid;
            if (uid != null && damage > 0) await Raid.addHit(uid, AuthService.instance.user?.name ?? '', damage).catchError((_) {});
            _load();
          },
        ),
      ),
    ).then((_) => mounted ? setState(() {}) : null);
  }

  String _name() => _boss.isEmpty ? '' : '${_boss[0].toUpperCase()}${_boss.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final factory = currentFactory();
    final hits = _hits;
    final total = hits == null ? 0 : hits.values.fold(0, (a, b) => a + b);
    final left = Raid.triesLeft(factory);
    final cleared = total >= Raid.pool;
    final teams = UserData.instance.teams;
    final names = {for (final f in FriendsService.instance.friends) f.uid: f.name, if (_uid != null) _uid!: tr('Você')};
    return Scaffold(
      appBar: AppBar(title: Text('🐉 ${tr('Raid da semana')}')),
      body: ReadableWidth(
        child: ListView(key: const ValueKey('raid'), padding: const EdgeInsets.all(16), children: [
          SiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: SizedBox.square(dimension: 150, child: PokemonSprite(Raid.bossOf(), fill: 0.95))),
              Center(
                  child: m.Text('${_name()} · ${Raid.gimmickOf() == 'dmax' ? 'Dynamax' : 'Tera'} · Nv. 75',
                      style: TextStyle(color: c.text, fontWeight: FontWeight.w900, fontSize: 18))),
              const SizedBox(height: 4),
              Text(tr('Você e seus amigos dividem a vida dele: o dano de todos soma. Quando a barra acaba, cada um pega o prêmio.'),
                  textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  key: const ValueKey('raid-bar'),
                  value: 1 - (total / Raid.pool).clamp(0.0, 1.0),
                  minHeight: 14,
                  color: cleared ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  backgroundColor: c.card,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                  cleared
                      ? '🎉 ${tr('O grupo derrubou o chefe!')}'
                      : tr('Vida do chefe: {0}% de {1}%').replaceAll('{0}', '${(Raid.pool - total).clamp(0, Raid.pool)}').replaceAll('{1}', '${Raid.pool}'),
                  key: const ValueKey('raid-total'),
                  style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 12),
          SiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('⚔️ ${tr('Lutar')}', style: TextStyle(color: c.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              if (teams.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _team,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Seu time')),
                  items: [for (final (i, t) in teams.indexed) DropdownMenuItem(value: i, child: m.Text('${t['name']}'))],
                  onChanged: (v) => setState(() => _team = v ?? 0),
                ),
              const SizedBox(height: 8),
              PillButton(
                key: const ValueKey('raid-fight'),
                label: '🐉 ${tr('Lutar com o chefe')} ($left/${Raid.triesPerDay})',
                color: const Color(0xFFEF4444),
                onPressed: left <= 0 ? null : _fight,
              ),
              if (left <= 0) Text(tr('Volte amanhã para lutar de novo.'), style: TextStyle(color: c.muted, fontSize: 12)),
              if (cleared)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PillButton(
                    key: const ValueKey('raid-claim'),
                    label: Raid.claimed(factory) ? '✓ ${tr('Prêmio pego')}' : '🎁 ${tr('Pegar o prêmio')} (+${Raid.coins} 🪙)',
                    color: const Color(0xFF22C55E),
                    onPressed: Raid.claimed(factory) ? null : () => setState(() => saveFactory(Raid.claim(currentFactory(), total))),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          SiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('👥 ${tr('O grupo')}', style: TextStyle(color: c.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              if (hits == null) const Center(child: CircularProgressIndicator()),
              if (hits != null && hits.isEmpty) Text(tr('Ninguém lutou ainda nesta semana.'), style: TextStyle(color: c.muted, fontSize: 12)),
              if (hits != null)
                for (final e in (hits.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: m.Text(names[e.key] ?? '?', style: TextStyle(color: c.text))),
                      m.Text('${e.value}%', style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                    ]),
                  ),
            ]),
          ),
        ]),
      ),
    );
  }
}
