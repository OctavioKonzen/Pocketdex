// lib/widgets/pokedex_web/pokedex_web_grid.dart
//
// Grade da Pokédex no site (PC). Ao clicar em um Pokémon, os detalhes abrem
// logo abaixo da linha dele, empurrando os outros cards para baixo.

import 'package:flutter/material.dart';

import '../../models/pokemon_listing.dart';
import '../../services/pokemon_service.dart';
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

  /// Linha onde o painel está aberto (a do Pokémon mostrado).
  int _panelRow = -1;

  /// Muda a cada abertura por clique (reinicia a animação de "crescer a
  /// partir do card"); ao navegar pelas setas o painel só desliza.
  int _openCount = 0;
  bool _openedByClick = false;

  /// Aba do painel, mantida ao trocar de Pokémon.
  int _tab = 0;

  /// Posição da rolagem antes de abrir o painel; ao fechar, volta para ela.
  double? _returnOffset;

  static const _rowExtent = PokedexCardStyle.height + PokedexCardStyle.spacing;
  static const _transition = Duration(milliseconds: 450);
  static const _curve = Curves.easeInOutCubic;

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
      _panelRow = -1;
    }
  }

  int get _selectedIndex => _selectedUrl == null
      ? -1
      : widget.pokemon.indexWhere((p) => p.url == _selectedUrl);

  /// Abre (ou fecha, se já aberto) o Pokémon clicado em um card.
  void _onCardTap(PokemonListing pokemon, int columns) {
    if (pokemon.url == _selectedUrl) {
      _close();
    } else {
      _open(pokemon, columns, byClick: true);
    }
  }

  void _close() {
    setState(() {
      _selectedUrl = null;
      _panelRow = -1;
    });
    final back = _returnOffset;
    _returnOffset = null;
    if (back != null) _scrollTo(back);
  }

  /// Mostra [pokemon] no painel. Se ele estiver em outra linha, o painel
  /// acompanha: o antigo encolhe, o novo cresce e a página rola suavemente
  /// até ele (fica "travada" no Pokémon aberto).
  void _open(PokemonListing pokemon, int columns, {required bool byClick}) {
    final wasOpen = _selectedUrl != null;
    if (!wasOpen && _scrollController.hasClients) {
      _returnOffset = _scrollController.offset;
    }
    final index = widget.pokemon.indexOf(pokemon);
    final row = index ~/ columns;
    final changesRow = row != _panelRow;
    setState(() {
      _selectedUrl = pokemon.url;
      _panelRow = row;
      if (changesRow) {
        _openCount++;
        _openedByClick = byClick || !wasOpen;
      }
    });
    _prefetchNeighbours(index);
    if (changesRow) _scrollTo(row * _rowExtent);
  }

  void _openById(int id, int columns) {
    final match = widget.pokemon.where((p) => p.id == '$id');
    if (match.isNotEmpty) _open(match.first, columns, byClick: false);
  }

  /// Carrega antes os vizinhos, para as setas abrirem sem espera.
  void _prefetchNeighbours(int index) {
    final service = PokemonService();
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < widget.pokemon.length) {
        final id = int.tryParse(widget.pokemon[i].id);
        if (id != null) service.fetchPokemonDetails(id);
      }
    }
  }

  void _scrollTo(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // O alvo é calculado para o layout final (painel antigo já fechado),
      // então rola junto com as animações dos painéis.
      final max = _scrollController.position.maxScrollExtent +
          PokedexInlineDetails.maxHeight;
      _scrollController.animateTo(offset.clamp(0.0, max),
          duration: _transition, curve: _curve);
    });
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
      final selectedRow = selectedIndex < 0 ? -1 : _panelRow;
      // O painel ocupa o espaço visível abaixo da linha do card, sem cortar.
      final panelHeight = (constraints.maxHeight -
              _rowExtent -
              PokedexCardStyle.spacing -
              12)
          .clamp(
              PokedexInlineDetails.minHeight, PokedexInlineDetails.maxHeight);

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
                                // Some só o card da linha do painel.
                                hidden: start + col == selectedIndex &&
                                    row == selectedRow,
                                child: PokedexWebCard(
                                  key:
                                      ValueKey(widget.pokemon[start + col].url),
                                  pokemon: widget.pokemon[start + col],
                                  isSelected: start + col == selectedIndex,
                                  onTap: () => _onCardTap(
                                      widget.pokemon[start + col], columns),
                                ),
                              )
                            : const SizedBox(height: PokedexCardStyle.height),
                      ),
                    ],
                  ],
                ),
                // Painel de detalhes: abre/fecha encolhendo e crescendo com
                // o conteúdo visível (sem "piscar" vazio).
                AnimatedSwitcher(
                  duration: _transition,
                  switchInCurve: _curve,
                  switchOutCurve: _curve,
                  transitionBuilder: (child, animation) => SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: row == selectedRow
                      ? Padding(
                          key: ValueKey('panel-$row'),
                          padding: const EdgeInsets.only(
                              top: PokedexCardStyle.spacing),
                          child: _GrowFromCard(
                              key: ValueKey(_openCount),
                              enabled: _openedByClick,
                              // Cresce a partir da coluna do card clicado.
                              alignment: Alignment(
                                  -1 +
                                      2 *
                                          (selectedIndex % columns + 0.5) /
                                          columns,
                                  -1),
                              // Bucket próprio: as abas do painel não herdam a
                              // posição de rolagem da lista da Pokédex.
                              child: PageStorage(
                                  bucket: PageStorageBucket(),
                                  child: PokedexInlineDetails(
                                    height: panelHeight,
                                    pokemonId: int.parse(
                                        widget.pokemon[selectedIndex].id),
                                    initialTab: _tab,
                                    onTabChanged: (tab) => _tab = tab,
                                    hasPrevious: selectedIndex > 0,
                                    hasNext: selectedIndex <
                                        widget.pokemon.length - 1,
                                    onPrevious: () => _open(
                                        widget.pokemon[selectedIndex - 1],
                                        columns,
                                        byClick: false),
                                    onNext: () => _open(
                                        widget.pokemon[selectedIndex + 1],
                                        columns,
                                        byClick: false),
                                    onNavigate: (id) => _openById(id, columns),
                                    onClose: _close,
                                  ))),
                        )
                      : const SizedBox(
                          key: ValueKey('empty'), width: double.infinity),
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
  final bool enabled;
  final Widget child;

  const _GrowFromCard(
      {super.key,
      required this.alignment,
      required this.enabled,
      required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
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
