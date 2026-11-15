// lib/widgets/type_chip.dart
//
// Etiqueta de tipo na cor do tipo (a mesma do site): usada nas listas, na
// busca e nas sugestões de time.

import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../utils/pokemon_colors.dart';
import '../utils/string_extensions.dart';

class TypeChip extends StatelessWidget {
  final String type;
  final bool small;
  const TypeChip(this.type, {super.key, this.small = true});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 2 : 4),
        decoration: BoxDecoration(
          color: getColorForType(type),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(150)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Text(type.capitalise(),
            style: TextStyle(color: Colors.white, fontSize: small ? 11 : 13, fontWeight: FontWeight.bold)),
      );
}

/// Vários tipos lado a lado.
class TypeChips extends StatelessWidget {
  final List<String> types;
  const TypeChips(this.types, {super.key});

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 4, runSpacing: 4, children: [for (final t in types) TypeChip(t)]);
}
