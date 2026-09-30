// lib/widgets/where_to_find.dart
//
// Página do Pokémon: grito (aba Sobre) e a aba Jogos, com os jogos em que ele
// aparece por geração (tocar marca como pego na Coleção) e onde encontrá-lo.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../models/game.dart';
import '../services/cry_player.dart';
import '../services/local_database.dart';
import '../services/user_data.dart';
import '../utils/encounters.dart';

/// Botão "Ouvir o grito".
class CryButton extends StatelessWidget {
  final int speciesId;
  const CryButton({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(Icons.volume_up_rounded, size: 18, color: theme.colorScheme.primary),
      label: const Text('Ouvir o grito'),
      onPressed: () => CryPlayer.instance.play(speciesId),
    );
  }
}

/// Aba Jogos da página do Pokémon: os jogos em que ele aparece, por geração
/// (principais e secundários), com "Só em Red" quando é exclusivo de uma
/// versão, e onde encontrá-lo. Tocar num jogo marca/desmarca "peguei".
class GamesTab extends StatefulWidget {
  final int pokemonId;
  final List<String> games;
  const GamesTab({super.key, required this.pokemonId, required this.games});

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  Map<String, dynamic> _only = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GamesTab old) {
    super.didUpdateWidget(old);
    if (old.pokemonId != widget.pokemonId) _load();
  }

  Future<void> _load() async {
    final all = await LocalDatabase.instance.exclusives();
    final only = all['${widget.pokemonId}'];
    if (mounted) setState(() => _only = only is Map ? Map<String, dynamic>.from(only) : const {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inGame = widget.games.toSet();
    final main = [for (final g in games) if (!g.spinoff && inGame.contains(g.key)) g];
    final spinoffs = [for (final g in games) if (g.spinoff && inGame.contains(g.key)) g];
    final byGen = <int, List<Game>>{};
    for (final g in main) {
      byGen.putIfAbsent(g.gen, () => []).add(g);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListenableBuilder(
        listenable: UserData.instance,
        builder: (context, _) {
          final caughtCount = inGame.where((k) => UserData.instance.caught(k).contains(widget.pokemonId)).length;
          Widget section(String title, List<Game> list) => Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.6,
                      children: [for (final g in list) _card(g)],
                    ),
                  ],
                ),
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inGame.isEmpty)
                Text('Sem jogos registrados para esta forma.', style: TextStyle(color: theme.hintColor))
              else ...[
                Text(
                  tr('Aparece em {0} jogos · pego em {1}.')
                      .replaceAll('{0}', '${inGame.length}')
                      .replaceAll('{1}', '$caughtCount'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('Toque num jogo para marcar que você já pegou este Pokémon nele.',
                    style: TextStyle(color: theme.hintColor, fontSize: 12)),
                for (final e in byGen.entries) section(tr('Geração {0}').replaceAll('{0}', '${e.key}'), e.value),
                if (spinoffs.isNotEmpty) section(tr('Jogos secundários'), spinoffs),
              ],
              const SizedBox(height: 18),
              WhereToFind(pokemonId: widget.pokemonId),
            ],
          );
        },
      ),
    );
  }

  Widget _card(Game game) {
    final caught = UserData.instance.caught(game.key).contains(widget.pokemonId);
    final only = _only[game.key] as String?;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: game.gradient,
          borderRadius: BorderRadius.circular(16),
          border: caught ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => UserData.instance.toggleCaught(game.key, widget.pokemonId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      if (only != null)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                          child: Text(tr('Só em {0}').replaceAll('{0}', only),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                Icon(caught ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: caught ? Colors.white : Colors.white54, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Onde encontrar: escolhe o jogo e vê local, método, nível e chance.
class WhereToFind extends StatefulWidget {
  final int pokemonId;
  const WhereToFind({super.key, required this.pokemonId});

  @override
  State<WhereToFind> createState() => _WhereToFindState();
}

class _WhereToFindState extends State<WhereToFind> {
  Map<String, List<List<dynamic>>>? _byGame;
  Map<String, dynamic>? _locations;
  String? _game;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WhereToFind old) {
    super.didUpdateWidget(old);
    if (old.pokemonId != widget.pokemonId) {
      _game = null;
      _load();
    }
  }

  Future<void> _load() async {
    final db = LocalDatabase.instance;
    final rows = await db.encountersOf(widget.pokemonId);
    final byGame = <String, List<List<dynamic>>>{};
    for (final r in rows) {
      byGame.putIfAbsent(r[1] as String, () => []).add(r);
    }
    final locations = byGame.isEmpty ? null : await db.locations();
    if (mounted) {
      setState(() {
        _byGame = byGame;
        _locations = locations;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byGame = _byGame;
    final gameList = [
      for (final g in games)
        if (byGame?[g.key] != null) g
    ];
    final current = byGame?[_game] != null ? _game : (gameList.isEmpty ? null : gameList.last.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Onde encontrar', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (byGame == null)
          const SizedBox.shrink()
        else if (gameList.isEmpty)
          Text('Sem locais de captura na natureza (evolução, ovo, evento ou jogo sem dados de locais).',
              style: TextStyle(color: theme.hintColor, fontSize: 13))
        else ...[
          DropdownButtonFormField<String>(
            initialValue: current,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: [for (final g in gameList) DropdownMenuItem(value: g.key, child: Text(g.name))],
            onChanged: (v) => setState(() => _game = v),
          ),
          const SizedBox(height: 8),
          for (final r in byGame[current] ?? const <List<dynamic>>[])
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(18), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(locationName(_locations, r[0] as String), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_details(r), style: TextStyle(color: theme.hintColor, fontSize: 12)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _details(List<dynamic> r) {
    final min = r[3], max = r[4], chance = (r[5] as num?)?.toInt() ?? 0;
    final versions = (r[6] as List?)?.cast<String>() ?? const [];
    final level = min == max
        ? tr('Nível {0}').replaceAll('{0}', '$min')
        : tr('Nível {0}–{1}').replaceAll('{0}', '$min').replaceAll('{1}', '$max');
    return [
      tr(encounterMethodLabel(r[2] as String)),
      level,
      if (chance > 0 && chance < 100) '$chance%',
      if (versions.isNotEmpty) versions.join(', '),
    ].join(' · ');
  }
}
