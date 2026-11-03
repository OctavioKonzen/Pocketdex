// lib/widgets/daily_pokemon_card.dart
//
// Card do Pokémon do dia no Início (igual ao site, DailyPokemonCard.jsx):
// sprite, nome, uma curiosidade (a descrição da Pokédex) e o grito.

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../screens/pokemon_detail_screen.dart';
import '../services/cry_player.dart';
import '../services/daily_pokemon.dart';
import '../services/local_database.dart';
import '../utils/pokemon_colors.dart';
import '../utils/string_extensions.dart';
import 'pokemon_sprite.dart';

class DailyPokemonCard extends StatefulWidget {
  const DailyPokemonCard({super.key});

  @override
  State<DailyPokemonCard> createState() => _DailyPokemonCardState();
}

class _DailyPokemonCardState extends State<DailyPokemonCard> {
  final int _id = DailyPokemon.today;
  Map<String, dynamic>? _row;
  String _flavor = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = LocalDatabase.instance;
    final row = await db.pokemonRow(_id);
    final species = (await db.speciesById())[_id];
    if (!mounted) return;
    setState(() {
      _row = row;
      _flavor = (I18n.pick(species?['flavor'] as String?, species?['flavors']) ?? '').replaceAll('\n', ' ');
    });
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    if (row == null) return const SizedBox(height: 104);
    final types = (row['types'] as List).cast<String>();
    final name = I18n.pokemonName((row['name'] as String).split('-').first.capitalise());
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: typeBackground(types, borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: _id))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                SizedBox.square(dimension: 80, child: PokemonSprite(_id, fill: 0.95)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⭐ Pokémon do dia', style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('$name  #${_id.toString().padLeft(3, '0')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
                      if (_flavor.isNotEmpty)
                        // A descrição vem do banco já no idioma (sem tradução automática).
                        Text(_flavor, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('Ouvir o grito'),
                  onPressed: () => CryPlayer.instance.play(_id),
                  icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
