// lib/screens/tools/shiny_hunt_screen.dart
//
// Contador de shiny hunt: +1 a cada encontro, com a chance do método escolhido.
// As caçadas ficam na conta (as mesmas do site).

import 'package:flutter/material.dart' hide Text;
import 'package:uuid/uuid.dart';

import '../../i18n/i18n.dart';
import '../../i18n/text.dart';
import '../../services/local_database.dart';
import '../../services/user_data.dart';
import '../../utils/shiny.dart';
import '../../utils/responsive.dart';
import '../../utils/site_ui.dart';
import '../../widgets/pokemon_sprite.dart';
import 'pick_pokemon.dart';

class ShinyHuntScreen extends StatefulWidget {
  const ShinyHuntScreen({super.key});

  @override
  State<ShinyHuntScreen> createState() => _ShinyHuntScreenState();
}

class _ShinyHuntScreenState extends State<ShinyHuntScreen> {
  String _method = 'full';
  Map<int, Map<String, dynamic>> _rows = {};

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.allPokemonRows().then((rows) {
      if (mounted) setState(() => _rows = {for (final r in rows) r['id'] as int: r});
    });
  }

  void _save(List<Map<String, dynamic>> hunts) => UserData.instance.update({'hunts': hunts});

  void _change(String id, Map<String, dynamic> changes) => _save([
        for (final h in UserData.instance.hunts) h['id'] == id ? {...h, ...changes} : h
      ]);

  Future<void> _newHunt() async {
    final id = await pickPokemon(context);
    if (id == null) return;
    _save([
      {
        'id': const Uuid().v4(),
        'pokemonId': id,
        'method': _method,
        'count': 0,
        'found': false,
        'startedAt': DateTime.now().millisecondsSinceEpoch,
        'foundAt': null,
      },
      ...UserData.instance.hunts,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contador de shiny')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newHunt,
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Nova caçada'),
      ),
      body: ListenableBuilder(
        listenable: UserData.instance,
        builder: (context, _) {
          final hunts = UserData.instance.hunts;
          return ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Método (para a próxima caçada)'), border: const OutlineInputBorder()),
                  items: [
                    for (final m in shinyMethods) DropdownMenuItem(value: m.key, child: Text('${tr(m.label)} · 1/${m.odds}')),
                  ],
                  onChanged: (v) => setState(() => _method = v ?? 'full'),
                ),
                const SizedBox(height: 16),
                if (hunts.isEmpty) const EmptyMessage('Nenhuma caçada ainda. Escolha o método e o Pokémon para começar a contar.'),
                for (final h in hunts) _card(h, c),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> h, SiteColors c) {
    final id = h['id'] as String;
    final pokemonId = (h['pokemonId'] as num).toInt();
    final count = (h['count'] as num?)?.toInt() ?? 0;
    final found = h['found'] == true;
    final method = shinyMethod(h['method'] as String?);
    final chance = shinyChanceSoFar(count, method.odds);
    final row = _rows[pokemonId];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: found ? Colors.amber.withAlpha(35) : c.card,
        borderRadius: BorderRadius.circular(24),
        border: found ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 70, height: 70, child: PokemonSprite(pokemonId, shiny: true)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row == null ? '...' : I18n.pokemonName(shortName(row['name'] as String)),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('${tr(method.label)} · 1/${method.odds}', style: TextStyle(color: c.muted, fontSize: 12)),
                    if (found)
                      Text(tr('✨ Encontrado com {0} encontros!').replaceAll('{0}', '$count'),
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Apagar caçada'),
                icon: Icon(Icons.delete_outline, color: c.muted),
                onPressed: () => _save(UserData.instance.hunts.where((x) => x['id'] != id).toList()),
              ),
            ],
          ),
          Text('$count', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
          Text(tr('{0}% de chance de já ter aparecido').replaceAll('{0}', '${(chance * 100).round()}'),
              style: TextStyle(color: c.muted, fontSize: 12)),
          if (!found) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _change(id, {'count': count > 0 ? count - 1 : 0}),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _change(id, {'count': count + 1}),
                      child: const Text('+1', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: const Color(0xFF3E2723)),
                  onPressed: () => _change(id, {'found': true, 'foundAt': DateTime.now().millisecondsSinceEpoch}),
                  child: const Text('Achei ✨'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
