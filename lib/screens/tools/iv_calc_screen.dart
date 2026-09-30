// lib/screens/tools/iv_calc_screen.dart
//
// Calculadora de IVs: nível, Nature, EVs e os status mostrados no jogo.

import 'package:flutter/material.dart' hide Text;

import '../../i18n/i18n.dart';
import '../../i18n/text.dart';
import '../../services/local_database.dart';
import '../../services/team_sets.dart';
import '../../utils/ivs.dart';
import '../../utils/responsive.dart';
import '../../utils/site_ui.dart';
import '../../widgets/pokemon_sprite.dart';
import 'pick_pokemon.dart';

class IvCalcScreen extends StatefulWidget {
  const IvCalcScreen({super.key});

  @override
  State<IvCalcScreen> createState() => _IvCalcScreenState();
}

class _IvCalcScreenState extends State<IvCalcScreen> {
  static const _labels = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed'];
  Map<String, dynamic>? _pokemon;
  int _level = 50;
  String _nature = 'Hardy';
  final _stats = List.generate(6, (_) => TextEditingController());
  final _evs = List.generate(6, (_) => TextEditingController(text: '0'));

  @override
  void dispose() {
    for (final c in [..._stats, ..._evs]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final id = await pickPokemon(context);
    if (id == null) return;
    final row = await LocalDatabase.instance.pokemonRow(id);
    if (mounted && row != null) setState(() => _pokemon = row);
  }

  int _base(int i) => (((_pokemon?['stats'] as List?)?[i] as List?)?[0] as num?)?.toInt() ?? 0;

  String _result(int i) {
    final shown = int.tryParse(_stats[i].text);
    if (_pokemon == null || shown == null) return '—';
    final ev = (int.tryParse(_evs[i].text) ?? 0).clamp(0, 252);
    final ivs = possibleIvs(i, _base(i), shown, ev, _level, _nature);
    if (ivs.isEmpty) return tr('Não bate');
    return ivs.length == 1 ? '${ivs.first}' : '${ivs.first}–${ivs.last}';
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    InputDecoration deco([String? label]) =>
        InputDecoration(labelText: label == null ? null : tr(label), isDense: true, border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de IVs')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SiteCard(
              onTap: _pick,
              child: Row(
                children: [
                  SizedBox(width: 60, height: 60, child: _pokemon == null ? null : PokemonSprite(_pokemon!['id'] as int)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_pokemon == null ? 'Escolher Pokémon' : I18n.pokemonName(shortName(_pokemon!['name'] as String)),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (_pokemon != null)
                          Text('Base: ${[for (var i = 0; i < 6; i++) _base(i)].join(' / ')}', style: TextStyle(color: c.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: '$_level',
                    keyboardType: TextInputType.number,
                    decoration: deco('Nível'),
                    onChanged: (v) => setState(() => _level = (int.tryParse(v) ?? 50).clamp(1, 100)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _nature,
                    isExpanded: true,
                    decoration: deco('Nature'),
                    items: [for (final n in natures.keys) DropdownMenuItem(value: n, child: Text(natureLabel(n)))],
                    onChanged: (v) => setState(() => _nature = v ?? 'Hardy'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Coloque os status que aparecem no resumo do Pokémon no jogo e os EVs que ele já tem (0 se nunca treinou).',
                style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.bold),
                child: const Row(
                  children: [
                    SizedBox(width: 64, child: Text('Status')),
                    Expanded(child: Text('No jogo')),
                    SizedBox(width: 8),
                    Expanded(child: Text('EVs')),
                    SizedBox(width: 64, child: Text('IV', textAlign: TextAlign.center)),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(_labels[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _stats[i],
                        keyboardType: TextInputType.number,
                        decoration: deco(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _evs[i],
                        keyboardType: TextInputType.number,
                        decoration: deco(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_result(i), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
