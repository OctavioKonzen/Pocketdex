// lib/screens/pokedex_screen.dart
//
// Pokédex no estilo do site: cabeçalho com a quantidade, busca e os cards em
// grade. Os filtros (geração, jogo e versão, tipos, categoria, habilidade,
// golpe e ordem) ficam num botão flutuante: ele abre um menu para escolher qual.
// Também usada para escolher um Pokémon (times e treino de EVs).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;

import '../models/game.dart';
import '../models/generation.dart';
import '../models/pokemon_listing.dart';
import '../services/account_format.dart';
import '../services/local_database.dart';
import '../services/pokemon_service.dart';
import '../utils/pokemon_colors.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/game_picker.dart';
import '../widgets/generation_picker.dart';
import '../widgets/pikachu_loading_indicator.dart';
import '../widgets/pokedex_web/pokedex_web_grid.dart';
import '../widgets/pokemon_card.dart';
import 'pokemon_detail_screen.dart';
import 'package:pocket_dex/i18n/text.dart';
import 'package:pocket_dex/i18n/i18n.dart';

class PokedexScreen extends StatefulWidget {
  final bool isForTeamSelection;

  /// Busca vinda de fora (barra do topo do site); filtra a lista.
  final ValueListenable<String>? searchQuery;

  const PokedexScreen({super.key, this.isForTeamSelection = false, this.searchQuery});

  @override
  PokedexScreenState createState() => PokedexScreenState();
}

class PokedexScreenState extends State<PokedexScreen> {
  final PokemonService _pokemonService = PokemonService();
  final TextEditingController _searchController = TextEditingController();

  List<PokemonListing> _fullPokemonList = [];
  List<PokemonListing> _displayList = [];
  Generation? _selectedGeneration;
  Game? _selectedGame;
  List<String> _selectedTypes = [];
  String? _version; // versão do jogo escolhido (Red, Blue...)
  Map<String, dynamic> _exclusives = {};
  bool _isLoading = true;

  // Filtros extras (iguais aos do site): categoria, habilidade, golpe e ordem.
  String? _tag; // 'legendary' | 'mythical' | 'baby'
  String _ability = '';
  String _move = '';
  int? _sort; // 0-5 = status; 6 = total
  Map<int, Map<String, dynamic>> _rows = {};
  Map<int, Map<String, dynamic>> _species = {};
  Map<String, Map<String, dynamic>> _moves = {};
  List<String> _abilityNames = [];

  static const _statLabels = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed'];

  @override
  void initState() {
    super.initState();
    _loadPokemon();
    _searchController.addListener(_filterPokemon);
    widget.searchQuery?.addListener(_onExternalSearch);
  }

  void _onExternalSearch() => _searchController.text = widget.searchQuery!.value;

  /// Dados para os filtros extras (carregados na primeira vez que abrem).
  Future<void> _loadFilterData() async {
    if (_rows.isNotEmpty) return;
    final db = LocalDatabase.instance;
    final rows = await db.allPokemonRows();
    final species = await db.speciesById();
    final moves = await db.movesByName();
    final abilities = [for (final a in await db.allAbilities()) if (a['is_main_series'] == true) a['name'] as String]..sort();
    final exclusives = await db.exclusives();
    if (!mounted) return;
    setState(() {
      _exclusives = exclusives;
      _rows = {for (final r in rows) r['id'] as int: r};
      _species = species;
      _moves = moves;
      _abilityNames = abilities;
    });
    _filterPokemon();
  }

