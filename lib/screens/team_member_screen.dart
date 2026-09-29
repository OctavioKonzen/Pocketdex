// lib/screens/team_member_screen.dart
//
// Editor completo de um Pokémon do time (igual ao site,
// web-site/src/components/TeamMemberEditor.jsx): apelido, nível, gênero,
// shiny, habilidade, item, Nature, tipo Tera, 4 golpes, EVs e IVs com os
// status finais. Cada mudança já é salva ([onChanged]).
//
// Ao fechar devolve 'remove' (tirar do time), 'swap' (trocar o Pokémon) ou null.

import 'package:flutter/material.dart';

import '../services/local_database.dart';
import '../services/team_sets.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/pick_fields.dart';
import '../widgets/pokemon_sprite.dart';

// Categorias de itens que não dá para segurar em batalha.
const _notHeld = {
  'standard-balls', 'special-balls', 'apricorn-balls', 'all-machines', 'plot-advancement', 'event-items', 'gameplay', //
  'unused', 'data-cards', 'dex-completion', 'mulch', 'apricorn-box', 'spelunking', 'curry-ingredients',
  'sandwich-ingredients', 'picnic', 'tm-materials', 'catching-bonus', 'z-crystals', 'dynamax-crystals', 'nature-mint',
  'species-candies', 'collectibles', 'loot',
};

class TeamMemberScreen extends StatefulWidget {
  final int pokemonId;
  final Map<String, dynamic> set;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const TeamMemberScreen({super.key, required this.pokemonId, required this.set, required this.onChanged});

  @override
  State<TeamMemberScreen> createState() => _TeamMemberScreenState();
}

