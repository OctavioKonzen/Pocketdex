import 'package:flutter/material.dart';

const Map<String, Color> pokemonTypeColors = {
  'normal': Color(0xFFA8A77A),
  'fire': Color(0xFFEE8130),
  'water': Color(0xFF6390F0),
  'electric': Color(0xFFF7D02C),
  'grass': Color(0xFF7AC74C),
  'ice': Color(0xFF96D9D6),
  'fighting': Color(0xFFC22E28),
  'poison': Color(0xFFA33EA1),
  'ground': Color(0xFFE2BF65),
  'flying': Color(0xFFA98FF3),
  'psychic': Color(0xFFF95587),
  'bug': Color(0xFFA6B91A),
  'rock': Color(0xFFB6A136),
  'ghost': Color(0xFF735797),
  'dragon': Color(0xFF6F35FC),
  'dark': Color(0xFF705746),
  'steel': Color(0xFFB7B7CE),
  'fairy': Color(0xFFD685AD),
};

Color getColorForType(String type) {
  return pokemonTypeColors[type.toLowerCase()] ?? Colors.grey[700]!;
}
/// Fundo de um Pokémon: a cor do tipo, ou gradiente das duas cores quando
/// ele tem dois tipos (igual ao site).
BoxDecoration typeBackground(List<String> types, {BorderRadius? borderRadius}) {
  final first = types.isNotEmpty ? getColorForType(types.first) : Colors.grey[850]!;
  return BoxDecoration(
    color: first,
    borderRadius: borderRadius,
    gradient: types.length > 1
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [first, getColorForType(types[1])],
            stops: const [0.2, 0.85],
          )
        : null,
  );
}