  static String _slug(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  int _statOf(Map<String, dynamic>? row, int i) {
    final stats = (row?['stats'] as List?) ?? const [];
    int value(int k) => k < stats.length ? ((stats[k] as List)[0] as num).toInt() : 0;
    if (i == 6) return [for (var k = 0; k < 6; k++) value(k)].fold(0, (a, b) => a + b);
    return value(i);
  }

  bool get _extraActive =>
      _tag != null || _slug(_ability).isNotEmpty || _slug(_move).isNotEmpty || _sort != null || _version != null;

  @override
  void dispose() {
    widget.searchQuery?.removeListener(_onExternalSearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPokemon() async {
    setState(() => _isLoading = true);
    try {
      List<PokemonListing> list;
      if (_selectedGame != null) {
        // Com jogo, entram também as formas que aparecem nele (Alola, Mega...).
        list = await _pokemonService.fetchPokemonInGame(_selectedGame!.key,
            generation: _selectedGeneration?.id, types: _selectedTypes);
      } else if (_selectedTypes.isNotEmpty) {
        // Com tipo, entram também as formas (Alola, Mega...), como no site.
        list = await _pokemonService.fetchPokemonByTypes(_selectedTypes);
        final gen = _selectedGeneration;
        if (gen != null) {
          final species = (await LocalDatabase.instance.speciesIdsOfGeneration(gen.id)).toSet();
          list = list.where((p) => species.contains(AccountFormat.speciesOf(int.parse(p.id)))).toList();
        }
      } else if (_selectedGeneration != null) {
        list = await _pokemonService.fetchPokedex(_selectedGeneration!);
      } else {
        list = await _pokemonService.fetchAllPokemonList();
      }
      if (!mounted) return;
      setState(() {
        _fullPokemonList = list;
        _isLoading = false;
      });
      _filterPokemon();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar os Pokémon: $e')));
    }
  }

  void _filterPokemon() {
    final query = _searchController.text.trim().toLowerCase();
    final ability = _slug(_ability);
    final move = _slug(_move);
    final learners = move.isEmpty || _moves[move] == null ? null : ((_moves[move]!['learned_by'] as List?) ?? const []).toSet();
    final useAbility = ability.isNotEmpty && _abilityNames.contains(ability);
    var list = _fullPokemonList.where((p) {
      if (query.isNotEmpty && !(I18n.nameMatches(p.name, query) || p.id == query)) return false;
      if (!_extraActive || _rows.isEmpty) return true;
      final id = int.parse(p.id);
      final row = _rows[id];
      if (_version != null && _selectedGame != null) {
        final only = (_exclusives['$id'] as Map?)?[_selectedGame!.key];
        if (only != null && only != _version) return false;
      }
      if (_tag != null) {
        final s = _species[row?['species']];
        final tag = s == null
            ? null
            : s['is_mythical'] == true
                ? 'mythical'
                : s['is_legendary'] == true
                    ? 'legendary'
                    : s['is_baby'] == true
                        ? 'baby'
                        : null;
        if (tag != _tag) return false;
      }
      if (useAbility && !(((row?['abilities'] as List?) ?? const []).any((a) => (a as List)[0] == ability))) return false;
      if (learners != null && !learners.contains(id)) return false;
      return true;
    }).toList();
    if (_sort != null && _rows.isNotEmpty) {
      final i = _sort!;
      list = [...list]..sort((a, b) => _statOf(_rows[int.parse(b.id)], i).compareTo(_statOf(_rows[int.parse(a.id)], i)));
    }
    setState(() => _displayList = list);
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        // Até dois tipos: o novo substitui o mais antigo.
        _selectedTypes = [..._selectedTypes.length == 2 ? _selectedTypes.sublist(1) : _selectedTypes, type];
      }
    });
    _loadPokemon();
  }

  void _clearFilters() {
    setState(() {
      _selectedGeneration = null;
      _selectedGame = null;
      _version = null;
      _selectedTypes = [];
      _tag = null;
      _ability = '';
      _move = '';
      _sort = null;
    });
    _loadPokemon();
  }

