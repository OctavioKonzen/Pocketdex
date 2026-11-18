import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/dex_seals.dart';

void main() {
  final rows = [for (final r in jsonDecode(File('assets/database/pokemon.json').readAsStringSync()) as List) Map<String, dynamic>.from(r as Map)];

  test('selos da Pokédex: 9 regiões e 18 tipos, só as formas normais (igual ao site)', () {
    final seals = DexSeals.build(rows);
    expect(seals.length, 27);
    final kanto = seals.firstWhere((s) => s.id == 'kanto');
    expect(kanto.ids.length, 151);
    expect(seals.firstWhere((s) => s.id == 'paldea').ids.length, 1025 - 905);
    expect(seals.fold<int>(0, (n, s) => n + (s.id.startsWith('type-') ? 0 : s.ids.length)), 1025);
    final caught = {...kanto.ids};
    expect(kanto.done(caught), isTrue);
    expect(DexSeals.doneIds(seals, caught), contains('kanto'));
    expect(seals.firstWhere((s) => s.id == 'type-fire').done(caught), isFalse);
    expect(seals.firstWhere((s) => s.id == 'johto').have(caught), 0);
  });
}
