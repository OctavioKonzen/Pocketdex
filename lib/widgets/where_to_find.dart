// lib/widgets/where_to_find.dart
//
// Página do Pokémon: grito, jogos em que ele aparece (tocar marca como pego
// na Coleção) e onde encontrá-lo em cada jogo (dados do banco local).

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

/// Jogos do Pokémon; cada um marca/desmarca "peguei" na Coleção.
class GamesSection extends StatelessWidget {
  final int pokemonId;
  final List<String> games;
  const GamesSection({super.key, required this.pokemonId, required this.games});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: UserData.instance,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jogos', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Toque num jogo para marcar que você já pegou este Pokémon nele.',
              style: TextStyle(color: theme.hintColor, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in games)
                if (gamesByKey[key] != null) _chip(gamesByKey[key]!, UserData.instance.caught(key).contains(pokemonId)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(Game game, bool caught) => GestureDetector(
        onTap: () => UserData.instance.toggleCaught(game.key, pokemonId),
        child: Opacity(
          opacity: caught ? 1 : 0.8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: game.gradient,
              borderRadius: BorderRadius.circular(30),
              border: caught ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Text('${caught ? '✓ ' : ''}${game.name}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      );
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
