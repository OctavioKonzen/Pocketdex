// lib/widgets/generation_picker.dart
//
// Seletor de geração igual ao do site: botão com a cor da geração e os 3
// iniciais; ao tocar abre uma lista com botões grandes de cada geração.

import 'package:flutter/material.dart';
import '../models/generation.dart';
import '../utils/app_images.dart';

class GenerationPicker extends StatelessWidget {
  final Generation? value; // null = todas
  final ValueChanged<Generation?> onChanged;
  const GenerationPicker({super.key, required this.value, required this.onChanged});

  static Widget starters(List<String> ids, double size) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final id in ids)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Image.asset(AppImages.pokemonSprite(id),
                  width: size, height: size, filterQuality: FilterQuality.none, cacheWidth: 96),
            ),
        ],
      );

  static Widget option({required Generation? gen, required bool selected, required VoidCallback onTap, bool compact = false}) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gen?.gradient ?? allGenerationsGradient,
          borderRadius: BorderRadius.circular(compact ? 30 : 20),
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 30 : 20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 6 : 12),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(gen?.label ?? 'Todas as gerações',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: compact ? 14 : 17)),
                      if (!compact)
                        Text(gen?.region ?? 'Nacional',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!compact) const Spacer(),
                starters(gen?.starterIds ?? allGenerationsStarters, compact ? 30 : 48),
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
            const Text('Geração', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final gen in <Generation?>[null, ...generations])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: option(
                  gen: gen,
                  selected: gen?.id == value?.id,
                  onTap: () {
                    Navigator.pop(sheet);
                    onChanged(gen);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      option(gen: value, selected: false, compact: true, onTap: () => _open(context));
}
