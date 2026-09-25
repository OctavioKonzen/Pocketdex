// lib/screens/web_shell.dart
//
// Estrutura do site (PC): barra de navegação no topo e a Pokédex como tela
// principal. Cada seção tem a própria navegação interna, então a barra fica
// sempre visível (ex.: Enciclopédia → Golpes → detalhe do golpe).
// No celular o app continua usando a HomeScreen com os cards de menu.

import 'package:flutter/material.dart';

import '../widgets/hover_scale.dart';
import 'encyclopedia_screen.dart';
import 'favorites_screen.dart';
import 'game_screen.dart';
import 'pokedex_screen.dart';
import 'settings_screen.dart';
import 'teams_screen.dart';
import 'training_screen.dart';

class _WebSection {
  final String label;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  const _WebSection(this.label, this.icon, this.color, this.builder);
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  /// Texto da busca do topo; filtra a Pokédex.
  final ValueNotifier<String> _search = ValueNotifier('');
  final TextEditingController _searchController = TextEditingController();

  // Mesmas cores dos cards do menu do app.
  late final List<_WebSection> _sections = [
    _WebSection('Pokédex', Icons.catching_pokemon, Colors.teal.shade400,
        (_) => PokedexScreen(searchQuery: _search)),
    _WebSection('Favoritos', Icons.star_rounded, Colors.amber.shade400,
        (_) => const FavoritesScreen()),
    _WebSection('Times', Icons.groups_rounded, Colors.redAccent.shade200,
        (_) => const TeamsScreen()),
    _WebSection('Jogo', Icons.videogame_asset_rounded, Colors.blue.shade400,
        (_) => const GameScreen()),
    _WebSection('Enciclopédia', Icons.menu_book_rounded, Colors.purple.shade400,
        (_) => const EncyclopediaScreen()),
    _WebSection('Treino', Icons.fitness_center_rounded, Colors.orange.shade400,
        (_) => const TrainingScreen()),
  ];

  late final List<GlobalKey<NavigatorState>> _navigators =
      List.generate(_sections.length, (_) => GlobalKey<NavigatorState>());

  /// Seções já abertas (as outras só são criadas quando visitadas).
  final Set<int> _visited = {0};
  int _current = 0;

  @override
  void dispose() {
    _search.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index == _current) {
      // Clicar na seção atual volta para o início dela.
      _navigators[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _current = index;
      _visited.add(index);
    });
  }

  void _onSearch(String text) {
    _search.value = text;
    if (_current != 0) _go(0);
    _navigators[0].currentState?.popUntil((route) => route.isFirst);
  }

  void _openSettings() {
    _navigators[_current].currentState?.push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            sections: _sections,
            current: _current,
            onSelect: _go,
            searchController: _searchController,
            onSearch: _onSearch,
            onSettings: _openSettings,
          ),
          Expanded(
            child: IndexedStack(
              index: _current,
              children: [
                for (var i = 0; i < _sections.length; i++)
                  _visited.contains(i)
                      ? Navigator(
                          key: _navigators[i],
                          onGenerateRoute: (_) =>
                              MaterialPageRoute(builder: _sections[i].builder),
                        )
                      : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final List<_WebSection> sections;
  final int current;
  final ValueChanged<int> onSelect;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onSettings;

  const _TopBar({
    required this.sections,
    required this.current,
    required this.onSelect,
    required this.searchController,
    required this.onSearch,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 6,
      shadowColor: Colors.black54,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              HoverScale(
                scale: 1.08,
                child: GestureDetector(
                  onTap: () => onSelect(0),
                  child: Image.asset('assets/images/poke_logo.png', height: 52),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < sections.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _NavButton(
                            section: sections[i],
                            selected: i == current,
                            onTap: () => onSelect(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 280,
                height: 42,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Procurar Pokémon por nome ou número',
                    hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: theme.hintColor),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(21),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Configurações',
                child: HoverScale(
                  scale: 1.15,
                  child: IconButton(
                    onPressed: onSettings,
                    icon: Icon(Icons.settings_rounded,
                        color: theme.colorScheme.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final _WebSection section;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.section.color;
    final foreground =
        widget.selected ? Colors.white : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.section.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: HoverScale(
        scale: 1.08,
        onHoverChanged: (value) => setState(() => _hovering = value),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.selected
                  ? color
                  : _hovering
                      ? color.withAlpha(50)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                          color: color.withAlpha(110),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.section.icon,
                    size: 20,
                    color: widget.selected || _hovering ? foreground : color),
                const SizedBox(width: 8),
                Text(
                  widget.section.label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight:
                        widget.selected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
