// lib/screens/pokedex_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/generation.dart';
import '../models/pokemon_listing.dart';
import '../services/pokemon_service.dart';
import '../utils/pokemon_colors.dart';
import '../widgets/generation_card.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/pikachu_loading_indicator.dart';
import 'pokemon_detail_screen.dart';
import 'favorites_screen.dart';

class PokedexScreen extends StatefulWidget {
  final bool isForTeamSelection;

  const PokedexScreen({
    super.key,
    this.isForTeamSelection = false,
  });

  @override
  PokedexScreenState createState() => PokedexScreenState();
}

class PokedexScreenState extends State<PokedexScreen> with SingleTickerProviderStateMixin {
  final PokemonService _pokemonService = PokemonService();
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  bool _isMenuOpen = false;

  List<PokemonListing> _fullPokemonList = [];
  List<PokemonListing> _displayList = [];
  Generation? _selectedGeneration;
  List<String> _selectedTypes = [];

  bool _isSearchVisible = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPokemon();
    _searchController.addListener(_filterPokemon);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPokemon() async {
    setState(() => _isLoading = true);
    try {
      List<PokemonListing> pokemonList;
      if (_selectedTypes.isNotEmpty) {
        pokemonList = await _pokemonService.fetchPokemonByTypes(_selectedTypes);
      } else if (_selectedGeneration != null) {
        pokemonList = await _pokemonService.fetchPokedex(_selectedGeneration!);
      } else {
        pokemonList = await _pokemonService.fetchAllPokemonList();
      }

      if (mounted) {
        setState(() {
          _fullPokemonList = pokemonList;
          _displayList = pokemonList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar Pokémon da API: $e')));
      }
    }
  }

  void _filterPokemon() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _displayList = _fullPokemonList.where((pokemon) {
        return pokemon.name.toLowerCase().contains(query) ||
            pokemon.id.contains(query);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
      }
    });
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _showTypeSelector() {
    final theme = Theme.of(context);
    List<String> tempSelectedTypes = List.from(_selectedTypes);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Filtrar por Tipo', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Selecione até dois tipos', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: pokemonTypeColors.keys.length,
                        itemBuilder: (context, index) {
                          final type = pokemonTypeColors.keys.elementAt(index);
                          return FilterChip(
                            label: Text(type[0].toUpperCase() + type.substring(1)),
                            selected: tempSelectedTypes.contains(type),
                            onSelected: (bool selected) {
                              modalState(() {
                                if (selected) {
                                  if (tempSelectedTypes.length < 2) {
                                    tempSelectedTypes.add(type);
                                  }
                                } else {
                                  tempSelectedTypes.remove(type);
                                }
                              });
                            },
                            backgroundColor: getColorForType(type).withAlpha(50),
                            selectedColor: getColorForType(type),
                            labelStyle: TextStyle(
                              color: tempSelectedTypes.contains(type)
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                            checkmarkColor: Colors.white,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTypes.clear();
                              _selectedGeneration = null;
                            });
                             Navigator.pop(context);
                            _loadPokemon();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
                          child: const Text('Limpar Filtros'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTypes = tempSelectedTypes;
                              _selectedGeneration = null;
                            });
                            Navigator.pop(context);
                            _loadPokemon();
                          },
                          child: const Text('Aplicar'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showGenerationSelector() {
    final theme = Theme.of(context);
    showModalBottomSheet(
        context: context,
        backgroundColor: theme.cardColor,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 12.0),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade700,
                                    borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 24),
                        Text('Filtrar por Geração',
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 20),
                        Expanded(
                            child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 1.2),
                                itemCount: generations.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedGeneration = null;
                                            _selectedTypes.clear();
                                          });
                                          Navigator.pop(context);
                                          _loadPokemon();
                                        },
                                        child: Container(
                                            decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Center(
                                                child: Text('Todas as Gerações',
                                                    style: TextStyle(
                                                        color: theme.colorScheme
                                                            .onSurface,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16)))));
                                  }
                                  final generation = generations[index - 1];
                                  return GenerationCard(
                                      generation: generation,
                                      onTap: () {
                                        setState(() {
                                          _selectedGeneration = generation;
                                          _selectedTypes.clear();
                                        });
                                        Navigator.pop(context);
                                        _loadPokemon();
                                      });
                                }))
                      ])));
        });
  }

  Future<void> _handlePokemonSelection(PokemonListing pokemon) async {
    if (widget.isForTeamSelection) {
      Navigator.of(context)
          .pop({'id': pokemon.id, 'imageUrl': pokemon.imageUrl});
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PokemonDetailScreen(
            initialPokemonId: int.parse(pokemon.id),
          ),
        ),
      );
    }
  }

  Widget _buildMenuItem(
      {required String text,
      required IconData icon,
      required VoidCallback onTap,
      required Animation<double> animation}) {
    return FadeTransition(
        opacity: animation,
        child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 0.5), end: Offset.zero)
                .animate(animation),
            child: InkWell(
                onTap: onTap,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26, blurRadius: 4)
                              ]),
                          child: Text(text,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      CircleAvatar(child: Icon(icon, color: Colors.white))
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String currentTitle =
        widget.isForTeamSelection ? 'Selecione um Pokémon' : 'Pokédex';

    return Scaffold(
        appBar: AppBar(
            title: Text(currentTitle),
            leading: widget.isForTeamSelection
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(null))
                : null),
        body: Stack(children: [
          Column(children: [
            AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isSearchVisible ? 70.0 : 0.0,
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: TextField(
                            controller: _searchController,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                            decoration: InputDecoration(
                                hintText: 'Procurar Pokémon por nome ou nú...',
                                hintStyle:
                                    TextStyle(color: theme.hintColor),
                                prefixIcon: Icon(Icons.search,
                                    color: theme.hintColor),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none)))))),
            Expanded(
                child: _isLoading
                    ? const PikachuLoadingIndicator()
                    : _displayList.isEmpty
                        ? Center(
                            child: Text(
                                _searchController.text.isNotEmpty
                                    ? 'Nenhum Pokémon encontrado.'
                                    : 'Nenhum Pokémon na Pokédex.',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(178))))
                        : GridView.builder(
                            key: const PageStorageKey('pokedex_grid'),
                            padding:
                                const EdgeInsets.fromLTRB(20, 10, 20, 80),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.8),
                            itemCount: _displayList.length,
                            itemBuilder: (context, index) {
                              final pokemon = _displayList[index];
                              return PokemonCard(
                                  key: ValueKey(pokemon.url),
                                  pokemonListing: pokemon,
                                  onTap: () =>
                                      _handlePokemonSelection(pokemon));
                            }))
          ]),
          if (_isMenuOpen)
            GestureDetector(
                onTap: _toggleMenu,
                child: Container(color: Colors.black.withAlpha(128)))
        ]),
        floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildMenuItem(
                  text: 'Procurar',
                  icon: Icons.search,
                  onTap: () {
                    _toggleMenu();
                    _toggleSearch();
                  },
                  animation: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.2, 1.0))),
              const SizedBox(height: 12),
              _buildMenuItem(
                  text: 'Filtrar por Geração',
                  icon: Icons.public,
                  onTap: () {
                    _toggleMenu();
                    _showGenerationSelector();
                  },
                  animation: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.4, 1.0))),
              const SizedBox(height: 12),
              _buildMenuItem(
                text: 'Filtrar por Tipo',
                icon: Icons.shield_outlined,
                onTap: () {
                  _toggleMenu();
                  _showTypeSelector();
                },
                animation: CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.6, 1.0))),
              const SizedBox(height: 12),
              _buildMenuItem(
                  text: 'Favoritos',
                  icon: Icons.favorite,
                  onTap: () {
                    _toggleMenu();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const FavoritesScreen()));
                  },
                  animation: CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.8, 1.0))),
              const SizedBox(height: 16),
              FloatingActionButton(
                  onPressed: _toggleMenu,
                  child: AnimatedIcon(
                      icon: AnimatedIcons.menu_close,
                      progress: _animationController))
            ]));
  }
}