// lib/widgets/expandable_entry.dart
//
// Itens da Enciclopédia que abrem os detalhes logo abaixo, empurrando os
// outros para baixo (mesma lógica do site) em vez de abrir outra tela.
// Só um fica aberto por vez; os dados de cada item são carregados uma vez.

import 'package:flutter/material.dart';

import '../models/pokemon_listing.dart';
import 'pikachu_loading_indicator.dart';
import 'pokemon_card.dart';

class ExpandableEntry<T> extends StatefulWidget {
  final String id;
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T? data, bool open) header;
  final Widget Function(BuildContext context, T data) details;

  /// Qual item está aberto (compartilhado pela lista).
  final ValueNotifier<String?> openId;
  final Color accent;

  const ExpandableEntry({
    super.key,
    required this.id,
    required this.load,
    required this.header,
    required this.details,
    required this.openId,
    this.accent = const Color(0xFFAB47BC),
  });

  @override
  State<ExpandableEntry<T>> createState() => _ExpandableEntryState<T>();
}

class _ExpandableEntryState<T> extends State<ExpandableEntry<T>> {
  late final Future<T> _future = widget.load();

  void _toggle() {
    final opening = widget.openId.value != widget.id;
    widget.openId.value = opening ? widget.id : null;
    if (opening) {
      // Rola suavemente até o item aberto.
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) {
          Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: widget.openId,
      builder: (context, openId, _) {
        final open = openId == widget.id;
        return FutureBuilder<T>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: open ? Border(top: BorderSide(color: widget.accent, width: 4)) : null,
                boxShadow: open ? const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: data == null ? null : _toggle,
                      child: Row(
                        children: [
                          Expanded(child: widget.header(context, data, open)),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: AnimatedRotation(
                              turns: open ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: Icon(Icons.expand_more, color: theme.hintColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: open && data != null
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: widget.details(context, data),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Grade com alguns Pokémon e o botão "Ver todos" (lista grande é pesada
/// para desenhar de uma vez dentro da lista).
class PokemonPreviewGrid extends StatefulWidget {
  final Future<List<PokemonListing>> Function() load;
  final VoidCallback onSeeAll;
  final int limit;
  const PokemonPreviewGrid({super.key, required this.load, required this.onSeeAll, this.limit = 12});

  @override
  State<PokemonPreviewGrid> createState() => _PokemonPreviewGridState();
}

class _PokemonPreviewGridState extends State<PokemonPreviewGrid> {
  late final Future<List<PokemonListing>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<PokemonListing>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: PikachuLoadingIndicator(size: 50));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Nenhum Pokémon encontrado.', style: TextStyle(color: theme.hintColor)),
          );
        }
        final shown = list.take(widget.limit).toList();
        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) => PokemonCard(key: ValueKey(shown[i].url), pokemonListing: shown[i]),
            ),
            if (list.length > shown.length)
              TextButton.icon(
                onPressed: widget.onSeeAll,
                icon: const Icon(Icons.grid_view),
                label: Text('Ver todos (${list.length})'),
              ),
          ],
        );
      },
    );
  }
}
