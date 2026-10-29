// lib/widgets/team_image.dart
//
// Imagem do time para mandar no WhatsApp, Instagram... (igual ao site,
// TeamImage.jsx): nome do time, cada Pokémon com item, habilidade, Tera e
// golpes, na cor do time e com a marca do PocketDex.

import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../utils/pokemon_colors.dart';
import '../utils/string_extensions.dart';
import 'pokemon_sprite.dart';

/// "choice-scarf" → "Choice Scarf".
String _pretty(Object? slug) => '${slug ?? ''}'.split('-').map((w) => w.capitalise()).join(' ');

Color _hex(String? hex, Color fallback) {
  final v = int.tryParse((hex ?? '').replaceAll('#', ''), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

class TeamImage {
  TeamImage._();

  /// Mostra a imagem e o botão para compartilhar.
  static Future<void> show(
    BuildContext context, {
    required String name,
    String? color,
    required List<int?> pokemon,
    required List<Map<String, dynamic>?> sets,
    required Map<int, String> names,
  }) async {
    final key = GlobalKey();
    var busy = false;
    await showDialog(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: RepaintBoundary(
                    key: key,
                    child: TeamImageCard(name: name, color: color, pokemon: pokemon, sets: sets, names: names),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Fechar'))),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                update(() => busy = true);
                                await _share(key, name);
                                update(() => busy = false);
                              },
                        icon: const Icon(Icons.share),
                        label: const Text('Compartilhar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _share(GlobalKey key, String name) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return;
    final file = XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: 'pocketdex-time.png');
    await SharePlus.instance.share(ShareParams(files: [file], text: tr('Meu time "{0}" no PocketDex').replaceAll('{0}', name)));
  }
}

/// O cartão da imagem (público para o teste de layout).
class TeamImageCard extends StatelessWidget {
  final String name;
  final String? color;
  final List<int?> pokemon;
  final List<Map<String, dynamic>?> sets;
  final Map<int, String> names;
  const TeamImageCard({super.key, required this.name, this.color, required this.pokemon, required this.sets, required this.names});

  @override
  Widget build(BuildContext context) {
    final base = _hex(color, const Color(0xFF3949AB));
    final members = [
      for (var i = 0; i < pokemon.length; i++)
        if (pokemon[i] != null) (pokemon[i]!, i < sets.length ? sets[i] : null)
    ];
    // A imagem é sempre igual, qualquer que seja o tamanho do texto do aparelho.
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: 360,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [base, Color.lerp(base, Colors.black, 0.55)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white, fontSize: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final (id, set) in members) _Member(id: id, set: set, name: names[id] ?? '#$id')],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Image.asset('assets/images/poke_logo.png', height: 34),
                const Spacer(),
                const Text('octaviokonzen.github.io/Pocketdex', style: TextStyle(color: Colors.white70, fontSize: 9)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Member extends StatelessWidget {
  final int id;
  final Map<String, dynamic>? set;
  final String name;
  const _Member({required this.id, this.set, required this.name});

  @override
  Widget build(BuildContext context) {
    final moves = [
      for (final m in (set?['moves'] as List?) ?? const [])
        if ('$m'.isNotEmpty) _pretty(m)
    ];
    final item = '${set?['item'] ?? ''}';
    final ability = '${set?['ability'] ?? ''}';
    final tera = '${set?['tera'] ?? ''}';
    final nickname = '${set?['nickname'] ?? ''}'.trim();
    final title = nickname.isNotEmpty ? nickname : I18n.pokemonName(_pretty(name));
    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox.square(dimension: 52, child: PokemonSprite(id, shiny: set?['shiny'] == true, fill: 0.95)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                if (item.isNotEmpty) Text('@ ${_pretty(item)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                if (tera.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: getColorForType(tera), borderRadius: BorderRadius.circular(8)),
                    child: Text('Tera ${_pretty(tera)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
          ]),
          if (ability.isNotEmpty) Text(_pretty(ability), style: const TextStyle(color: Colors.white70)),
          for (final m in moves) Text('• $m', maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
