// lib/screens/tools/nuzlocke_screen.dart
//
// Registro de Nuzlocke: um Pokémon por local; quem desmaia vai para o
// cemitério. Os locais de cada jogo vêm do banco local. Fica na conta (os
// mesmos do site).

import 'package:flutter/material.dart' hide Text;
import 'package:uuid/uuid.dart';

import '../../i18n/i18n.dart';
import '../../i18n/text.dart';
import '../../models/game.dart';
import '../../services/local_database.dart';
import '../../services/user_data.dart';
import '../../utils/encounters.dart';
import '../../utils/responsive.dart';
import '../../utils/site_ui.dart';
import '../../widgets/pokemon_sprite.dart';
import 'pick_pokemon.dart';

const _status = [
  ('caught', 'Vivo', Color(0xFF22C55E)),
  ('dead', 'Morto', Color(0xFFEF4444)),
  ('missed', 'Perdido', Color(0xFF78909C)),
];

void _saveRuns(List<Map<String, dynamic>> runs) => UserData.instance.update({'nuzlockes': runs});

class NuzlockeScreen extends StatefulWidget {
  const NuzlockeScreen({super.key});

  @override
  State<NuzlockeScreen> createState() => _NuzlockeScreenState();
}

class _NuzlockeScreenState extends State<NuzlockeScreen> {
  Map<String, List<String>>? _areas;

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.gameAreas().then((a) {
      if (mounted) setState(() => _areas = a);
    });
  }

  Future<void> _create() async {
    final gameList = [for (final g in games) if (_areas?[g.key] != null) g];
    if (gameList.isEmpty) return;
    final name = TextEditingController();
    var game = gameList.any((g) => g.key == 'frlg') ? 'frlg' : gameList.first.key;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Novo Nuzlocke'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, maxLength: 40, decoration: InputDecoration(labelText: tr('Nome'))),
              DropdownButtonFormField<String>(
                initialValue: game,
                isExpanded: true,
                items: [for (final g in gameList) DropdownMenuItem(value: g.key, child: Text(g.name))],
                onChanged: (v) => setDialog(() => game = v ?? game),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Criar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final run = {
      'id': const Uuid().v4(),
      'name': name.text.trim().isEmpty ? gamesByKey[game]!.name : name.text.trim(),
      'game': game,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'entries': <dynamic>[],
    };
    _saveRuns([run, ...UserData.instance.nuzlockes]);
    if (mounted) _open(run['id'] as String);
  }

  void _open(String id) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _RunScreen(runId: id, areas: _areas ?? const {})),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuzlocke')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _areas == null ? null : _create,
        backgroundColor: const Color(0xFFEF5350),
        icon: const Icon(Icons.add),
        label: const Text('Novo Nuzlocke'),
      ),
      body: ListenableBuilder(
        listenable: UserData.instance,
        builder: (context, _) {
          final runs = UserData.instance.nuzlockes;
          return ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (runs.isEmpty)
                  const EmptyMessage('Nenhum Nuzlocke ainda. Crie um para anotar cada captura por local, as mortes e o seu time.'),
                for (final r in runs) _runCard(r),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _runCard(Map<String, dynamic> r) {
    final g = gamesByKey[r['game']];
    final entries = (r['entries'] as List? ?? const []).cast<Map>();
    final alive = entries.where((e) => e['status'] == 'caught').length;
    final dead = entries.where((e) => e['status'] == 'dead').length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(gradient: g?.gradient, color: g == null ? Colors.blueGrey : null, borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => _open(r['id'] as String),
        title: Text(r['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        subtitle: Text(
          '${g?.name ?? ''}\n${tr('{0} vivos · {1} mortos · {2} locais').replaceAll('{0}', '$alive').replaceAll('{1}', '$dead').replaceAll('{2}', '${entries.length}')}',
          style: const TextStyle(color: Colors.white),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: tr('Apagar Nuzlocke'),
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: () => _saveRuns(UserData.instance.nuzlockes.where((x) => x['id'] != r['id']).toList()),
        ),
      ),
    );
  }
}

class _RunScreen extends StatefulWidget {
  final String runId;
  final Map<String, List<String>> areas;
  const _RunScreen({required this.runId, required this.areas});

  @override
  State<_RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<_RunScreen> {
  Map<String, dynamic>? _locations;
  Map<int, Map<String, dynamic>> _rows = {};
  String? _area;
  final _nickname = TextEditingController();

  @override
  void initState() {
    super.initState();
    final db = LocalDatabase.instance;
    db.locations().then((l) {
      if (mounted) setState(() => _locations = l);
    });
    db.allPokemonRows().then((rows) {
      if (mounted) setState(() => _rows = {for (final r in rows) r['id'] as int: r});
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _run {
    for (final r in UserData.instance.nuzlockes) {
      if (r['id'] == widget.runId) return r;
    }
    return null;
  }

  List<Map<String, dynamic>> _entries(Map<String, dynamic> run) =>
      [for (final e in (run['entries'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];

  void _setEntries(List<Map<String, dynamic>> entries) => _saveRuns([
        for (final r in UserData.instance.nuzlockes) r['id'] == widget.runId ? {...r, 'entries': entries} : r,
      ]);

  Future<void> _add(String area) async {
    final id = await pickPokemon(context);
    final run = _run;
    if (id == null || run == null) return;
    _setEntries([
      ..._entries(run),
      {'area': area, 'pokemonId': id, 'nickname': _nickname.text.trim(), 'status': 'caught'},
    ]);
    setState(() => _area = null);
    _nickname.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return ListenableBuilder(
      listenable: UserData.instance,
      builder: (context, _) {
        final run = _run;
        if (run == null) return Scaffold(appBar: AppBar());
        final entries = _entries(run);
        final g = gamesByKey[run['game']];
        final all = widget.areas[run['game']] ?? const <String>[];
        final used = {for (final e in entries) e['area']};
        final free = all.where((a) => !used.contains(a)).toList();
        final chosen = _area != null && free.contains(_area) ? _area! : (free.isEmpty ? null : free.first);
        return Scaffold(
          appBar: AppBar(title: Text(run['name'] as String? ?? 'Nuzlocke')),
          body: ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: g?.gradient, borderRadius: BorderRadius.circular(18)),
                  child: Text('${g?.name ?? ''} · ${tr('{0}/{1} locais').replaceAll('{0}', '${entries.length}').replaceAll('{1}', '${all.length}')}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                SiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Novo encontro', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Regra do Nuzlocke: só o primeiro Pokémon de cada local. Os locais já usados somem da lista.',
                          style: TextStyle(color: c.muted, fontSize: 12)),
                      const SizedBox(height: 10),
                      if (chosen != null)
                        DropdownButtonFormField<String>(
                          key: ValueKey(chosen),
                          initialValue: chosen,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: tr('Local'), isDense: true, border: const OutlineInputBorder()),
                          items: [for (final a in free) DropdownMenuItem(value: a, child: Text(locationName(_locations, a)))],
                          onChanged: (v) => setState(() => _area = v),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nickname,
                        maxLength: 20,
                        decoration: InputDecoration(labelText: tr('Apelido (opcional)'), isDense: true, border: const OutlineInputBorder()),
                      ),
                      FilledButton.icon(
                        onPressed: chosen == null ? null : () => _add(chosen),
                        icon: const Icon(Icons.catching_pokemon),
                        label: const Text('Escolher Pokémon'),
                      ),
                    ],
                  ),
                ),
                for (final (key, label, color) in _status) ...[
                  const SizedBox(height: 16),
                  Text('${tr(label)} (${entries.where((e) => e['status'] == key).length})',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  for (final e in entries.where((e) => e['status'] == key)) _entry(e, entries, c),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _entry(Map<String, dynamic> e, List<Map<String, dynamic>> entries, SiteColors c) {
    final id = (e['pokemonId'] as num).toInt();
    final row = _rows[id];
    final nickname = (e['nickname'] as String?) ?? '';
    final dead = e['status'] == 'dead';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Opacity(opacity: dead ? 0.5 : 1, child: SizedBox(width: 52, height: 52, child: PokemonSprite(id))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname.isNotEmpty ? nickname : (row == null ? '' : I18n.pokemonName(shortName(row['name'] as String))),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(locationName(_locations, e['area'] as String), style: TextStyle(color: c.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(spacing: 4, children: [
                  for (final (key, label, color) in _status)
                    ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      selected: e['status'] == key,
                      selectedColor: color,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _setEntries([
                        for (final x in entries) x['area'] == e['area'] ? {...x, 'status': key} : x,
                      ]),
                    ),
                ]),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Tirar encontro'),
            icon: Icon(Icons.close, color: c.muted),
            onPressed: () => _setEntries(entries.where((x) => x['area'] != e['area']).toList()),
          ),
        ],
      ),
    );
  }
}
