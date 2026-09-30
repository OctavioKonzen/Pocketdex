// lib/screens/egg_chain_screen.dart
//
// Cadeia de golpes de ovo (igual ao site, EggChain.jsx): escolhe o filhote e
// um golpe de ovo dele e vê por quais Pokémon passar (lib/services/egg_chain.dart).

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../services/egg_chain.dart';
import '../services/local_database.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/pokemon_sprite.dart';
import 'pokedex_screen.dart';
import 'pokemon_detail_screen.dart';

String _pretty(String slug) => slug.split('-').map((w) => w.capitalise()).join(' ');

class EggChainScreen extends StatefulWidget {
  const EggChainScreen({super.key});

  @override
  State<EggChainScreen> createState() => _EggChainScreenState();
}

class _EggChainScreenState extends State<EggChainScreen> {
  int? _target;
  String _targetName = '';
  List<String>? _moves;
  String? _move;
  List<List<EggLink>>? _chains;
  Map<int, String> _names = {};
  bool _busy = false;

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
    final moves = await EggChains.eggMoves(id);
    setState(() {
      _target = id;
      _targetName = _name(id);
      _moves = moves;
      _move = null;
      _chains = null;
    });
  }

  Future<void> _choose(String move) async {
    setState(() {
      _move = move;
      _chains = null;
      _busy = true;
    });
    final chains = await EggChains.find(_target!, move);
    if (mounted && _move == move) {
      setState(() {
        _chains = chains;
        _busy = false;
      });
    }
  }

  String _how(EggLink l) => switch (l.method) {
        'level-up' => tr('aprende no nível {0}').replaceAll('{0}', '${l.level}'),
        'machine' => tr('aprende por TM'),
        'tutor' => tr('aprende com tutor'),
        _ => tr('recebe de ovo'),
      };

  Widget _node(EggLink l) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: l.id))),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 86,
          child: Column(children: [
            SizedBox.square(dimension: 52, child: PokemonSprite(l.id, fill: 0.95)),
            Text(_name(l.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(_how(l), maxLines: 2, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final moves = _moves;
    final chains = _chains;
    return Scaffold(
      appBar: AppBar(title: const Text('Golpes de ovo')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Escolha o filhote e o golpe de ovo: mostramos por quais Pokémon passar para ele nascer sabendo o golpe.',
                style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 12),
            SiteCard(
              onTap: _pick,
              child: Row(children: [
                SizedBox.square(
                    dimension: 64, child: _target == null ? const Icon(Icons.egg_outlined, size: 40) : PokemonSprite(_target!, fill: 0.95)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(_target == null ? tr('Escolher Pokémon') : _targetName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const Icon(Icons.chevron_right),
              ]),
            ),
            if (moves != null) ...[
              const SizedBox(height: 14),
              if (moves.isEmpty)
                const EmptyMessage('Esse Pokémon não tem golpes de ovo.')
              else ...[
                const Text('Golpes de ovo', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in moves)
                    ChoiceChip(
                      label: Text(_pretty(m)),
                      selected: _move == m,
                      showCheckmark: false,
                      selectedColor: const Color(0xFFEC407A),
                      labelStyle: TextStyle(color: _move == m ? Colors.white : null, fontWeight: FontWeight.w600),
                      onSelected: (_) => _choose(m),
                    ),
                ]),
              ],
            ],
            if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (chains != null) ...[
              const SizedBox(height: 16),
              if (chains.isEmpty)
                const EmptyMessage('Não achamos uma cadeia de até 3 pais para esse golpe.')
              else ...[
                Text(tr('Cadeias para {0} aprender {1}').replaceAll('{0}', _targetName).replaceAll('{1}', _pretty(_move!)),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                for (final chain in chains)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        for (final link in chain) ...[_node(link), const Icon(Icons.arrow_forward, size: 18)],
                        _node(EggLink(_target!, 'egg')),
                      ]),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
