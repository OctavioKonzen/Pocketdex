// lib/widgets/game_picker.dart
//
// Seletor de jogo (ao lado do de geração, igual ao site): mostra só os
// Pokémon que aparecem no jogo escolhido.

import 'package:flutter/material.dart';

import '../models/game.dart';
import 'generation_picker.dart';

const _allGradient = LinearGradient(colors: [Color(0xFF546E7A), Color(0xFF37474F)]);

class GamePicker extends StatelessWidget {
  final Game? value; // null = todos
  final ValueChanged<Game?> onChanged;
  const GamePicker({super.key, required this.value, required this.onChanged});

  static Widget _option({required Game? game, required bool selected, required VoidCallback onTap, bool compact = false}) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: game?.gradient ?? _allGradient,
          borderRadius: BorderRadius.circular(compact ? 30 : 20),
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 30 : 20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 6 : 10),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(game?.name ?? 'Todos os jogos',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: compact ? 14 : 16)),
                      if (!compact)
                        Text(game == null ? 'Pokédex Nacional' : 'Geração ${game.gen}${game.spinoff ? ' · jogo secundário' : ''}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!compact) const Spacer(),
                GenerationPicker.starters([for (final id in (game?.mascots ?? const [25])) '$id'], compact ? 30 : 44),
                if (compact) const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Jogo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final game in <Game?>[null, ...games])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _option(
                  game: game,
                  selected: game?.key == value?.key,
                  onTap: () {
                    Navigator.pop(sheet);
                    onChanged(game);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _option(game: value, selected: false, compact: true, onTap: () => _open(context));
}
