// lib/screens/collection_screen.dart
//
// Coleção por jogo: marca os Pokémon que você já pegou em cada jogo (normal e
// shiny) e mostra o progresso. Fica salva na conta (a mesma do site).

import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../models/game.dart';
import '../services/local_database.dart';
import '../services/user_data.dart';
import '../widgets/forms_collection.dart';
import '../widgets/game_picker.dart';
import '../widgets/pokemon_sprite.dart';

class CollectionView extends StatefulWidget {
  const CollectionView({super.key});

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  static const _prefKey = 'collection_game';
  List<Map<String, dynamic>>? _pokedex;
  String _game = 'sv';
  String _filter = 'all';
  bool _shinyMode = false;
  String? _version; // versão do jogo (Red, Blue...)
  bool _forms = false;
  Map<String, dynamic> _exclusives = {};

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.defaultPokemon().then((rows) {
      if (mounted) setState(() => _pokedex = rows);
    });
    LocalDatabase.instance.exclusives().then((e) {
      if (mounted) setState(() => _exclusives = e);
    });
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString(_prefKey);
      if (saved != null && gamesByKey[saved] != null && mounted) setState(() => _game = saved);
    });
  }

  void _choose(Game? g) {
    if (g == null) return;
    setState(() {
      _game = g.key;
      _version = null;
    });
    SharedPreferences.getInstance().then((p) => p.setString(_prefKey, g.key));
  }

  static String _name(String slug) {
    final base = slug.split('-').first;
    return base.isEmpty ? base : base[0].toUpperCase() + base.substring(1);
  }

  /// "Por jogo" ou "Formas" (Living Dex das formas: regionais, Megas...).
  Widget _modeSwitch() => SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Por jogo'), icon: Icon(Icons.videogame_asset)),
          ButtonSegment(value: true, label: Text('Formas'), icon: Icon(Icons.auto_awesome_mosaic)),
        ],
        selected: {_forms},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _forms = s.first),
      );

  @override
  Widget build(BuildContext context) {
    if (_forms) return FormsCollection(header: _modeSwitch());
    final pokedex = _pokedex;
    if (pokedex == null) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final game = gamesByKey[_game]!;
    return ListenableBuilder(
      listenable: UserData.instance,
      builder: (context, _) {
        final caught = UserData.instance.caught(_game);
        final shiny = UserData.instance.caught(_game, shiny: true);
        String? only(Map<String, dynamic> p) => (_exclusives['${p['id']}'] as Map?)?[_game] as String?;
        final inGame = [
          for (final p in pokedex)
            if (((p['games'] as List?) ?? const []).contains(_game) &&
                (_version == null || only(p) == null || only(p) == _version))
              p,
        ];
        final done = inGame.where((p) => caught.contains(p['id'])).length;
        final doneShiny = inGame.where((p) => shiny.contains(p['id'])).length;
        final shown = [
          for (final p in inGame)
            if (_filter == 'all' || (_filter == 'caught') == caught.contains(p['id'])) p,
        ];
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverList.list(children: [
                _modeSwitch(),
                const SizedBox(height: 10),
                GamePicker(value: game, onChanged: _choose),
                if (game.versions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // Cada versão tem Pokémon que a outra não tem.
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final v in <String?>[null, ...game.versions])
                        ChoiceChip(
                          label: Text(v ?? tr('Todas as versões')),
                          selected: _version == v,
                          onSelected: (_) => setState(() => _version = v),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('Todos')),
                          ButtonSegment(value: 'missing', label: Text('Faltando')),
                          ButtonSegment(value: 'caught', label: Text('Pegos')),
                        ],
                        selected: {_filter},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() => _filter = s.first),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('✨ Shiny'),
                      selected: _shinyMode,
                      selectedColor: Colors.amber,
                      onSelected: (v) => setState(() => _shinyMode = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: game.gradient, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_version ?? game.name,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          ),
                          Text(
                              tr('{0}/{1} pegos · {2} shiny')
                                  .replaceAll('{0}', '$done')
                                  .replaceAll('{1}', '${inGame.length}')
                                  .replaceAll('{2}', '$doneShiny'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: inGame.isEmpty ? 0 : done / inGame.length,
                          minHeight: 10,
                          color: Colors.white,
                          backgroundColor: Colors.black26,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          _shinyMode
                              ? 'Toque num Pokémon para marcar que você o pegou shiny.'
                              : 'Toque num Pokémon para marcar que você o pegou neste jogo.',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final p = shown[i];
                  final id = p['id'] as int;
                  final isCaught = caught.contains(id);
                  final isShiny = shiny.contains(id);
                  final on = _shinyMode ? isShiny : isCaught;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => UserData.instance.toggleCaught(_game, id, shiny: _shinyMode),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: on ? Border.all(color: const Color(0xFF38BDF8), width: 2) : null,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Stack(
                        children: [
                          Text('#$id', style: TextStyle(color: theme.hintColor, fontSize: 9)),
                          if (isShiny)
                            const Align(
                                alignment: Alignment.topRight, child: Text('✨', style: TextStyle(fontSize: 12))),
                          if (_version == null && only(p) != null)
                            Align(
                              alignment: const Alignment(1, 0.45),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: Text(only(p)!,
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          Column(
                            children: [
                              Expanded(
                                child: Opacity(
                                  opacity: isCaught || isShiny ? 1 : 0.35,
                                  child: PokemonSprite(id, shiny: isShiny && _shinyMode),
                                ),
                              ),
                              Text(I18n.pokemonName(_name(p['name'] as String)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
