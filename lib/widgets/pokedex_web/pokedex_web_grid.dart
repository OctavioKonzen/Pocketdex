// lib/widgets/pokedex_web/pokedex_web_grid.dart
//
// Grade da Pokédex no site (PC). Ao clicar em um Pokémon, os detalhes abrem
// logo abaixo da linha dele, empurrando os outros cards para baixo.

import 'package:flutter/material.dart';

import '../../models/pokemon_listing.dart';
import 'pokedex_inline_details.dart';
import 'pokedex_web_card.dart';

class PokedexWebGrid extends StatefulWidget {
  final List<PokemonListing> pokemon;

  const PokedexWebGrid({super.key, required this.pokemon});

  @override
  State<PokedexWebGrid> createState() => _PokedexWebGridState();
}

class _PokedexWebGridState extends State<PokedexWebGrid> {
  static const _horizontalPadding = 24.0;

  final ScrollController _scrollController = ScrollController();
  String? _selectedUrl;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PokedexWebGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fecha o painel se o Pokémon aberto saiu da lista (busca/filtro).
    if (_selectedUrl != null &&
        !widget.pokemon.any((p) => p.url == _selectedUrl)) {
      _selectedUrl = null;
    }
  }

  int get _selectedIndex => _selectedUrl == null
      ? -1
      : widget.pokemon.indexWhere((p) => p.url == _selectedUrl);

  void _select(PokemonListing? pokemon, {required int columns}) {
    final previousRow = _selectedIndex < 0 ? -1 : _selectedIndex ~/ columns;
    setState(() =>
        _selectedUrl = pokemon?.url == _selectedUrl ? null : pokemon?.url);
    final index = _selectedIndex;
    if (index < 0) return;
    final row = index ~/ columns;
    if (row == previousRow) return;
    // Rola suavemente até a linha do Pokémon aberto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      const rowExtent = PokedexCardStyle.height + PokedexCardStyle.spacing;
      // Deixa a linha do card no topo, com o painel logo abaixo.
      final target = (row * rowExtent)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic);
    });
  }

  void _selectById(int id, {required int columns}) {
    final match = widget.pokemon.where((p) => p.id == '$id');
    if (match.isNotEmpty) {
      _select(match.first, columns: columns);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth - _horizontalPadding * 2;
      // 6 por linha; menos só se a tela for estreita demais para 6.
      final fit = ((available + PokedexCardStyle.spacing) /
              (PokedexCardStyle.minWidth + PokedexCardStyle.spacing))
          .floor();
      final columns = fit.clamp(2, PokedexCardStyle.columns);
      final rows = (widget.pokemon.length / columns).ceil();
      final selectedIndex = _selectedIndex;
      final selectedRow = selectedIndex < 0 ? -1 : selectedIndex ~/ columns;

      return ListView.builder(
        key: const PageStorageKey('pokedex_web_grid'),
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
            _horizontalPadding, 12, _horizontalPadding, 96),
        itemCount: rows,
        itemBuilder: (context, row) {
          final start = row * columns;
          return Padding(
            padding: const EdgeInsets.only(bottom: PokedexCardStyle.spacing),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var col = 0; col < columns; col++) ...[
                      if (col > 0)
                        const SizedBox(width: PokedexCardStyle.spacing),
                      Expanded(
                        child: start + col < widget.pokemon.length
                            // O card aberto cresce e some (ele "vira" o painel).
                            ? _GrowAndFade(
                                hidden: start + col == selectedIndex,
                                child: PokedexWebCard(
                                  key:
                                      ValueKey(widget.pokemon[start + col].url),
                                  pokemon: widget.pokemon[start + col],
                                  isSelected: start + col == selectedIndex,
                                  onTap: () => _select(
                                      widget.pokemon[start + col],
                                      columns: columns),
                                ),
                              )
                            : const SizedBox(height: PokedexCardStyle.height),
                      ),
                    ],
                  ],
                ),
                // Painel de detalhes abrindo/fechando com animação.
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: row == selectedRow
                      ? Padding(
                          padding: const EdgeInsets.only(
                              top: PokedexCardStyle.spacing),
                          // Bucket próprio: as abas do painel não herdam a
                          // posição de rolagem da lista da Pokédex.
                          child: _GrowFromCard(
                              key: ValueKey(_selectedUrl),
                              // Cresce a partir da coluna do card clicado.
                              alignment: Alignment(
                                  -1 +
                                      2 *
                                          (selectedIndex % columns + 0.5) /
                                          columns,
                                  -1),
                              child: PageStorage(
                                  bucket: PageStorageBucket(),
                                  child: PokedexInlineDetails(
                                    pokemonId: int.parse(
                                        widget.pokemon[selectedIndex].id),
                                    hasPrevious: selectedIndex > 0,
                                    hasNext: selectedIndex <
                                        widget.pokemon.length - 1,
                                    onPrevious: () => _select(
                                        widget.pokemon[selectedIndex - 1],
                                        columns: columns),
                                    onNext: () => _select(
                                        widget.pokemon[selectedIndex + 1],
                                        columns: columns),
                                    onNavigate: (id) =>
                                        _selectById(id, columns: columns),
                                    onClose: () =>
                                        _select(null, columns: columns),
                                  ))),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

/// Card que cresce e desaparece quando [hidden] (ao abrir os detalhes).
class _GrowAndFade extends StatelessWidget {
  final bool hidden;
  final Widget child;

  const _GrowAndFade({required this.hidden, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedScale(
        scale: hidden ? 1.35 : 1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: child,
        ),
      ),
    );
  }
}

/// Painel que "sai" do card: começa pequeno na posição do card e cresce.
class _GrowFromCard extends StatelessWidget {
  final Alignment alignment;
  final Widget child;

  const _GrowFromCard(
      {super.key, required this.alignment, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.15 + 0.85 * value,
          alignment: alignment,
          child: child,
        ),
      ),
    );
  }
}
