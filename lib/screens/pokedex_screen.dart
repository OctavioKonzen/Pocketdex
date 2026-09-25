// lib/screens/pokedex_screen.dart
//
// Pokédex no estilo do site: cabeçalho com a quantidade, busca, seletor de
// geração e filtro de tipos no topo (sem menu flutuante), e os cards em grade.
// Também usada para escolher um Pokémon (times e treino de EVs).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/generation.dart';
import '../models/pokemon_listing.dart';
import '../services/account_format.dart';
import '../services/local_database.dart';
import '../services/pokemon_service.dart';
import '../utils/pokemon_colors.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/generation_picker.dart';
import '../widgets/pikachu_loading_indicator.dart';
import '../widgets/pokedex_web/pokedex_web_grid.dart';
import '../widgets/pokemon_card.dart';
import 'pokemon_detail_screen.dart';

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
  List<String> _selectedTypes = [];
  bool _showTypes = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPokemon();
    _searchController.addListener(_filterPokemon);
    widget.searchQuery?.addListener(_onExternalSearch);
  }

  void _onExternalSearch() => _searchController.text = widget.searchQuery!.value;

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
      if (_selectedTypes.isNotEmpty) {
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
    setState(() {
      _displayList = query.isEmpty
          ? _fullPokemonList
          : _fullPokemonList.where((p) => p.name.toLowerCase().contains(query) || p.id == query).toList();
    });
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
      _selectedTypes = [];
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
    final filters = _selectedGeneration != null || _selectedTypes.isNotEmpty;
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
              _TypesButton(
                types: _selectedTypes,
                open: _showTypes,
                onTap: () => setState(() => _showTypes = !_showTypes),
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
          Text('Selecione até dois tipos', style: TextStyle(color: c.muted, fontSize: 13)),
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
        ],
      ),
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
  final bool open;
  final VoidCallback onTap;
  const _TypesButton({required this.types, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final active = types.isNotEmpty;
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
                active ? 'Tipos: ${types.map((t) => t.capitalise()).join(' + ')}' : 'Tipos',
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
