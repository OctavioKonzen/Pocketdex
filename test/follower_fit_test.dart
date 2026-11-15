import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/widgets/battle_scene.dart';

void main() {
  final anim = json.decode(File('assets/database/animated_sprites.json').readAsStringSync()) as Map;
  // O desenho de frente: [largura, altura] em caixas (como AnimatedSprites.standOf, com o GIF animado).
  List<double> stand(int id) {
    final f = (anim['fit']['front'] as Map)['$id'] as List?;
    final z = f == null ? 1.0 : ((f.first as num).toDouble() < 1 ? 1.0 : (f.first as num).toDouble());
    final s = (anim['stand']['front'] as Map)['$id'] as List;
    return [(s[0] as num) * z, (s[1] as num) * z];
  }

  final person = 0.95 * battleScale(personDm);
  ({double pokemon, double trainer, double k}) sizes(num height, int id) {
    final s = stand(id);
    final f = followerFit(height, s);
    return (pokemon: f.scale * 0.95 * s[1], trainer: person * f.k, k: f.k);
  }

  test('o Pokémon ao lado do treinador, na altura de verdade (igual ao site)', () {
    for (final (id, height) in [(25, 4), (6, 17), (143, 21), (1007, 25)]) {
      final r = sizes(height, id);
      expect(r.pokemon / r.trainer, closeTo(height / personDm, 0.01));
    }
    expect(sizes(25, 1007).k, lessThan(1));
    final wailord = sizes(145, 321);
    expect(wailord.k, followMin);
    expect(wailord.pokemon, lessThanOrEqualTo(0.95 + 1e-9));
    expect(sizes(4, 25).k, 1);
  });
}
