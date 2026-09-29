// lib/widgets/team_share_dialogs.dart
//
// Janelas de compartilhar e importar times (código, link ou texto de simulador),
// no mesmo formato do site.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../services/local_database.dart';
import '../services/team_sets.dart';
import '../services/team_share.dart';
import '../services/user_data.dart';
import 'pokemon_sprite.dart';
import 'package:pocket_dex/i18n/text.dart';

class TeamShareDialogs {
  TeamShareDialogs._();

  /// Mostra o link, o código e o texto do Showdown do time `teamId`.
  static Future<void> share(BuildContext context, String teamId) async {
    final team = UserData.instance.teams.where((t) => t['id'] == teamId).firstOrNull;
    if (team == null) return;
    final pokemon = [for (final p in (team['pokemon'] as List? ?? [])) (p as num?)?.toInt()];
    final name = '${team['name'] ?? 'Time'}';
    final color = team['color'] as String?;
    final sets = teamSets(pokemon, team['sets']);
    final rows = await LocalDatabase.instance.allPokemonRows();
    final names = {for (final r in rows) r['id'] as int: r['name'] as String};
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Compartilhar time'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mande o link ou o código para um amigo: no site ou no app, ele abre em Times → Importar.',
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
              const SizedBox(height: 12),
              _CopyField(label: 'Link', value: TeamShare.link(name: name, color: color, pokemon: pokemon, sets: sets)),
              _CopyField(label: 'Código', value: TeamShare.encode(name: name, color: color, pokemon: pokemon, sets: sets)),
              _CopyField(
                  label: 'Texto (Pokémon Showdown e outros simuladores)',
                  value: TeamShare.toShowdown(name, pokemon, names, sets),
                  lines: 8),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Fechar'))],
      ),
    );
  }

  /// Cola um código, link ou texto do Showdown; devolve o time ou null.
  static Future<SharedTeam?> import(BuildContext context) async {
    final db = LocalDatabase.instance;
    final rows = await db.allPokemonRows();
    // Nomes de golpes, habilidades e itens do texto → os do banco.
    final lookups = (
      moves: lookupOf((await db.movesByName()).keys),
      abilities: lookupOf([for (final a in await db.allAbilities()) a['name'] as String]),
      items: lookupOf([for (final i in await db.allItems()) i['name'] as String]),
    );
    if (!context.mounted) return null;
    return showDialog<SharedTeam>(context: context, builder: (_) => _ImportDialog(rows: rows, lookups: lookups));
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  final int lines;
  const _CopyField({required this.label, required this.value, this.lines = 1});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copiado!')));
                },
                child: const Text('Copiar'),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
            child: Text(
              value,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Lookups = ({Map<String, String> moves, Map<String, String> abilities, Map<String, String> items});

class _ImportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final _Lookups lookups;
  const _ImportDialog({required this.rows, required this.lookups});
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();
  SharedTeam? _team;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _text.text = data!.text!;
    _changed(_text.text);
  }

  void _changed(String text) => setState(() => _team = text.trim().isEmpty
      ? null
      : TeamShare.parse(text, widget.rows,
          moves: widget.lookups.moves, abilities: widget.lookups.abilities, items: widget.lookups.items));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Importar time'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 6,
              onChanged: _changed,
              decoration: InputDecoration(
                hintText: tr('Cole aqui o link, o código (PDX1...) ou o texto do time (Pokémon Showdown e outros)'),
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste), label: const Text('Colar')),
            ),
            if (_team != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_team!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final id in _team!.pokemon)
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle),
                                child: id == null ? null : PokemonSprite(id, fill: 0.8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            else if (_text.text.trim().isNotEmpty)
              const Text('Não encontrei um time nesse texto.', style: TextStyle(color: Colors.redAccent)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: _team == null ? null : () => Navigator.pop(context, _team),
          child: const Text('Importar', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
