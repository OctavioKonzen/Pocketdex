import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/team_share.dart';

void main() {
  test('código igual ao do site (vai e volta)', () {
    // Código gerado pelo site para o time "Meu Time".
    const fromSite = 'PDX1eyJuIjoiTWV1IFRpbWUiLCJjIjpudWxsLCJwIjpbMTAwMzQsNDQ1LDEyMiwxMDAyMSxudWxsLG51bGxdfQ';
    final team = TeamShare.decode('https://x/#/times/importar/$fromSite')!;
    expect(team.name, 'Meu Time');
    expect(team.pokemon, [10034, 445, 122, 10021, null, null]);
    expect(TeamShare.encode(name: team.name, color: team.color, pokemon: team.pokemon), fromSite);
    final accents = TeamShare.decode(TeamShare.encode(name: 'Time Ação ⚡', color: '#FF5252', pokemon: [6]))!;
    expect(accents.name, 'Time Ação ⚡');
    expect(accents.color, '#FF5252');
    expect(TeamShare.decode('lixo'), isNull);
  });

  test('lê o formato do Showdown', () {
    final rows = [
      {'id': 6, 'name': 'charizard', 'is_default': true},
      {'id': 10034, 'name': 'charizard-mega-x', 'is_default': false},
      {'id': 645, 'name': 'landorus-incarnate', 'is_default': true},
      {'id': 122, 'name': 'mr-mime', 'is_default': true},
    ];
    const text = '=== [gen9ou] Meu Time ===\n\nZard (Charizard-Mega-X) (M) @ Charizardite X\nAbility: Tough Claws\n- Dragon Dance\n\n'
        'Landorus @ Life Orb\n- Earthquake\n\nMr. Mime\n';
    final team = TeamShare.fromShowdown(text, rows)!;
    expect(team.name, 'Meu Time');
    expect(team.pokemon, [10034, 645, 122, null, null, null]);
    expect(TeamShare.showdownName('charizard-mega-x'), 'Charizard-Mega-X');
  });
}
