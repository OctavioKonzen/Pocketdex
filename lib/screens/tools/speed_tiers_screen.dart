// lib/screens/tools/speed_tiers_screen.dart
//
// Faixas de velocidade (igual ao site, SpeedTiers.jsx): todos os Pokémon em
// ordem de Speed no nível 50 ou 100, com o treino escolhido (máximo com
// Nature a favor, máximo neutro, sem EVs, mínimo) e os efeitos de batalha
// (Choice Scarf, Tailwind, +1 e Trick Room, que inverte a ordem).

import 'package:flutter/material.dart' hide Text;

import '../../i18n/i18n.dart';
import '../../i18n/text.dart';
import '../../services/damage_calc.dart';
import '../../services/local_database.dart';
import '../../utils/responsive.dart';
import '../../utils/site_ui.dart';
import '../../utils/string_extensions.dart';
import '../../widgets/pokemon_sprite.dart';
import '../pokemon_detail_screen.dart';

/// Treinos de Speed: (nome, IV, EVs, Nature).
const speedSpreads = [
  ('Máx. com Nature', 31, 252, 1.1),
  ('Máx. neutra', 31, 252, 1.0),
  ('Sem EVs', 31, 0, 1.0),
  ('Mínima', 0, 0, 0.9),
];

/// Speed final: status do nível, depois os multiplicadores (arredondando
/// para baixo a cada passo, como no jogo).
int speedStat(int base, int level, int iv, int ev, double nature, {bool scarf = false, bool boost = false, bool tailwind = false}) {
  var s = (((2 * base + iv + ev ~/ 4) * level ~/ 100) + 5) * nature;
  var v = s.floor();
  if (boost) v = (v * 1.5).floor();
  if (scarf) v = (v * 1.5).floor();
  if (tailwind) v = v * 2;
  return v;
}

class SpeedTiersScreen extends StatefulWidget {
  const SpeedTiersScreen({super.key});

  @override
  State<SpeedTiersScreen> createState() => _SpeedTiersScreenState();
}

class _SpeedTiersScreenState extends State<SpeedTiersScreen> {
  List<(int, String, int, bool)>? _all; // (id, nome, base, totalmente evoluído)
  int _level = 50;
  int _spread = 0;
  bool _scarf = false, _boost = false, _tailwind = false, _trickRoom = false, _finalOnly = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DamageData.load();
    final rows = await LocalDatabase.instance.defaultPokemon();
    final list = [
      for (final r in rows)
        (
          r['id'] as int,
          r['name'] as String,
          ((r['stats'] as List)[5] as List).first as int,
          !(data.species[toId(data.speciesName(r['name'] as String))]?.nfe ?? false),
        ),
    ];
    if (mounted) setState(() => _all = list);
  }

  Widget _chip(String label, bool on, ValueChanged<bool> change) => FilterChip(
        label: Text(label),
        selected: on,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: const Color(0xFF0284C7),
        labelStyle: TextStyle(color: on ? Colors.white : null, fontWeight: FontWeight.w600),
        onSelected: (v) => setState(() => change(v)),
      );

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final all = _all;
    final (_, iv, ev, nat) = speedSpreads[_spread];
    final q = _query.trim().toLowerCase();
    final list = all == null
        ? const <(int, String, int, int)>[]
        : ([
            for (final (id, name, base, fin) in all)
              if (!_finalOnly || fin) (id, name, base, speedStat(base, _level, iv, ev, nat, scarf: _scarf, boost: _boost, tailwind: _tailwind)),
          ]..sort((a, b) => _trickRoom ? a.$4.compareTo(b.$4) : b.$4.compareTo(a.$4)));
    final shown = q.isEmpty ? list.indexed.toList() : list.indexed.where((e) => I18n.nameMatches(e.$2.$2, q) || '${e.$2.$1}' == q).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Faixas de velocidade')),
      body: ReadableWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quem ataca primeiro: todos os Pokémon em ordem de Speed.', style: TextStyle(color: c.muted, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final l in const [50, 100]) _chip(tr('Nível {0}').replaceAll('{0}', '$l'), _level == l, (_) => _level = l),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final (i, s) in speedSpreads.indexed) _chip(s.$1, _spread == i, (_) => _spread = i),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip('Choice Scarf', _scarf, (v) => _scarf = v),
                      _chip('+1 Speed', _boost, (v) => _boost = v),
                      _chip('Tailwind', _tailwind, (v) => _tailwind = v),
                      _chip('Trick Room', _trickRoom, (v) => _trickRoom = v),
                      _chip('Só evoluídos', _finalOnly, (v) => _finalOnly = v),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: tr('Procurar Pokémon'),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
            ),
            if (all == null)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else
              SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final (rank, (id, name, base, speed)) = shown[i];
                  return ListTile(
                    dense: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: id))),
                    leading: SizedBox(
                      width: 78,
                      child: Row(children: [
                        SizedBox(width: 34, child: Text('${rank + 1}', style: TextStyle(color: c.muted, fontWeight: FontWeight.bold))),
                        SizedBox.square(dimension: 40, child: PokemonSprite(id, fill: 0.95)),
                      ]),
                    ),
                    title: Text(I18n.pokemonName(name.replaceAll('-', ' ').capitalise()),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(tr('Base {0}').replaceAll('{0}', '$base')),
                    trailing: Text('$speed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
