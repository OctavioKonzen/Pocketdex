// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'package:pocket_dex/models/pokemon_listing.dart';
import 'package:pocket_dex/screens/pokedex_screen.dart';
import 'package:pocket_dex/screens/pokemon_detail_screen.dart';
import 'package:pocket_dex/screens/teams_screen.dart';
import 'package:pocket_dex/screens/encyclopedia_screen.dart';
import 'package:pocket_dex/screens/training_screen.dart';
import 'package:pocket_dex/screens/game_screen.dart';
import 'package:pocket_dex/screens/favorites_screen.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/utils/pokemon_colors.dart';
import 'package:pocket_dex/utils/string_extensions.dart';
import 'package:pocket_dex/widgets/category_card.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';
import 'package:pocket_dex/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PokemonService _pokemonService = PokemonService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  final Debouncer<String> _debouncer =
      Debouncer(const Duration(milliseconds: 300), initialValue: '');
  late StreamSubscription<String> _debouncerSubscription;

  List<PokemonListing> _allPokemonList = [];
  List<PokemonListing> _searchResults = [];
  bool _isLoadingPokemonList = true;
  bool _showResultsOverlay = false;

  @override
  void initState() {
    super.initState();
    _loadAllPokemon();
    _searchController.addListener(() {
      _debouncer.value = _searchController.text;
    });
    _debouncerSubscription = _debouncer.values.listen((query) {
      _onSearchChanged(query);
    });
    _searchFocusNode.addListener(() {
      setState(() {
        _showResultsOverlay =
            _searchFocusNode.hasFocus && _searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debouncerSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadAllPokemon() async {
    setState(() {
      _isLoadingPokemonList = true;
    });
    try {
      final list = await _pokemonService.fetchAllPokemonList();
      if (mounted) {
        setState(() {
          _allPokemonList = list;
          _isLoadingPokemonList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPokemonList = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao carregar a lista de Pokémon.')));
      }
    }
  }

  void _onSearchChanged(String query) {
    final trimmedQuery = query.trim().toLowerCase();
    setState(() {
      if (trimmedQuery.isEmpty) {
        _searchResults.clear();
        _showResultsOverlay = false;
      } else {
        _searchResults = _allPokemonList.where((pokemon) {
          return pokemon.name.toLowerCase().contains(trimmedQuery) ||
              pokemon.id == trimmedQuery;
        }).take(3).toList();
        _showResultsOverlay = true;
      }
    });
  }

  void _dismissSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: _isLoadingPokemonList
            ? const Center(child: PikachuLoadingIndicator(size: 100))
            : GestureDetector(
                onTap: _dismissSearch,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(theme),
                          Expanded(child: _buildCategoryGrid()),
                        ],
                      ),
                    ),
                    if (_showResultsOverlay)
                      GestureDetector(
                        onTap: _dismissSearch,
                        child: Container(
                          color: Colors.black.withAlpha(128),
                        ),
                      ),
                    if (_showResultsOverlay) _buildResultsOverlay(theme),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
        tooltip: 'Configurações',
        backgroundColor: theme.colorScheme.secondary,
        child: Icon(Icons.settings, color: theme.colorScheme.onSecondary),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 20.0),
          child: Center(
            child: Image.asset(
              'assets/images/poke_logo.png',
              height: 150,
            ),
          ),
        ),
        CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Procurar Pokémon por nome ou nú...',
              hintStyle: TextStyle(color: theme.hintColor),
              prefixIcon: Icon(Icons.search, color: theme.hintColor),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResultsOverlay(ThemeData theme) {
    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: const Offset(0, 60),
      child: Material(
        color: theme.cardColor,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: _buildSearchResultsList(theme),
      ),
    );
  }

  Widget _buildSearchResultsList(ThemeData theme) {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Nenhum Pokémon encontrado.',
            style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(178))),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _searchResults.map((pokemon) {
        return _SearchResultTile(
          pokemon: pokemon,
          onTap: () {
            _dismissSearch();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PokemonDetailScreen(
                  initialPokemonId: int.parse(pokemon.id),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        CategoryCard(
          title: 'Pokédex',
          color: Colors.teal.shade400,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (context) => const PokedexScreen())),
        ),
        CategoryCard(
          title: 'Favoritos',
          color: Colors.amber.shade400,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (context) => const FavoritesScreen())),
        ),
        CategoryCard(
          title: 'Time',
          color: Colors.redAccent.shade200,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (context) => const TeamsScreen())),
        ),
        CategoryCard(
          title: 'Jogo',
          color: Colors.blue.shade400,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (context) => const GameScreen())),
        ),
        CategoryCard(
          title: 'Enciclopédia',
          color: Colors.purple.shade400,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const EncyclopediaScreen())),
        ),
        CategoryCard(
          title: 'Treino',
          color: Colors.orange.shade400,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (context) => const TrainingScreen())),
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final PokemonListing pokemon;
  final VoidCallback onTap;
  const _SearchResultTile({required this.pokemon, required this.onTap});
  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  Map<String, dynamic>? _details;
  static final Map<String, Map<String, dynamic>> _cache = {};

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      if (_cache.containsKey(widget.pokemon.url)) {
        if (mounted) setState(() => _details = _cache[widget.pokemon.url]);
        return;
      }
      final response = await http.get(Uri.parse(widget.pokemon.url));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        _cache[widget.pokemon.url] = data;
        setState(() => _details = data);
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_details == null) {
      return const SizedBox(height: 68);
    }
    final String spriteUrl = _details!['sprites']['front_default'] ?? '';
    final String name = (widget.pokemon.name.split('-').first).capitalise();
    final String id = '#${_details!['id'].toString().padLeft(3, '0')}';
    final String type = _details!['types'][0]['type']['name'];
    final Color backgroundColor = getColorForType(type).withAlpha(220);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              if (spriteUrl.isNotEmpty)
                Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(spriteUrl,
                        width: 48, height: 48, gaplessPlayback: true))
              else
                const SizedBox(width: 56, height: 56),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(id,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(204))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}