// lib/screens/pokedex_screen.dart
//
// Pokédex no estilo do site: cabeçalho com a quantidade, busca, seletor de
// geração e filtro de tipos no topo (sem menu flutuante), e os cards em grade.
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
  bool _showTypes = false;
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
    if (!mounted) return;
    setState(() {
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

  bool get _extraActive => _tag != null || _slug(_ability).isNotEmpty || _slug(_move).isNotEmpty || _sort != null;

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
    final filters = _selectedGeneration != null || _selectedGame != null || _selectedTypes.isNotEmpty || _extraActive;
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
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              GenerationPicker(
                value: _selectedGeneration,
                onChanged: (g) {
                  setState(() => _selectedGeneration = g);
                  _loadPokemon();
                },
              ),
              const SizedBox(width: 8),
              GamePicker(
                value: _selectedGame,
                onChanged: (g) {
                  setState(() => _selectedGame = g);
                  _loadPokemon();
                },
              ),
              const SizedBox(width: 8),
              _TypesButton(
                types: _selectedTypes,
                extra: [_tag, _slug(_ability), _slug(_move), _sort].where((v) => v != null && v != '').length,
                open: _showTypes,
                onTap: () {
                  setState(() => _showTypes = !_showTypes);
                  _loadFilterData();
                },
              ),
              if (filters)
                TextButton(
                  onPressed: _clearFilters,
                  child: Text('Limpar filtros', style: TextStyle(color: c.muted, decoration: TextDecoration.underline)),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showTypes ? _typeGrid(c) : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _typeGrid(SiteColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tipos (até dois)', style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 10),
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
                  onTap: () => _toggleType(type),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _extraFilters(c),
        ],
      ),
    );
  }

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
        DropdownButtonFormField<String?>(
          initialValue: _tag,
          decoration: deco('Categoria'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Todos')),
            DropdownMenuItem(value: 'legendary', child: Text('Lendários')),
            DropdownMenuItem(value: 'mythical', child: Text('Míticos')),
            DropdownMenuItem(value: 'baby', child: Text('Bebês')),
          ],
          onChanged: (v) {
            setState(() => _tag = v);
            _filterPokemon();
          },
        ),
        const SizedBox(height: 10),
        auto('Habilidade', 'Ex.: Intimidate', _abilityNames, _ability, (v) => _ability = v),
        const SizedBox(height: 10),
        auto('Aprende o golpe', 'Ex.: Earthquake', _moves.keys.toList()..sort(), _move, (v) => _move = v),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          initialValue: _sort,
          decoration: deco('Ordenar por'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Número da Pokédex')),
            const DropdownMenuItem(value: 6, child: Text('Total dos status (maior)')),
            for (var i = 0; i < 6; i++) DropdownMenuItem(value: i, child: Text('${_statLabels[i]} (maior)')),
          ],
          onChanged: (v) {
            setState(() => _sort = v);
            _filterPokemon();
          },
        ),
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

class _TypesButton extends StatelessWidget {
  final List<String> types;
  final int extra;
  final bool open;
  final VoidCallback onTap;
  const _TypesButton({required this.types, required this.open, required this.onTap, this.extra = 0});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final active = types.isNotEmpty || extra > 0;
    return Material(
      color: active ? const Color(0xFF0284C7) : c.surface,
      shape: StadiumBorder(side: BorderSide(color: c.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list, size: 18, color: active ? Colors.white : c.text),
              const SizedBox(width: 6),
              Text(
                '${tr('Filtros')}${types.isNotEmpty ? ': ${types.map((t) => t.capitalise()).join(' + ')}' : ''}${extra > 0 ? ' (+$extra)' : ''}',
                style: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.white : c.text),
              ),
              Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: active ? Colors.white : c.muted),
            ],
          ),
        ),
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
