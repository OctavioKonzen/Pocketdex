// lib/screens/tools/counters_screen.dart
//
// "Quem vence esse Pokémon?" (igual ao site, Counters.jsx): escolhe um
// Pokémon e vê quem ganha dele 1 contra 1 no nível 50, com o melhor golpe de
// cada lado (a mesma conta da batalha de times, lib/services/team_battle.dart).

import 'package:flutter/material.dart' hide Text;

import '../../i18n/i18n.dart';
import '../../i18n/text.dart';
import '../../services/local_database.dart';
import '../../services/team_battle.dart';
import '../../utils/responsive.dart';
import '../../utils/site_ui.dart';
import '../../utils/string_extensions.dart';
import '../../widgets/pokemon_sprite.dart';
import '../pokedex_screen.dart';
import '../pokemon_detail_screen.dart';

class CountersScreen extends StatefulWidget {
  const CountersScreen({super.key});

  @override
  State<CountersScreen> createState() => _CountersScreenState();
}

class _CountersScreenState extends State<CountersScreen> {
  int? _target;
  String _targetName = '';
  bool _legendaries = false;
  double? _progress;
  List<(int, Duel)>? _result;
  Map<int, String> _names = {};
  int _run = 0;

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.defaultPokemon().then((rows) {
      if (mounted) setState(() => _names = {for (final r in rows) r['id'] as int: r['name'] as String});
    });
  }

  String _name(int id) => I18n.pokemonName((_names[id] ?? '#$id').replaceAll('-', ' ').capitalise());

  Future<void> _pick() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
    );
    final id = int.tryParse('${picked?['id']}');
    if (id == null) return;
    final row = await LocalDatabase.instance.pokemonRow(id);
    setState(() {
      _target = id;
      _targetName = I18n.pokemonName(((row?['name'] as String?) ?? '#$id').replaceAll('-', ' ').capitalise());
    });
    _go();
  }

  Future<void> _go() async {
    final target = _target;
    if (target == null) return;
    final run = ++_run;
    setState(() {
      _progress = 0;
      _result = null;
    });
    final result = await TeamBattle.counters(target, legendaries: _legendaries, progress: (p) {
      if (mounted && run == _run) setState(() => _progress = p);
    });
    if (mounted && run == _run) {
      setState(() {
        _result = result;
        _progress = null;
      });
    }
  }

  static String _pct(double x) => '${x.toStringAsFixed(1).replaceAll('.', ',')}%';

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Quem vence?')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Escolha um Pokémon e veja quem ganha dele 1 contra 1 (nível 50, melhor golpe de cada lado).',
                style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 12),
            SiteCard(
              onTap: _pick,
              child: Row(children: [
                SizedBox.square(
                    dimension: 64, child: _target == null ? const Icon(Icons.catching_pokemon, size: 40) : PokemonSprite(_target!, fill: 0.95)),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      Text(_target == null ? tr('Escolher Pokémon') : _targetName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir lendários e míticos'),
              value: _legendaries,
              onChanged: (v) {
                setState(() => _legendaries = v);
                _go();
              },
            ),
            if (_progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text('Calculando os confrontos...', style: TextStyle(color: c.muted, fontSize: 12)),
            ],
            if (result != null && result.isEmpty) const EmptyMessage('Ninguém ganha dele 1 contra 1 nessas condições.'),
            if (result != null && result.isNotEmpty) ...[
              Text(tr('{0} Pokémon ganham do {1}').replaceAll('{0}', '${result.length}').replaceAll('{1}', _targetName),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              for (final (id, d) in result.take(40))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: id))),
                    leading: SizedBox.square(dimension: 48, child: PokemonSprite(id, fill: 0.95)),
                    title: Text(_name(id), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${tr('{0}: {1} por golpe · derrota em {2}').replaceAll('{0}', d.mine.move).replaceAll('{1}', _pct(d.mine.pct)).replaceAll('{2}', tr(d.mine.hits == 1 ? '1 golpe' : '{0} golpes').replaceAll('{0}', '${d.mine.hits}'))}\n'
                      '${d.theirs.hits >= 99 ? tr('Não leva dano dele.') : tr('Aguenta {0}').replaceAll('{0}', tr(d.theirs.hits == 1 ? '1 golpe' : '{0} golpes').replaceAll('{0}', '${d.theirs.hits}'))}',
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
