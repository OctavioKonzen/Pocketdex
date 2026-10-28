// lib/screens/home_screen.dart

import 'dart:async';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:flutter/material.dart' hide Text;

import 'package:pocket_dex/models/pokemon_listing.dart';
import 'package:pocket_dex/screens/pokedex_screen.dart';
import 'package:pocket_dex/screens/pokemon_detail_screen.dart';
import 'package:pocket_dex/screens/teams_screen.dart';
import 'package:pocket_dex/screens/encyclopedia_screen.dart';
import 'package:pocket_dex/screens/training_screen.dart';
import 'package:pocket_dex/screens/game_screen.dart';
import 'package:pocket_dex/screens/favorites_screen.dart';
import 'package:pocket_dex/screens/battle_center_screen.dart';
import 'package:pocket_dex/screens/friends_screen.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/utils/pokemon_colors.dart';
import 'package:pocket_dex/utils/string_extensions.dart';
import 'package:pocket_dex/utils/site_ui.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';
import 'package:pocket_dex/screens/settings_screen.dart';
import 'package:pocket_dex/utils/responsive.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';
import 'package:pocket_dex/widgets/account_avatar.dart';
import 'package:pocket_dex/services/auth_service.dart';
import 'package:pocket_dex/services/update_service.dart';
import 'package:pocket_dex/i18n/text.dart';
import 'package:pocket_dex/i18n/i18n.dart';
import 'package:pocket_dex/widgets/type_chip.dart';
import 'package:pocket_dex/widgets/daily_pokemon_card.dart';

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
  // Campo de busca: a lista de resultados tem a mesma largura dele.
  final GlobalKey _searchFieldKey = GlobalKey();

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
    // Versão nova do app publicada? Oferece atualizar direto por aqui.
    WidgetsBinding.instance.addPostFrameCallback((_) => UpdateService.checkOnStart(context));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Falha ao carregar a lista de Pokémon.')));
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
        _searchResults = _allPokemonList
            .where((pokemon) {
              return I18n.nameMatches(pokemon.name, trimmedQuery) ||
                  pokemon.id == trimmedQuery;
            })
            .take(3)
            .toList();
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
                child: ReadableWidth(
                  maxWidth: 960,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Responsive.isWide(context)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [_buildHeader(theme), _buildCategoryGrid()],
                              )
                            // Celular: o menu rola (são 8 cards).
                            : ListView(
                                padding: const EdgeInsets.only(bottom: 80),
                                children: [_buildHeader(theme), _buildCategoryGrid()],
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
      ),
      // Com conta, as Configurações ficam no menu do avatar (no topo).
      floatingActionButton: AuthService.instance.status == AuthStatus.signedIn
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              tooltip: tr('Configurações'),
              backgroundColor: theme.colorScheme.secondary,
              child: Icon(Icons.settings, color: theme.colorScheme.onSecondary),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo à esquerda e, com conta, a foto de perfil (toque para abrir o perfil).
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: Row(
            children: [
              Image.asset('assets/images/poke_logo.png', height: 64),
              const Spacer(),
              if (AuthService.instance.status == AuthStatus.signedIn)
                AccountAvatar(size: 44, onTap: () => ProfileSheet.show(context)),
            ],
          ),
        ),
        CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            key: _searchFieldKey,
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: tr('Procurar Pokémon'),
              hintStyle: TextStyle(color: theme.hintColor),
              prefixIcon: Icon(Icons.search, color: theme.hintColor),
              filled: true,
              fillColor: SiteColors.of(context).card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: SiteColors.of(context).line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: SiteColors.of(context).line),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const DailyPokemonCard(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResultsOverlay(ThemeData theme) {
    final field = _searchFieldKey.currentContext?.size;
    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: Offset(0, (field?.height ?? 56) + 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: field?.width,
          // Mesmo estilo dos cards do app: cantos de 20 e sombra.
          child: Material(
            color: theme.cardColor,
            elevation: 10,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildSearchResultsList(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList(ThemeData theme) {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Nenhum Pokémon encontrado.',
            style:
                TextStyle(color: theme.colorScheme.onSurface.withAlpha(178))),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _searchResults.map((pokemon) {
        return _SearchResultTile(
          // Um por Pokémon: sem isso, ao digitar mais letras o card mantinha
          // os dados (número, tipo, sprite) do resultado anterior.
          key: ValueKey(pokemon.url),
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

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (context) => screen));

  // As seções do app em cards escuros do novo visual (ícone na cor da seção).
  Widget _buildCategoryGrid() {
    final sections = [
      (Icons.catching_pokemon, 'Pokédex', SectionColors.pokedex, const PokedexScreen()),
      (Icons.star, 'Favoritos', SectionColors.favorites, const FavoritesScreen()),
      (Icons.groups, 'Time', SectionColors.teams, const TeamsScreen()),
      (Icons.sports_esports, 'Jogo', SectionColors.game, const GameScreen()),
      (Icons.bolt, 'Batalha', const Color(0xFF90A4AE), const BattleCenterScreen()),
      (Icons.menu_book, 'Enciclopédia', SectionColors.encyclopedia, const EncyclopediaScreen()),
      (Icons.fitness_center, 'Treino', SectionColors.training, const TrainingScreen()),
      (Icons.chat, 'Amigos', const Color(0xFF5C6BC0), const FriendsScreen()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Explorar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.isWide(context) ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 104,
          ),
          children: [
            for (final (icon, title, color, screen) in sections)
              ModeCard(compact: true, height: 104, icon: icon, title: title, color: color, onTap: () => _open(screen)),
          ],
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final PokemonListing pokemon;
  final VoidCallback onTap;
  const _SearchResultTile({super.key, required this.pokemon, required this.onTap});
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

  @override
  void didUpdateWidget(_SearchResultTile old) {
    super.didUpdateWidget(old);
    if (old.pokemon.url != widget.pokemon.url) {
      _details = null;
      _fetchDetails();
    }
  }

  Future<void> _fetchDetails() async {
    try {
      if (_cache.containsKey(widget.pokemon.url)) {
        if (mounted) setState(() => _details = _cache[widget.pokemon.url]);
        return;
      }
      final data =
          await PokemonService().fetchPokemonJsonByUrl(widget.pokemon.url);
      if (mounted) {
        _cache[widget.pokemon.url] = data;
        setState(() => _details = data);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_details == null) return const SizedBox(height: 76);
    final int id = _details!['id'] as int;
    final String name = I18n.pokemonName(widget.pokemon.name.split('-').first.capitalise());
    final List<String> types = [for (final t in _details!['types'] as List) t['type']['name'] as String];
    // Um card da Pokédex em miniatura: cor do tipo, Pokébola ao fundo, nome,
    // número e tipos (igual aos cards e ao site).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 76,
          decoration: typeBackground(types, borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned(
                    right: -14,
                    top: -14,
                    bottom: -14,
                    child: Opacity(opacity: 0.12, child: Image.asset('assets/images/pokeball.png', width: 104, cacheWidth: 208)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('#${id.toString().padLeft(3, '0')}',
                                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TypeChips(types),
                            ],
                          ),
                        ),
                        SizedBox.square(dimension: 60, child: PokemonSprite(id, fill: 0.9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