  void _handlePokemonSelection(PokemonListing pokemon) {
    if (widget.isForTeamSelection) {
      Navigator.of(context).pop({'id': pokemon.id, 'imageUrl': pokemon.imageUrl});
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: int.parse(pokemon.id))),
      );
    }
  }

  Widget _header(SiteColors c) {
    // Filtros ativos: um chip para cada (o "x" tira só aquele).
    final active = <(String, VoidCallback)>[
      if (_selectedGeneration != null) (_selectedGeneration!.name, () => _setGeneration(null)),
      if (_selectedGame != null) (_selectedGame!.name, () => _setGame(null)),
      if (_version != null) (_version!, () => _setVersion(null)),
      if (_selectedTypes.isNotEmpty)
        (_selectedTypes.map((t) => t.capitalise()).join(' + '), () {
          setState(() => _selectedTypes = []);
          _loadPokemon();
        }),
      if (_tag != null) (_tagLabel(_tag), () => _setExtra(() => _tag = null)),
      if (_slug(_ability).isNotEmpty) ('${tr('Habilidade')}: ${_ability.trim()}', () => _setExtra(() => _ability = '')),
      if (_slug(_move).isNotEmpty) ('${tr('Golpe')}: ${_move.trim()}', () => _setExtra(() => _move = '')),
      if (_sort != null) (_sortLabel(_sort), () => _setExtra(() => _sort = null)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: widget.isForTeamSelection ? 'Escolha um Pokémon' : 'Pokédex',
          subtitle: _isLoading ? null : '${_displayList.length} Pokémon',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SiteSearchField(controller: _searchController, hint: 'Procurar Pokémon por nome ou número'),
        ),
        if (active.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (label, clear) in active)
                  InputChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    onDeleted: clear,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF0284C7),
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    deleteIconColor: Colors.white,
                    side: BorderSide.none,
                  ),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text('Limpar filtros', style: TextStyle(color: c.muted, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  int get _activeCount => [
        _selectedGeneration,
        _selectedGame,
        _version,
        _selectedTypes.isEmpty ? null : 1,
        _tag,
        _slug(_ability).isEmpty ? null : 1,
        _slug(_move).isEmpty ? null : 1,
        _sort,
      ].where((v) => v != null).length;

  void _setGeneration(Generation? g) {
    setState(() => _selectedGeneration = g);
    _loadPokemon();
  }

  void _setGame(Game? g) {
    setState(() {
      _selectedGame = g;
      _version = null;
    });
    _loadPokemon();
  }

  void _setVersion(String? v) {
    setState(() => _version = v);
    _loadFilterData().then((_) => _filterPokemon());
  }

  void _setExtra(VoidCallback change) {
    setState(change);
    _filterPokemon();
  }

  String _tagLabel(String? tag) => switch (tag) {
        'legendary' => tr('Lendários'),
        'mythical' => tr('Míticos'),
        'baby' => tr('Bebês'),
        _ => tr('Todos'),
      };

  String _sortLabel(int? i) => i == null
      ? tr('Número da Pokédex')
      : i == 6
          ? tr('Total dos status (maior)')
          : tr('{0} (maior)').replaceAll('{0}', tr(_statLabels[i]));

  /// Botão flutuante: menu para escolher qual filtro mudar.
  Future<void> _openFiltersMenu() async {
    _loadFilterData();
    final c = SiteColors.of(context);
    Widget tile(IconData icon, String title, String value, VoidCallback onTap, {Color? color}) => ListTile(
          leading: CircleAvatar(backgroundColor: (color ?? const Color(0xFF0284C7)).withAlpha(40), child: Icon(icon, color: color ?? const Color(0xFF38BDF8))),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              const Text('Filtros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              tile(Icons.public, tr('Geração'), _selectedGeneration?.name ?? tr('Todas as gerações'),
                  () => GenerationPicker(value: _selectedGeneration, onChanged: _setGeneration).open(context)),
              tile(Icons.videogame_asset, tr('Jogo'), _selectedGame?.name ?? tr('Todos os jogos'),
                  () => GamePicker(value: _selectedGame, onChanged: _setGame).open(context)),
              if (_selectedGame?.versions.isNotEmpty ?? false)
                tile(Icons.call_split, tr('Versão'), _version ?? tr('Todas as versões'), _openVersions),
              tile(Icons.local_fire_department, tr('Tipos'),
                  _selectedTypes.isEmpty ? tr('Todos') : _selectedTypes.map((t) => t.capitalise()).join(' + '), _openTypes),
              tile(Icons.star, tr('Categoria'), _tagLabel(_tag), _openCategory),
              tile(Icons.bolt, tr('Habilidade e golpe'),
                  [if (_ability.trim().isNotEmpty) _ability.trim(), if (_move.trim().isNotEmpty) _move.trim()].join(' · ').isEmpty
                      ? tr('Todos')
                      : [if (_ability.trim().isNotEmpty) _ability.trim(), if (_move.trim().isNotEmpty) _move.trim()].join(' · '),
                  _openAbilityMove),
              tile(Icons.sort, tr('Ordenar por'), _sortLabel(_sort), _openSort),
              if (_activeCount > 0)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    _clearFilters();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpar filtros'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Uma folha simples com título (para cada filtro).
  Future<void> _sheet(String title, Widget Function(BuildContext sheet, StateSetter update) body) {
    final c = SiteColors.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(sheet).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                body(sheet, update),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openVersions() => _sheet(tr('Versão'), (sheet, update) {
        final game = _selectedGame!;
        return Column(
          children: [
            for (final v in <String?>[null, ...game.versions])
              _Choice(
                selected: v == _version,
                title: Text(v ?? tr('Todas as versões')),
                subtitle: v == null ? null : Text(tr('Tira os exclusivos da outra versão.')),
                onTap: () {
                  Navigator.pop(sheet);
                  _setVersion(v);
                },
              ),
          ],
        );
      });

  void _openTypes() => _sheet(tr('Tipos (até dois)'), (sheet, update) {
        return Column(
          children: [
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: [
                for (final type in pokemonTypeColors.keys)
                  _TypeOption(
                    type: type,
                    active: _selectedTypes.contains(type),
                    dimmed: _selectedTypes.isNotEmpty && !_selectedTypes.contains(type),
                    onTap: () {
                      _toggleType(type);
                      update(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(sheet), child: const Text('Pronto')),
            ),
          ],
        );
      });

  void _openCategory() => _sheet(tr('Categoria'), (sheet, update) {
        return Column(
          children: [
            for (final t in <String?>[null, 'legendary', 'mythical', 'baby'])
              _Choice(
                selected: t == _tag,
                title: Text(_tagLabel(t)),
                onTap: () {
                  Navigator.pop(sheet);
                  _setExtra(() => _tag = t);
                },
              ),
          ],
        );
      });

  void _openSort() => _sheet(tr('Ordenar por'), (sheet, update) {
        return Column(
          children: [
            for (final i in <int?>[null, 6, 0, 1, 2, 3, 4, 5])
              _Choice(
                selected: i == _sort,
                title: Text(_sortLabel(i)),
                onTap: () {
                  Navigator.pop(sheet);
                  _setExtra(() => _sort = i);
                },
              ),
          ],
        );
      });

  void _openAbilityMove() => _sheet(tr('Habilidade e golpe'), (sheet, update) {
        return Column(
          children: [
            _extraFilters(SiteColors.of(context)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(sheet), child: const Text('Pronto')),
            ),
          ],
        );
      });

  Widget _extraFilters(SiteColors c) {
    InputDecoration deco(String label, [String? hint]) =>
        InputDecoration(labelText: tr(label), hintText: hint, isDense: true, border: const OutlineInputBorder());
    Widget auto(String label, String hint, List<String> options, String value, ValueChanged<String> onChanged) =>
        Autocomplete<String>(
          initialValue: TextEditingValue(text: value),
          optionsBuilder: (v) {
            final q = _slug(v.text);
            if (q.isEmpty) return const Iterable<String>.empty();
            return options.where((o) => o.contains(q)).take(20).map((o) => o.replaceAll('-', ' ').capitalise());
          },
          onSelected: (v) {
            onChanged(v);
            _filterPokemon();
          },
          fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
            controller: controller,
            focusNode: focus,
            decoration: deco(label, hint),
            onChanged: (v) {
              onChanged(v);
              _filterPokemon();
            },
          ),
        );
    return Column(
      children: [
        auto('Habilidade', 'Ex.: Intimidate', _abilityNames, _ability, (v) => _ability = v),
        const SizedBox(height: 10),
        auto('Aprende o golpe', 'Ex.: Earthquake', _moves.keys.toList()..sort(), _move, (v) => _move = v),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final wide = Responsive.isWide(context) && !widget.isForTeamSelection;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isForTeamSelection ? 'Selecione um Pokémon' : 'Pokédex'),
        leading: widget.isForTeamSelection
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(null))
            : null,
      ),
      // Filtros: o botão flutuante abre um menu para escolher qual.
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pokedex-filters',
        onPressed: _openFiltersMenu,
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.tune),
        label: Text(_activeCount > 0 ? '${tr('Filtros')} ($_activeCount)' : tr('Filtros')),
      ),
      body: wide
          // Tela grande (tablet/PC): cards horizontais e detalhes na própria página.
          ? Column(children: [_header(c), Expanded(child: PokedexWebGrid(pokemon: _displayList))])
          : CustomScrollView(
              key: const PageStorageKey('pokedex_scroll'),
              slivers: [
                SliverToBoxAdapter(child: _header(c)),
                if (_isLoading)
                  const SliverFillRemaining(hasScrollBody: false, child: PikachuLoadingIndicator())
                else if (_displayList.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyMessage(
                        _searchController.text.isNotEmpty ? 'Nenhum Pokémon encontrado.' : 'Nenhum Pokémon com esses filtros.'),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Responsive.columns(context, min: 3),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _displayList.length,
                      itemBuilder: (context, index) {
                        final pokemon = _displayList[index];
                        return PokemonCard(
                          key: ValueKey(pokemon.url),
                          pokemonListing: pokemon,
                          onTap: () => _handlePokemonSelection(pokemon),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String type;
  final bool active;
  final bool dimmed;
  final VoidCallback onTap;
  const _TypeOption({required this.type, required this.active, required this.dimmed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: getColorForType(type),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: active ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(type.capitalise(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

/// Uma opção de uma lista (marcada com ✓ quando escolhida).
class _Choice extends StatelessWidget {
  final bool selected;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;
  const _Choice({required this.selected, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? const Color(0xFF38BDF8) : Theme.of(context).hintColor),
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      );
}
