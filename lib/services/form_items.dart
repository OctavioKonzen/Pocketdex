// lib/services/form_items.dart
//
// Itens que formas e mecânicas precisam (igual ao site, web-site/src/lib/formItems.js):
// Mega Pedras (com duas Megas, como Charizard X/Y, quem monta o time escolhe),
// Cristais Z e as formas que só existem segurando um item (Primal, Origin,
// Crowned, máscaras da Ogerpon...). Dados em battle_items.json
// (tool/build_battle_items.mjs, do Pokémon Showdown).

/// "Charizardite X" / "charizardite-x" → "charizarditex" (id do Showdown).
String itemId(String? s) => (s ?? '').toLowerCase().replaceAll(RegExp(r'--held$'), '').replaceAll(RegExp('[^a-z0-9]'), '');

/// id do item → slug do nosso banco ("firiumz" → "firium-z--held").
String itemSlug(String id, List<Map<String, dynamic>> items) =>
    items.where((i) => itemId(i['name'] as String?) == id).map((i) => i['name'] as String).firstOrNull ?? id;

/// Megas que esse Pokémon pode ter: (pedra, forma Mega). [forms]: nomes das
/// formas da mesma espécie.
List<({String stone, String form})> megaOptions(String name, Set<String> forms, Map<String, dynamic> battleItems) {
  final seen = <String>{};
  final out = <({String stone, String form})>[];
  for (final e in ((battleItems['mega'] as Map?) ?? const {}).entries) {
    final stone = '${e.key}', form = '${e.value}';
    if (!forms.contains(form) || !seen.add(stone)) continue;
    // A Mega da forma dele (Tatsugiri Droopy → Mega Tatsugiri Droopy), se existir.
    out.add((stone: stone, form: forms.contains('$name-mega') ? '$name-mega' : form));
  }
  return out;
}

/// Nome da Mega para mostrar: "charizard-mega-x" → "Mega X"; uma só → "Mega".
String megaLabel(String form) {
  final parts = form.split(RegExp(r'-mega-?'));
  return parts.length > 1 && parts[1].isNotEmpty ? 'Mega ${parts[1].toUpperCase()}' : 'Mega';
}

/// Itens que essa forma precisa segurar (ids), ou [].
List<String> requiredItems(String name, Map<String, dynamic> battleItems) =>
    [for (final i in (((battleItems['forms'] as Map?) ?? const {})[name] as List?) ?? const []) '$i'];

/// Cristal Z de um tipo ("fire" → "firiumz").
String? zCrystalOf(String type, Map<String, dynamic> battleItems) =>
    ((battleItems['z'] as Map?) ?? const {}).entries.where((e) => e.value == type).map((e) => '${e.key}').firstOrNull;