class _TeamMemberScreenState extends State<TeamMemberScreen> {
  late Map<String, dynamic> _set = normalizeSet(widget.set) ?? newSet();
  late final _nickname = TextEditingController(text: _set['nickname'] as String);
  Map<String, dynamic>? _row;
  Map<String, Map<String, dynamic>>? _moves;
  List<String>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = LocalDatabase.instance;
    final row = await db.pokemonRow(widget.pokemonId);
    final moves = await db.movesByName();
    final items = [
      for (final i in await db.allItems())
        if (((i['attributes'] as List?) ?? const []).contains('holdable') && !_notHeld.contains(i['category']))
          i['name'] as String,
    ]..sort();
    if (!mounted) return;
    setState(() {
      _row = row;
      _moves = moves;
      _items = {...popularItems.where(items.contains), ...items}.toList();
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _update(Map<String, dynamic> changes) {
    setState(() => _set = normalizeSet({..._set, ...changes})!);
    widget.onChanged(_set);
  }

  void _setStat(String group, String key, int value) =>
      _update({group: {...(_set[group] as Map<String, int>), key: value}});

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text,
            style: TextStyle(color: SiteColors.of(context).muted, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _box({required Widget child, VoidCallback? onTap}) {
    final c = SiteColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
        child: child,
      ),
    );
  }

  Widget _dropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) =>
      _box(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(isExpanded: true, isDense: true, value: value, items: items, onChanged: onChanged),
        ),
      );

  Widget? _moveInfo(String slug) {
    final m = _moves?[slug];
    if (m == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypeBadge(m['type'] as String, small: true),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text('${m['power'] ?? '—'}',
              textAlign: TextAlign.end, style: TextStyle(color: SiteColors.of(context).muted, fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _pickMove(int index) async {
    final row = _row;
    if (row == null) return;
    final learnable = {for (final m in row['moves'] as List) (m as List).first as String}.toList()..sort();
    final chosen = await showSearchSheet(context,
        title: 'Golpe ${index + 1}', options: learnable, emptyLabel: 'Nenhum', label: prettySlug, trailing: _moveInfo);
    if (chosen == null) return;
    final moves = List<String>.from(_set['moves'] as List);
    moves[index] = chosen;
    _update({'moves': moves});
  }

  Future<void> _pickItem() async {
    final chosen =
        await showSearchSheet(context, title: 'Item', options: _items ?? const [], emptyLabel: 'Nenhum', label: prettySlug);
    if (chosen != null) _update({'item': chosen});
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final row = _row;
    final name = row == null ? '' : (row['name'] as String).replaceAll('-', ' ').capitalise();
    final base = row == null ? null : [for (final s in row['stats'] as List) (s as List).first as int];
    final abilities = row == null ? const <List>[] : (row['abilities'] as List).cast<List>();
    final (up, down) = natures[_set['nature']] ?? (0, 0);
    final total = evTotal(_set);
    final shiny = _set['shiny'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text((_set['nickname'] as String).isNotEmpty ? _set['nickname'] as String : name),
        actions: [
          IconButton(
            tooltip: 'Trocar Pokémon',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => Navigator.pop(context, 'swap'),
          ),
          IconButton(
            tooltip: 'Remover do time',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.pop(context, 'remove'),
          ),
        ],
      ),
      body: row == null
          ? const Center(child: CircularProgressIndicator())
          : ReadableWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SiteCard(
                    child: Row(
                      children: [
                        SizedBox(width: 110, height: 110, child: PokemonSprite(widget.pokemonId, shiny: shiny, fill: 0.9)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Wrap(spacing: 4, children: [
                                for (final t in (row['types'] as List).cast<String>()) TypeBadge(t, small: true),
                              ]),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text('Shiny ✨', style: TextStyle(color: c.text)),
                                value: shiny,
                                onChanged: (v) => _update({'shiny': v}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Apelido'),
                        TextField(
                          controller: _nickname,
                          maxLength: 18,
                          onChanged: (v) => _update({'nickname': v}),
                          style: TextStyle(color: c.text),
                          decoration: InputDecoration(
                            hintText: name,
                            counterText: '',
                            isDense: true,
                            filled: true,
                            fillColor: c.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _label('Nível'),
                                NumberField(
                                    value: _set['level'] as int, min: 1, max: 100, onChanged: (v) => _update({'level': v})),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _label('Gênero'),
                                _dropdown<String>(
                                  value: _set['gender'] as String,
                                  items: const [
                                    DropdownMenuItem(value: '', child: Text('—')),
                                    DropdownMenuItem(value: 'M', child: Text('♂ Macho')),
                                    DropdownMenuItem(value: 'F', child: Text('♀ Fêmea')),
                                  ],
                                  onChanged: (v) => _update({'gender': v ?? ''}),
                                ),
                              ]),
                            ),
                          ],
                        ),
                        _label('Habilidade'),
                        _dropdown<String>(
                          value: _set['ability'] as String,
                          items: [
                            const DropdownMenuItem(value: '', child: Text('—')),
                            for (final a in abilities)
                              DropdownMenuItem(
                                value: a[0] as String,
                                child: Text('${prettySlug(a[0] as String)}${a[1] == true ? ' (oculta)' : ''}'),
                              ),
                            if ((_set['ability'] as String).isNotEmpty && !abilities.any((a) => a[0] == _set['ability']))
                              DropdownMenuItem(value: _set['ability'] as String, child: Text(prettySlug(_set['ability']))),
                          ],
                          onChanged: (v) => _update({'ability': v ?? ''}),
                        ),
                        _label('Item'),
                        _box(
                          onTap: _pickItem,
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                (_set['item'] as String).isEmpty ? 'Nenhum' : prettySlug(_set['item']),
                                style: TextStyle(color: (_set['item'] as String).isEmpty ? c.muted : c.text),
                              ),
                            ),
                            Icon(Icons.search, size: 18, color: c.muted),
                          ]),
                        ),
                        _label('Nature'),
                        _dropdown<String>(
                          value: _set['nature'] as String,
                          items: [for (final n in natures.keys) DropdownMenuItem(value: n, child: Text(natureLabel(n)))],
                          onChanged: (v) => _update({'nature': v ?? 'Hardy'}),
                        ),
                        _label('Tipo Tera'),
                        _dropdown<String>(
                          value: _set['tera'] as String,
                          items: [
                            const DropdownMenuItem(value: '', child: Text('—')),
                            for (final t in teraTypes) DropdownMenuItem(value: t, child: Text(prettySlug(t))),
                          ],
                          onChanged: (v) => _update({'tera': v ?? ''}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Golpes', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                        for (var i = 0; i < 4; i++) ...[
                          const SizedBox(height: 8),
                          _box(
                            onTap: () => _pickMove(i),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  (_set['moves'][i] as String).isEmpty ? 'Golpe ${i + 1}' : prettySlug(_set['moves'][i]),
                                  style: TextStyle(
                                    color: (_set['moves'][i] as String).isEmpty ? c.muted : c.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _moveInfo(_set['moves'][i] as String) ?? Icon(Icons.search, size: 18, color: c.muted),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EVs e IVs', style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.4),
                            1: FixedColumnWidth(44),
                            2: FixedColumnWidth(68),
                            3: FixedColumnWidth(60),
                            4: FlexColumnWidth(1),
                          },
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(children: [
                              const SizedBox(),
                              for (final h in const ['Base', 'EVs', 'IVs'])
                                Center(child: Text(h, style: TextStyle(color: c.muted, fontSize: 12))),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text('Final', style: TextStyle(color: c.muted, fontSize: 12)),
                              ),
                            ]),
                            for (var i = 0; i < 6; i++)
                              TableRow(children: [
                                Text.rich(TextSpan(
                                  text: statNames[statKeys[i]],
                                  style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 13),
                                  children: [
                                    if (up != down && i == up)
                                      const TextSpan(text: '+', style: TextStyle(color: Color(0xFF22C55E))),
                                    if (up != down && i == down)
                                      const TextSpan(text: '−', style: TextStyle(color: Color(0xFFEF4444))),
                                  ],
                                )),
                                Center(child: Text('${base![i]}', style: TextStyle(color: c.muted))),
                                Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: NumberField(
                                    value: _set['evs'][statKeys[i]] as int,
                                    min: 0,
                                    max: 252,
                                    onChanged: (v) => _setStat('evs', statKeys[i], v),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: NumberField(
                                    value: _set['ivs'][statKeys[i]] as int,
                                    min: 0,
                                    max: 31,
                                    onChanged: (v) => _setStat('ivs', statKeys[i], v),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('${statValue(base, i, _set)}',
                                      style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                                ),
                              ]),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'EVs usados: $total de 510',
                          style: TextStyle(
                            color: total > 510 ? const Color(0xFFEF4444) : c.muted,
                            fontSize: 12,
                            fontWeight: total > 510 ? FontWeight.bold : FontWeight.normal,
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
